//============================================================================
// id_stage.v
//   ID stage and its sub-modules:
//     - RegFile             : 32 x 32-bit, with WB->ID internal bypass
//     - ImmGen              : I / S / B / J immediates
//     - ControlUnit         : custom opcode mapping (see table below)
//     - HazardDetectionUnit : load-use stall
//     - ID_Stage            : wraps the four above
//
// Custom opcode table (decimal opcodes, all 7-bit):
//   R-type, opcode=34 (0x22):
//     add  (f3=1,f7=10)   and  (f3=0,f7=10)   or   (f3=7,f7=10)
//     xor  (f3=5,f7=10)   sltu (f3=4,f7=1)
//     srl  (f3=6,f7=10)   sra  (f3=6,f7=30)
//   I-type, opcode=14 (0x0E):
//     addi (f3=1)   andi (f3=0)   ori  (f3=7)   lw   (f3=3)
//   I-type, opcode=68 (0x44):  jalr (f3=1)
//   B-type, opcode=64 (0x40):  bge  (f3=6)   bne  (f3=2)
//   J-type, opcode=70 (0x46):  jal
//   S-type, opcode=24 (0x18):  sw   (f3=3)
//============================================================================

//----------------------------------------------------------------------------
// Register File : 32 x 32, with internal WB->ID bypass
//----------------------------------------------------------------------------
module RegFile (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] regs [0:31];

    // Combinational read with same-cycle WB bypass
    assign rd1 = (rs1 == 5'd0)                                      ? 32'd0 :
                 (we && (rd == rs1) && (rd != 5'd0))                ? wd    :
                                                                      regs[rs1];
    assign rd2 = (rs2 == 5'd0)                                      ? 32'd0 :
                 (we && (rd == rs2) && (rd != 5'd0))                ? wd    :
                                                                      regs[rs2];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else if (we && (rd != 5'd0)) begin
            regs[rd] <= wd;
        end
    end
endmodule


//----------------------------------------------------------------------------
// Immediate Generator
//   imm_type: 0=I, 1=S, 2=B, 3=J
//----------------------------------------------------------------------------
module ImmGen (
    input      [31:0] inst,
    input      [2:0]  imm_type,
    output reg [31:0] imm
);
    always @(*) begin
        case (imm_type)
            3'd0: imm = {{20{inst[31]}}, inst[31:20]};                              // I
            3'd1: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};                  // S
            3'd2: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}; // B
            3'd3: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // J
            default: imm = 32'd0;
        endcase
    end
endmodule


//----------------------------------------------------------------------------
// Control Unit (custom opcode mapping)
//   alu_control codes:
//     0000 ADD   0001 SUB   0010 AND   0011 OR
//     0100 XOR   0110 SLTU  1000 SRL   1001 SRA
//   mem_to_reg: 0=ALU, 1=Memory, 2=PC+4 (for jal/jalr link)
//----------------------------------------------------------------------------
module ControlUnit (
    input      [6:0] opcode,
    input      [2:0] funct3,
    input      [6:0] funct7,
    output reg       reg_write,
    output reg       mem_read,
    output reg       mem_write,
    output reg       alu_src,      // 0 = rs2, 1 = imm
    output reg [1:0] mem_to_reg,
    output reg       branch,
    output reg       jump,
    output reg       jalr,
    output reg [3:0] alu_control,
    output reg [2:0] imm_type
);
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLTU = 4'b0110;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;

    always @(*) begin
        // defaults (NOP)
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        alu_src     = 1'b0;
        mem_to_reg  = 2'd0;
        branch      = 1'b0;
        jump        = 1'b0;
        jalr        = 1'b0;
        alu_control = ALU_ADD;
        imm_type    = 3'd0;

        case (opcode)
            //--- R-type (opcode = 34) -----------------------------------
            7'd34: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                case (funct3)
                    3'd1: alu_control = ALU_ADD;                              // add
                    3'd0: alu_control = ALU_AND;                              // and
                    3'd7: alu_control = ALU_OR;                               // or
                    3'd5: alu_control = ALU_XOR;                              // xor
                    3'd4: alu_control = ALU_SLTU;                             // sltu (f7=1)
                    3'd6: alu_control = (funct7 == 7'd30) ? ALU_SRA : ALU_SRL;// srl / sra
                    default: alu_control = ALU_ADD;
                endcase
            end

            //--- I-type (opcode = 14) : addi/andi/ori/lw -----------------
            7'd14: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_type  = 3'd0;
                case (funct3)
                    3'd1: alu_control = ALU_ADD;        // addi
                    3'd0: alu_control = ALU_AND;        // andi
                    3'd7: alu_control = ALU_OR;         // ori
                    3'd3: begin                          // lw
                        alu_control = ALU_ADD;
                        mem_read    = 1'b1;
                        mem_to_reg  = 2'd1;
                    end
                    default: alu_control = ALU_ADD;
                endcase
            end

            //--- JALR (opcode = 68) -------------------------------------
            7'd68: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                imm_type    = 3'd0;     // I-type
                alu_control = ALU_ADD;
                jump        = 1'b1;
                jalr        = 1'b1;
                mem_to_reg  = 2'd2;     // link = PC+4
            end

            //--- Branch (opcode = 64) : bge / bne ------------------------
            7'd64: begin
                branch      = 1'b1;
                imm_type    = 3'd2;     // B-type
                alu_src     = 1'b0;
                alu_control = ALU_SUB;  // not used downstream; BranchEval handles it
            end

            //--- JAL (opcode = 70) --------------------------------------
            7'd70: begin
                reg_write   = 1'b1;
                jump        = 1'b1;
                imm_type    = 3'd3;     // J-type
                mem_to_reg  = 2'd2;     // link = PC+4
            end

            //--- SW (opcode = 24) ---------------------------------------
            7'd24: begin
                mem_write   = 1'b1;
                alu_src     = 1'b1;
                imm_type    = 3'd1;     // S-type
                alu_control = ALU_ADD;
            end

            default: ; // NOP (all defaults already set)
        endcase
    end
endmodule


//----------------------------------------------------------------------------
// Hazard Detection Unit (load-use)
//   If the instruction in ID/EX is a load whose rd matches either source
//   register of the instruction currently in IF/ID, stall one cycle.
//----------------------------------------------------------------------------
module HazardDetectionUnit (
    input  [4:0] if_id_rs1,
    input  [4:0] if_id_rs2,
    input  [4:0] id_ex_rd,
    input        id_ex_mem_read,
    output       stall
);
    assign stall = id_ex_mem_read &&
                   (id_ex_rd != 5'd0) &&
                   ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
endmodule


//----------------------------------------------------------------------------
// ID_Stage : wrapper
//----------------------------------------------------------------------------
module ID_Stage (
    input         clk,
    input         rst,
    // from IF/ID register
    input  [31:0] if_id_instruction,
    // write-back (from WB stage)
    input         wb_reg_write,
    input  [4:0]  wb_rd,
    input  [31:0] wb_wdata,
    // hazard inputs (from ID/EX register)
    input  [4:0]  id_ex_rd,
    input         id_ex_mem_read,
    // datapath outputs
    output [31:0] id_rd1,
    output [31:0] id_rd2,
    output [31:0] id_imm,
    output [4:0]  id_rs1,
    output [4:0]  id_rs2,
    output [4:0]  id_rd,
    output [2:0]  id_funct3,
    output [6:0]  id_funct7,
    output [6:0]  id_opcode,
    // control outputs
    output        id_reg_write,
    output        id_mem_read,
    output        id_mem_write,
    output        id_alu_src,
    output [1:0]  id_mem_to_reg,
    output        id_branch,
    output        id_jump,
    output        id_jalr,
    output [3:0]  id_alu_control,
    // hazard output
    output        stall
);
    assign id_opcode = if_id_instruction[6:0];
    assign id_funct3 = if_id_instruction[14:12];
    assign id_funct7 = if_id_instruction[31:25];
    assign id_rs1    = if_id_instruction[19:15];
    assign id_rs2    = if_id_instruction[24:20];
    assign id_rd     = if_id_instruction[11:7];

    wire [2:0] imm_type_w;

    RegFile u_rf (
        .clk (clk),
        .rst (rst),
        .we  (wb_reg_write),
        .rs1 (id_rs1),
        .rs2 (id_rs2),
        .rd  (wb_rd),
        .wd  (wb_wdata),
        .rd1 (id_rd1),
        .rd2 (id_rd2)
    );

    ImmGen u_imm (
        .inst    (if_id_instruction),
        .imm_type(imm_type_w),
        .imm     (id_imm)
    );

    ControlUnit u_ctrl (
        .opcode     (id_opcode),
        .funct3     (id_funct3),
        .funct7     (id_funct7),
        .reg_write  (id_reg_write),
        .mem_read   (id_mem_read),
        .mem_write  (id_mem_write),
        .alu_src    (id_alu_src),
        .mem_to_reg (id_mem_to_reg),
        .branch     (id_branch),
        .jump       (id_jump),
        .jalr       (id_jalr),
        .alu_control(id_alu_control),
        .imm_type   (imm_type_w)
    );

    HazardDetectionUnit u_hdu (
        .if_id_rs1     (id_rs1),
        .if_id_rs2     (id_rs2),
        .id_ex_rd      (id_ex_rd),
        .id_ex_mem_read(id_ex_mem_read),
        .stall         (stall)
    );
endmodule
