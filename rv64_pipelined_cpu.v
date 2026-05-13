//==========================================================================
// PHASE 3 : RV64 5-STAGE PIPELINED CPU
//==========================================================================
//  Stages : IF  -> ID  -> EX  -> MEM -> WB
//  Pipeline registers : IF/ID , ID/EX , EX/MEM , MEM/WB
//
//  Enhancements over Phase 2:
//    1. Forwarding (bypassing) unit         -> resolves EX & MEM data hazards
//    2. Hazard Detection Unit               -> stalls on load-use hazards
//    3. Branch Predictor (2-bit saturating) -> with BTB, in IF stage
//    4. Branch Determination in EX stage    -> flushes IF/ID & ID/EX on miss
//
//  RV64I instructions supported in this design:
//    R-type   : add, sub, and, or, xor, sll, srl, sra, slt, sltu
//    I-type   : addi, andi, ori, xori
//    Load     : ld     (load doubleword, funct3=011)
//    Store    : sd     (store doubleword, funct3=011)
//    Branch   : beq, bne, blt, bge, bltu, bgeu
//    Jump     : jal, jalr
//
//  Author : Phase 3 build
//==========================================================================


//==========================================================================
//  PROGRAM COUNTER (with write-enable for stalling)
//==========================================================================
module pc (
    input              clk,
    input              reset,
    input              pc_write,     // 0 = freeze PC (stall)
    input      [63:0]  next_pc,
    output reg [63:0]  pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= 64'd0;
        else if (pc_write)
            pc <= next_pc;
        // else: hold current pc (stall)
    end
endmodule


//==========================================================================
//  INSTRUCTION MEMORY (byte-addressed, little-endian, 64KB)
//==========================================================================
module instruction_memory (
    input  [63:0] pc,
    output [31:0] instruction
);
    reg [7:0] mem [0:65535];
    wire [15:0] addr = pc[15:0];

    assign instruction = { mem[addr+3], mem[addr+2], mem[addr+1], mem[addr] };

    // Program is loaded by the test bench using $readmemh
    // or by direct mem[i] assignments.
endmodule


//==========================================================================
//  REGISTER FILE (32 x 64-bit)
//   - Write on posedge clk
//   - Internal write-before-read forwarding so that WB & ID in same cycle
//     correctly forwards the just-written value to ID.
//   - x0 is hard-wired to zero
//==========================================================================
module RegFile (
    input         clk,
    input         reg_write,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [63:0] write_data,
    output [63:0] read_data1,
    output [63:0] read_data2
);
    reg [63:0] regs [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 64'd0;
    end

    always @(posedge clk) begin
        if (reg_write && rd != 5'd0)
            regs[rd] <= write_data;
    end

    // Internal WB->ID forwarding inside the register file
    assign read_data1 = (rs1 == 5'd0) ? 64'd0 :
                        (reg_write && (rd == rs1) && (rd != 5'd0)) ? write_data :
                        regs[rs1];

    assign read_data2 = (rs2 == 5'd0) ? 64'd0 :
                        (reg_write && (rd == rs2) && (rd != 5'd0)) ? write_data :
                        regs[rs2];
endmodule


//==========================================================================
//  IMMEDIATE GENERATOR (RV64, sign-extended to 64 bits)
//==========================================================================
module ImmGen (
    input      [31:0] instruction,
    input      [2:0]  imm_type,    // 000=I, 001=S, 010=B, 011=J
    output reg [63:0] imm_out
);
    always @(*) begin
        case (imm_type)
            3'b000: // I-type
                imm_out = { {52{instruction[31]}}, instruction[31:20] };

            3'b001: // S-type
                imm_out = { {52{instruction[31]}}, instruction[31:25], instruction[11:7] };

            3'b010: // B-type
                imm_out = { {51{instruction[31]}},
                            instruction[31], instruction[7],
                            instruction[30:25], instruction[11:8], 1'b0 };

            3'b011: // J-type
                imm_out = { {43{instruction[31]}},
                            instruction[31], instruction[19:12],
                            instruction[20], instruction[30:21], 1'b0 };

            default: imm_out = 64'd0;
        endcase
    end
endmodule


//==========================================================================
//  CONTROL UNIT
//   Generates all control signals from the opcode + funct3 + funct7 bit.
//   All control signals travel down the pipeline via ID/EX, EX/MEM, MEM/WB.
//==========================================================================
module ControlUnit (
    input  [31:0] instruction,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,      // 0 = reg, 1 = imm
    output reg        mem_to_reg,   // 0 = ALU result, 1 = mem data
    output reg        branch,       // is a conditional branch
    output reg        jump,         // is a jal / jalr
    output reg        jalr,         // is specifically jalr
    output reg [3:0]  alu_control,
    output reg [2:0]  imm_type
);
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire       bit30  = instruction[30];

    localparam R_TYPE = 7'b0110100;  // 0x34
    localparam I_TYPE = 7'b0010100;  // 0x14
    localparam LOAD   = 7'b0000011;  // 0x03
    localparam STORE  = 7'b0100100;  // 0x24
    localparam BRANCH = 7'b1100100;  // 0x64
    localparam JAL    = 7'b1110000;  // 0x70
    localparam JALR   = 7'b1101000;  // 0x68

    // ALU control codes
    // 0010=ADD 0110=SUB 0000=AND 0001=OR  0011=XOR
    // 0100=SLT 0101=SLTU 0111=SLL 1000=SRL 1001=SRA
    // (branch comparisons use SUB result + funct3 to evaluate condition in EX)

    always @(*) begin
        // defaults
        reg_write   = 0;
        mem_read    = 0;
        mem_write   = 0;
        alu_src     = 0;
        mem_to_reg  = 0;
        branch      = 0;
        jump        = 0;
        jalr        = 0;
        alu_control = 4'b0010;     // ADD by default
        imm_type    = 3'b000;

        case (opcode)
            R_TYPE: begin
                reg_write = 1;
                alu_src   = 0;
                case (funct3)
                    3'b001: alu_control = 4'b0010; // SUB EXTRA / ADD
                    3'b000: alu_control = 4'b0000; // AND
                    3'b111: alu_control = 4'b0001; // OR
                    3'b101: alu_control = 4'b0011; // XOR
                    3'b010: alu_control = 4'b0100; // SLT EXTRA
                    3'b100: alu_control = 4'b0101; // SLTU
                    3'b001: alu_control = 4'b0111; // SLL EXTRA
                    3'b110: alu_control = (funct7 == 7'h30) ? 4'b1001 : 4'b1000; // SRA / SRL
                    default: alu_control = 4'b0010;
                endcase
            end

            I_TYPE: begin
                reg_write = 1;
                alu_src   = 1;
                imm_type  = 3'b000; // Both ALU I-types and Lw use I-type immediate
                
                if (funct3 == 3'h3) begin
                    // ---- This is Load Word (Lw) ----
                    mem_read    = 1;
                    mem_to_reg  = 1;
                    alu_control = 4'b0010; // ADD to calculate memory address
                end else begin
                    // ---- These are standard I-Type ALU operations ----
                    mem_read    = 0;
                    mem_to_reg  = 0;
                    case (funct3)
                        3'h1: alu_control = 4'b0010; // Addiw
                        3'h0: alu_control = 4'b0000; // Andi
                        3'h7: alu_control = 4'b0001; // Ori (Wait, your table says Ori is 34/7 or 14/7. Ori is 4'b0001 in your codes!)
                        default: alu_control = 4'b0010;
                    endcase
                end
            end

            STORE: begin
                mem_write   = 1;
                alu_src     = 1;
                imm_type    = 3'b001;
                alu_control = 4'b0010;
            end

            BRANCH: begin
                branch      = 1;
                imm_type    = 3'b010;
                alu_control = 4'b0110;  // SUB to compare (actual decision uses funct3 in EX)
            end

            JAL: begin
                reg_write = 1;
                jump      = 1;
                imm_type  = 3'b011;
            end

            JALR: begin
                reg_write = 1;
                jump      = 1;
                jalr      = 1;
                alu_src   = 1;
                imm_type  = 3'b000;
                alu_control = 4'b0010;
            end

            default: ; // nop
        endcase
    end
endmodule


//==========================================================================
//  ALU (64-bit)
//==========================================================================
module ALU (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  alu_ctrl,
    output reg [63:0] result,
    output        zero
);
    assign zero = (result == 64'd0);

    always @(*) begin
        case (alu_ctrl)
            4'b0010: result = a + b;                              // ADD
            4'b0110: result = a - b;                              // SUB
            4'b0000: result = a & b;                              // AND
            4'b0001: result = a | b;                              // OR
            4'b0011: result = a ^ b;                              // XOR
            4'b0100: result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0; // SLT
            4'b0101: result = (a < b) ? 64'd1 : 64'd0;            // SLTU
            4'b0111: result = a << b[5:0];                        // SLL
            4'b1000: result = a >> b[5:0];                        // SRL
            4'b1001: result = $signed(a) >>> b[5:0];              // SRA
            default: result = 64'd0;
        endcase
    end
endmodule


//==========================================================================
//  BRANCH CONDITION EVALUATOR (lives in EX stage)
//   Uses funct3 to decide if the branch is taken based on the two operands.
//==========================================================================
module BranchEval (
    input  [63:0] a,
    input  [63:0] b,
    input  [2:0]  funct3,
    output reg    take
);
    always @(*) begin
        case (funct3)
            3'b000: take = (a == b);                              // BEQ
            3'b001: take = (a != b);                              // BNE
            3'b100: take = ($signed(a) <  $signed(b));            // BLT
            3'b101: take = ($signed(a) >= $signed(b));            // BGE
            3'b110: take = (a <  b);                              // BLTU
            3'b111: take = (a >= b);                              // BGEU
            default: take = 1'b0;
        endcase
    end
endmodule


//==========================================================================
//  DATA MEMORY  (256 x 64-bit, doubleword granularity)
//==========================================================================
module data_memory (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [63:0] addr,
    input  [63:0] write_data,
    output reg [63:0] read_data
);
    reg [63:0] mem [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 64'd0;
    end

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[10:3]] <= write_data; // doubleword index
    end

    always @(*) begin
        if (mem_read)
            read_data = mem[addr[10:3]];
        else
            read_data = 64'd0;
    end
endmodule


//==========================================================================
//  FORWARDING UNIT
//   Resolves EX & MEM data hazards by selecting where each ALU operand
//   actually comes from this cycle:
//      00 -> from ID/EX  (normal register read)
//      10 -> from EX/MEM (1-cycle-old ALU result)
//      01 -> from MEM/WB (2-cycle-old write-back value)
//==========================================================================
module ForwardingUnit (
    input  [4:0] id_ex_rs1,
    input  [4:0] id_ex_rs2,
    input  [4:0] ex_mem_rd,
    input        ex_mem_reg_write,
    input  [4:0] mem_wb_rd,
    input        mem_wb_reg_write,
    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);
    always @(*) begin
        // -------- ForwardA (operand from rs1) --------
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forwardA = 2'b10;   // EX hazard
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forwardA = 2'b01;   // MEM hazard
        else
            forwardA = 2'b00;

        // -------- ForwardB (operand from rs2) --------
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forwardB = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forwardB = 2'b01;
        else
            forwardB = 2'b00;
    end
endmodule


//==========================================================================
//  HAZARD DETECTION UNIT
//   Detects a LOAD-USE hazard: the instruction in ID/EX is a load, and the
//   instruction currently in IF/ID uses its destination as a source.
//
//   When detected:
//      - freeze PC (pc_write = 0)
//      - freeze IF/ID register (if_id_write = 0)
//      - inject a bubble into ID/EX (control_mux_sel = 1 => zero out controls)
//==========================================================================
module HazardDetectionUnit (
    input        id_ex_mem_read,
    input  [4:0] id_ex_rd,
    input  [4:0] if_id_rs1,
    input  [4:0] if_id_rs2,
    output reg   pc_write,
    output reg   if_id_write,
    output reg   control_mux_sel   // 1 => insert bubble (NOP controls)
);
    always @(*) begin
        if (id_ex_mem_read &&
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) &&
            id_ex_rd != 5'd0) begin
            pc_write        = 1'b0;
            if_id_write     = 1'b0;
            control_mux_sel = 1'b1;
        end else begin
            pc_write        = 1'b1;
            if_id_write     = 1'b1;
            control_mux_sel = 1'b0;
        end
    end
endmodule


//==========================================================================
//  BRANCH PREDICTOR  (dynamic, 2-bit saturating + small BTB)
//
//   - 16 entries, indexed by pc[5:2]
//   - Each entry holds  : 2-bit counter, valid bit, tag (upper PC bits),
//                         target address (BTB)
//   - 2-bit FSM states  : 00 strongly NT, 01 weakly NT, 10 weakly T, 11 strongly T
//   - Predict TAKEN when counter MSB == 1
//   - Updated in EX stage on every resolved branch / jump
//
//   Outputs in IF stage:
//      predict_taken      : prediction bit
//      predicted_target   : target if predicted taken (else don't care)
//==========================================================================
module BranchPredictor (
    input              clk,
    input              reset,

    // Prediction request (IF stage)
    input      [63:0]  if_pc,
    output reg         predict_taken,
    output reg [63:0]  predicted_target,

    // Update from EX stage
    input              update_en,         // a branch/jump was resolved
    input      [63:0]  update_pc,
    input              update_taken,
    input      [63:0]  update_target
);
    // 16 entries
    reg [1:0]  counter [0:15];
    reg        valid   [0:15];
    reg [57:0] tag     [0:15];   // 64 - 4 idx - 2 offset = 58 bits (bits 63..6 of PC)
    reg [63:0] target  [0:15];

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            counter[i] = 2'b01;     // weakly not-taken
            valid[i]   = 1'b0;
            tag[i]     = 58'd0;
            target[i]  = 64'd0;
        end
    end

    wire [3:0]  rd_idx  = if_pc[5:2];
    wire [57:0] rd_tag  = if_pc[63:6];   // was [63:8] -- bits 7:6 were uncovered, causing 0x14/0x54 aliasing
    wire [3:0]  wr_idx  = update_pc[5:2];
    wire [57:0] wr_tag  = update_pc[63:6];

    // Combinational lookup
    always @(*) begin
        if (valid[rd_idx] && (tag[rd_idx] == rd_tag) && counter[rd_idx][1]) begin
            predict_taken    = 1'b1;
            predicted_target = target[rd_idx];
        end else begin
            predict_taken    = 1'b0;
            predicted_target = 64'd0;
        end
    end

    // Update on resolved branch / jump in EX
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                counter[i] <= 2'b01;
                valid[i]   <= 1'b0;
            end
        end else if (update_en) begin
            valid[wr_idx]  <= 1'b1;
            tag[wr_idx]    <= wr_tag;
            target[wr_idx] <= update_target;

            // 2-bit saturating counter update
            if (update_taken) begin
                if (counter[wr_idx] != 2'b11)
                    counter[wr_idx] <= counter[wr_idx] + 2'b01;
            end else begin
                if (counter[wr_idx] != 2'b00)
                    counter[wr_idx] <= counter[wr_idx] - 2'b01;
            end
        end
    end
endmodule


//==========================================================================
//  PIPELINE REGISTERS
//==========================================================================

// ---------- IF/ID ----------------------------------------------------------
module IF_ID_Reg (
    input              clk,
    input              reset,
    input              flush,         // squash to NOP
    input              write_en,      // 0 = stall (hold)
    input      [63:0]  pc_in,
    input      [31:0]  instr_in,
    input              predicted_taken_in,
    input      [63:0]  predicted_target_in,
    output reg [63:0]  pc_out,
    output reg [31:0]  instr_out,
    output reg         predicted_taken_out,
    output reg [63:0]  predicted_target_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            pc_out               <= 64'd0;
            instr_out            <= 32'h00000013;  // NOP = addi x0,x0,0
            predicted_taken_out  <= 1'b0;
            predicted_target_out <= 64'd0;
        end else if (write_en) begin
            pc_out               <= pc_in;
            instr_out            <= instr_in;
            predicted_taken_out  <= predicted_taken_in;
            predicted_target_out <= predicted_target_in;
        end
    end
endmodule


// ---------- ID/EX ----------------------------------------------------------
module ID_EX_Reg (
    input              clk,
    input              reset,
    input              flush,            // squash on mispredict
    // control
    input              reg_write_in,
    input              mem_read_in,
    input              mem_write_in,
    input              alu_src_in,
    input              mem_to_reg_in,
    input              branch_in,
    input              jump_in,
    input              jalr_in,
    input      [3:0]   alu_ctrl_in,
    // data
    input      [63:0]  pc_in,
    input      [63:0]  rdata1_in,
    input      [63:0]  rdata2_in,
    input      [63:0]  imm_in,
    input      [4:0]   rs1_in,
    input      [4:0]   rs2_in,
    input      [4:0]   rd_in,
    input      [2:0]   funct3_in,
    input              predicted_taken_in,
    input      [63:0]  predicted_target_in,

    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         alu_src_out,
    output reg         mem_to_reg_out,
    output reg         branch_out,
    output reg         jump_out,
    output reg         jalr_out,
    output reg [3:0]   alu_ctrl_out,
    output reg [63:0]  pc_out,
    output reg [63:0]  rdata1_out,
    output reg [63:0]  rdata2_out,
    output reg [63:0]  imm_out,
    output reg [4:0]   rs1_out,
    output reg [4:0]   rs2_out,
    output reg [4:0]   rd_out,
    output reg [2:0]   funct3_out,
    output reg         predicted_taken_out,
    output reg [63:0]  predicted_target_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            reg_write_out        <= 0;
            mem_read_out         <= 0;
            mem_write_out        <= 0;
            alu_src_out          <= 0;
            mem_to_reg_out       <= 0;
            branch_out           <= 0;
            jump_out             <= 0;
            jalr_out             <= 0;
            alu_ctrl_out         <= 4'b0;
            pc_out               <= 64'd0;
            rdata1_out           <= 64'd0;
            rdata2_out           <= 64'd0;
            imm_out              <= 64'd0;
            rs1_out              <= 5'd0;
            rs2_out              <= 5'd0;
            rd_out               <= 5'd0;
            funct3_out           <= 3'd0;
            predicted_taken_out  <= 1'b0;
            predicted_target_out <= 64'd0;
        end else begin
            reg_write_out        <= reg_write_in;
            mem_read_out         <= mem_read_in;
            mem_write_out        <= mem_write_in;
            alu_src_out          <= alu_src_in;
            mem_to_reg_out       <= mem_to_reg_in;
            branch_out           <= branch_in;
            jump_out             <= jump_in;
            jalr_out             <= jalr_in;
            alu_ctrl_out         <= alu_ctrl_in;
            pc_out               <= pc_in;
            rdata1_out           <= rdata1_in;
            rdata2_out           <= rdata2_in;
            imm_out              <= imm_in;
            rs1_out              <= rs1_in;
            rs2_out              <= rs2_in;
            rd_out               <= rd_in;
            funct3_out           <= funct3_in;
            predicted_taken_out  <= predicted_taken_in;
            predicted_target_out <= predicted_target_in;
        end
    end
endmodule


// ---------- EX/MEM ---------------------------------------------------------
module EX_MEM_Reg (
    input              clk,
    input              reset,
    input              reg_write_in,
    input              mem_read_in,
    input              mem_write_in,
    input              mem_to_reg_in,
    input      [63:0]  alu_result_in,
    input      [63:0]  write_data_in,
    input      [4:0]   rd_in,
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg [63:0]  alu_result_out,
    output reg [63:0]  write_data_out,
    output reg [4:0]   rd_out
);
    always @(posedge clk) begin
        if (reset) begin
            reg_write_out  <= 0;
            mem_read_out   <= 0;
            mem_write_out  <= 0;
            mem_to_reg_out <= 0;
            alu_result_out <= 64'd0;
            write_data_out <= 64'd0;
            rd_out         <= 5'd0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_result_out <= alu_result_in;
            write_data_out <= write_data_in;
            rd_out         <= rd_in;
        end
    end
endmodule


// ---------- MEM/WB ---------------------------------------------------------
module MEM_WB_Reg (
    input              clk,
    input              reset,
    input              reg_write_in,
    input              mem_to_reg_in,
    input      [63:0]  alu_result_in,
    input      [63:0]  mem_data_in,
    input      [4:0]   rd_in,
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg [63:0]  alu_result_out,
    output reg [63:0]  mem_data_out,
    output reg [4:0]   rd_out
);
    always @(posedge clk) begin
        if (reset) begin
            reg_write_out  <= 0;
            mem_to_reg_out <= 0;
            alu_result_out <= 64'd0;
            mem_data_out   <= 64'd0;
            rd_out         <= 5'd0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_result_out <= alu_result_in;
            mem_data_out   <= mem_data_in;
            rd_out         <= rd_in;
        end
    end
endmodule


//==========================================================================
//  TOP-LEVEL PIPELINED CPU
//==========================================================================
module rv64_pipelined_cpu (
    input clk,
    input reset
);

    // ================================================================
    // ===========================  IF STAGE  =========================
    // ================================================================
    wire [63:0] pc_current, pc_plus4, pc_next;
    wire [31:0] if_instruction;
    wire        pc_write_en, if_id_write_en, hazard_bubble;
    wire        flush_from_branch;       // misprediction flush

    // Branch predictor outputs (in IF)
    wire        bp_predict_taken;
    wire [63:0] bp_predicted_target;

    // EX-stage branch resolution feeds back here
    wire        ex_take_branch;          // actual branch direction in EX
    wire [63:0] ex_branch_target;        // actual target in EX
    wire        ex_is_branch_or_jump;
    wire [63:0] ex_pc;
    wire        mispredict;              // 1 if EX disagrees with IF prediction

    assign pc_plus4 = pc_current + 64'd4;

    // PC selection :
    //   1. on misprediction  -> use ex_branch_target  (or PC+4 if branch was predicted-T but actually NT)
    //   2. on predict-taken  -> use predicted target
    //   3. else              -> PC + 4
    wire [63:0] correct_pc_on_miss = ex_take_branch ? ex_branch_target : (ex_pc + 64'd4);
    assign pc_next = mispredict        ? correct_pc_on_miss :
                     bp_predict_taken  ? bp_predicted_target :
                                         pc_plus4;

    pc PC (
        .clk(clk),
        .reset(reset),
        .pc_write(pc_write_en),
        .next_pc(pc_next),
        .pc(pc_current)
    );

    instruction_memory IM (
        .pc(pc_current),
        .instruction(if_instruction)
    );

    BranchPredictor BP (
        .clk(clk),
        .reset(reset),
        .if_pc(pc_current),
        .predict_taken(bp_predict_taken),
        .predicted_target(bp_predicted_target),
        .update_en(ex_is_branch_or_jump),
        .update_pc(ex_pc),
        .update_taken(ex_take_branch),
        .update_target(ex_branch_target)
    );

    // ================================================================
    // ========================  IF / ID  REGISTER  ===================
    // ================================================================
    wire [63:0] id_pc;
    wire [31:0] id_instruction;
    wire        id_predicted_taken;
    wire [63:0] id_predicted_target;

    IF_ID_Reg IF_ID (
        .clk(clk),
        .reset(reset),
        .flush(flush_from_branch),
        .write_en(if_id_write_en),
        .pc_in(pc_current),
        .instr_in(if_instruction),
        .predicted_taken_in(bp_predict_taken),
        .predicted_target_in(bp_predicted_target),
        .pc_out(id_pc),
        .instr_out(id_instruction),
        .predicted_taken_out(id_predicted_taken),
        .predicted_target_out(id_predicted_target)
    );

    // ================================================================
    // ===========================  ID STAGE  =========================
    // ================================================================
    wire [4:0] id_rs1 = id_instruction[19:15];
    wire [4:0] id_rs2 = id_instruction[24:20];
    wire [4:0] id_rd  = id_instruction[11:7];
    wire [2:0] id_funct3 = id_instruction[14:12];

    wire        id_reg_write, id_mem_read, id_mem_write, id_alu_src, id_mem_to_reg;
    wire        id_branch, id_jump, id_jalr;
    wire [3:0]  id_alu_ctrl;
    wire [2:0]  id_imm_type;
    wire [63:0] id_imm;
    wire [63:0] id_rdata1, id_rdata2;

    // Control signals for the instruction in MEM/WB are needed to drive
    // the register file write port.  Declared up here as wires; assigned later.
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [63:0] wb_write_data;

    ControlUnit CU (
        .instruction(id_instruction),
        .reg_write(id_reg_write),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .alu_src(id_alu_src),
        .mem_to_reg(id_mem_to_reg),
        .branch(id_branch),
        .jump(id_jump),
        .jalr(id_jalr),
        .alu_control(id_alu_ctrl),
        .imm_type(id_imm_type)
    );

    RegFile RF (
        .clk(clk),
        .reg_write(wb_reg_write),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(wb_rd),
        .write_data(wb_write_data),
        .read_data1(id_rdata1),
        .read_data2(id_rdata2)
    );

    ImmGen IG (
        .instruction(id_instruction),
        .imm_type(id_imm_type),
        .imm_out(id_imm)
    );

    // ----- Hazard detection: forward signals from ID/EX -----
    wire        ex_mem_read_stage;
    wire [4:0]  ex_rd_stage;

    HazardDetectionUnit HDU (
        .id_ex_mem_read(ex_mem_read_stage),
        .id_ex_rd(ex_rd_stage),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .pc_write(pc_write_en),
        .if_id_write(if_id_write_en),
        .control_mux_sel(hazard_bubble)
    );

    // If hazard_bubble = 1, gate all control signals to 0 going into ID/EX (bubble)
    wire id_reg_write_g  = hazard_bubble ? 1'b0 : id_reg_write;
    wire id_mem_read_g   = hazard_bubble ? 1'b0 : id_mem_read;
    wire id_mem_write_g  = hazard_bubble ? 1'b0 : id_mem_write;
    wire id_branch_g     = hazard_bubble ? 1'b0 : id_branch;
    wire id_jump_g       = hazard_bubble ? 1'b0 : id_jump;
    wire id_jalr_g       = hazard_bubble ? 1'b0 : id_jalr;

    // ================================================================
    // ========================  ID / EX REGISTER  ====================
    // ================================================================
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_alu_src, ex_mem_to_reg;
    wire        ex_branch, ex_jump, ex_jalr;
    wire [3:0]  ex_alu_ctrl;
    wire [63:0] ex_pc_w, ex_rdata1, ex_rdata2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire        ex_predicted_taken;
    wire [63:0] ex_predicted_target;

    ID_EX_Reg ID_EX (
        .clk(clk),
        .reset(reset),
        .flush(flush_from_branch),
        .reg_write_in(id_reg_write_g),
        .mem_read_in(id_mem_read_g),
        .mem_write_in(id_mem_write_g),
        .alu_src_in(id_alu_src),
        .mem_to_reg_in(id_mem_to_reg),
        .branch_in(id_branch_g),
        .jump_in(id_jump_g),
        .jalr_in(id_jalr_g),
        .alu_ctrl_in(id_alu_ctrl),
        .pc_in(id_pc),
        .rdata1_in(id_rdata1),
        .rdata2_in(id_rdata2),
        .imm_in(id_imm),
        .rs1_in(id_rs1),
        .rs2_in(id_rs2),
        .rd_in(id_rd),
        .funct3_in(id_funct3),
        .predicted_taken_in(id_predicted_taken),
        .predicted_target_in(id_predicted_target),
        .reg_write_out(ex_reg_write),
        .mem_read_out(ex_mem_read),
        .mem_write_out(ex_mem_write),
        .alu_src_out(ex_alu_src),
        .mem_to_reg_out(ex_mem_to_reg),
        .branch_out(ex_branch),
        .jump_out(ex_jump),
        .jalr_out(ex_jalr),
        .alu_ctrl_out(ex_alu_ctrl),
        .pc_out(ex_pc_w),
        .rdata1_out(ex_rdata1),
        .rdata2_out(ex_rdata2),
        .imm_out(ex_imm),
        .rs1_out(ex_rs1),
        .rs2_out(ex_rs2),
        .rd_out(ex_rd),
        .funct3_out(ex_funct3),
        .predicted_taken_out(ex_predicted_taken),
        .predicted_target_out(ex_predicted_target)
    );

    // Expose ID/EX mem_read & rd so the Hazard Detection Unit can see them
    assign ex_mem_read_stage = ex_mem_read;
    assign ex_rd_stage       = ex_rd;
    assign ex_pc             = ex_pc_w;

    // ================================================================
    // ===========================  EX STAGE  =========================
    // ================================================================
    // Forwarding muxes feed the ALU and branch evaluator
    wire [1:0]  forwardA, forwardB;
    wire [63:0] mem_alu_result;          // forwarded value from EX/MEM
    wire [63:0] wb_write_back_data;      // forwarded value from MEM/WB

    // EX/MEM forwarding feedback wires (declared up here so the FU sees correct widths)
    wire [4:0]  ex_mem_rd_stage_w;
    wire        ex_mem_reg_write_w;

    ForwardingUnit FU (
        .id_ex_rs1(ex_rs1),
        .id_ex_rs2(ex_rs2),
        .ex_mem_rd(ex_mem_rd_stage_w),
        .ex_mem_reg_write(ex_mem_reg_write_w),
        .mem_wb_rd(wb_rd),
        .mem_wb_reg_write(wb_reg_write),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );

    // Operand A (rs1) mux
    reg [63:0] alu_operand_a;
    always @(*) begin
        case (forwardA)
            2'b00: alu_operand_a = ex_rdata1;
            2'b10: alu_operand_a = mem_alu_result;
            2'b01: alu_operand_a = wb_write_back_data;
            default: alu_operand_a = ex_rdata1;
        endcase
    end

    // Operand B (rs2) -- first forward, then mux with immediate
    reg [63:0] forwarded_b;
    always @(*) begin
        case (forwardB)
            2'b00: forwarded_b = ex_rdata2;
            2'b10: forwarded_b = mem_alu_result;
            2'b01: forwarded_b = wb_write_back_data;
            default: forwarded_b = ex_rdata2;
        endcase
    end
    wire [63:0] alu_operand_b = ex_alu_src ? ex_imm : forwarded_b;

    // ALU
    wire [63:0] alu_result;
    wire        alu_zero;
    ALU ALU0 (
        .a(alu_operand_a),
        .b(alu_operand_b),
        .alu_ctrl(ex_alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Branch condition evaluation
    wire branch_condition_met;
    BranchEval BE (
        .a(alu_operand_a),
        .b(forwarded_b),
        .funct3(ex_funct3),
        .take(branch_condition_met)
    );

    // Compute actual branch / jump target
    wire [63:0] pc_plus_imm     = ex_pc_w + ex_imm;
    wire [63:0] jalr_target     = (alu_operand_a + ex_imm) & ~64'd1;
    wire [63:0] resolved_target = ex_jalr ? jalr_target : pc_plus_imm;

    // Actual taken-direction (for branch or unconditional jump)
    wire actual_taken = (ex_branch && branch_condition_met) || ex_jump;

    assign ex_take_branch       = actual_taken;
    assign ex_branch_target     = resolved_target;
    assign ex_is_branch_or_jump = ex_branch | ex_jump;

    // Misprediction logic :
    //   mispredict if direction differs from prediction, OR
    //   direction matches but predicted target was wrong (for jumps/branches we trust BTB only when
    //   prediction said taken and the target equals resolved_target).
    wire taken_matches  = (actual_taken == ex_predicted_taken);
    wire target_matches = (ex_predicted_target == resolved_target);
    assign mispredict   = ex_is_branch_or_jump &&
                          (!taken_matches || (actual_taken && !target_matches));

    // For jal / branches, the value written back is PC+4 (link). For others, ALU result.
    wire [63:0] ex_alu_or_link = ex_jump ? (ex_pc_w + 64'd4) : alu_result;

    // Misprediction flush -> kills IF/ID and ID/EX in the next cycle
    assign flush_from_branch = mispredict;

    // ================================================================
    // ========================  EX / MEM REGISTER  ===================
    // ================================================================
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire [63:0] mem_alu_result_w, mem_write_data_w;
    wire [4:0]  mem_rd_w;

    EX_MEM_Reg EX_MEM (
        .clk(clk),
        .reset(reset),
        .reg_write_in(ex_reg_write),
        .mem_read_in(ex_mem_read),
        .mem_write_in(ex_mem_write),
        .mem_to_reg_in(ex_mem_to_reg),
        .alu_result_in(ex_alu_or_link),
        .write_data_in(forwarded_b),          // already-forwarded store data
        .rd_in(ex_rd),
        .reg_write_out(mem_reg_write),
        .mem_read_out(mem_mem_read),
        .mem_write_out(mem_mem_write),
        .mem_to_reg_out(mem_mem_to_reg),
        .alu_result_out(mem_alu_result_w),
        .write_data_out(mem_write_data_w),
        .rd_out(mem_rd_w)
    );

    // Expose to forwarding unit
    assign mem_alu_result      = mem_alu_result_w;
    assign ex_mem_rd_stage_w   = mem_rd_w;
    assign ex_mem_reg_write_w  = mem_reg_write;

    // ================================================================
    // ===========================  MEM STAGE  ========================
    // ================================================================
    wire [63:0] mem_read_data;
    data_memory DM (
        .clk(clk),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .addr(mem_alu_result_w),
        .write_data(mem_write_data_w),
        .read_data(mem_read_data)
    );

    // ================================================================
    // ========================  MEM / WB REGISTER  ===================
    // ================================================================
    wire        wb_mem_to_reg;
    wire [63:0] wb_alu_result, wb_mem_data;

    MEM_WB_Reg MEM_WB (
        .clk(clk),
        .reset(reset),
        .reg_write_in(mem_reg_write),
        .mem_to_reg_in(mem_mem_to_reg),
        .alu_result_in(mem_alu_result_w),
        .mem_data_in(mem_read_data),
        .rd_in(mem_rd_w),
        .reg_write_out(wb_reg_write),
        .mem_to_reg_out(wb_mem_to_reg),
        .alu_result_out(wb_alu_result),
        .mem_data_out(wb_mem_data),
        .rd_out(wb_rd)
    );

    // ================================================================
    // ===========================  WB STAGE  =========================
    // ================================================================
    assign wb_write_data       = wb_mem_to_reg ? wb_mem_data : wb_alu_result;
    assign wb_write_back_data  = wb_write_data;

endmodule