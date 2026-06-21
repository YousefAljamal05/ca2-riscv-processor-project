//============================================================================
// ex_stage.v
//   EX stage and its sub-modules:
//     - ALU             : 32-bit ALU
//     - BranchEval      : bne / bge using funct3 (custom encoding)
//     - ForwardingUnit  : 2-bit forwardA / forwardB
//     - EX_Stage        : wraps them, plus the operand muxes and branch
//                         target / branch-taken computation
//============================================================================

//----------------------------------------------------------------------------
// 32-bit ALU
//----------------------------------------------------------------------------
module ALU (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_control,
    output reg [31:0] result,
    output            zero
);
    always @(*) begin
        case (alu_control)
            4'b0000: result = a + b;                          // ADD
            4'b0001: result = a - b;                          // SUB
            4'b0010: result = a & b;                          // AND
            4'b0011: result = a | b;                          // OR
            4'b0100: result = a ^ b;                          // XOR
            4'b0110: result = (a < b) ? 32'd1 : 32'd0;       // SLTU (unsigned)
            4'b1000: result = a >> b[4:0];                    // SRL
            4'b1001: result = $signed(a) >>> b[4:0];          // SRA
            default: result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0);
endmodule


//----------------------------------------------------------------------------
// Branch Evaluator
//   Custom funct3 mapping:
//     3'd2 -> bne (a != b)
//     3'd6 -> bge (a >= b, signed)
//----------------------------------------------------------------------------
module BranchEval (
    input      [2:0]  funct3,
    input      [31:0] a,
    input      [31:0] b,
    output reg        take
);
    always @(*) begin
        case (funct3)
            3'd2:    take = (a != b);                         // bne
            3'd6:    take = ($signed(a) >= $signed(b));       // bge
            default: take = 1'b0;
        endcase
    end
endmodule


//----------------------------------------------------------------------------
// Forwarding Unit
//   Forward priority: EX/MEM beats MEM/WB (newer wins).
//     00 = no forward (use ID/EX register data)
//     01 = forward from MEM/WB stage
//     10 = forward from EX/MEM stage
//----------------------------------------------------------------------------
module ForwardingUnit (
    input      [4:0] id_ex_rs1,
    input      [4:0] id_ex_rs2,
    input      [4:0] ex_mem_rd,
    input            ex_mem_reg_write,
    input      [4:0] mem_wb_rd,
    input            mem_wb_reg_write,
    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);
    always @(*) begin
        // A operand
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forwardA = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forwardA = 2'b01;
        else
            forwardA = 2'b00;

        // B operand
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forwardB = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forwardB = 2'b01;
        else
            forwardB = 2'b00;
    end
endmodule


//----------------------------------------------------------------------------
// EX_Stage : operand muxing + ALU + branch eval + target computation
//----------------------------------------------------------------------------
module EX_Stage (
    // ID/EX inputs (datapath)
    input  [31:0] id_ex_pc,
    input  [31:0] id_ex_rd1,
    input  [31:0] id_ex_rd2,
    input  [31:0] id_ex_imm,
    input  [4:0]  id_ex_rs1,
    input  [4:0]  id_ex_rs2,
    input  [2:0]  id_ex_funct3,
    // ID/EX inputs (control)
    input         id_ex_alu_src,
    input  [3:0]  id_ex_alu_control,
    input         id_ex_branch,
    input         id_ex_jump,
    input         id_ex_jalr,
    // Forwarding sources
    input  [4:0]  ex_mem_rd,
    input         ex_mem_reg_write,
    input  [31:0] ex_mem_alu_result,
    input  [4:0]  mem_wb_rd,
    input         mem_wb_reg_write,
    input  [31:0] wb_wdata,
    // Outputs to EX/MEM register
    output [31:0] ex_alu_result,
    output [31:0] ex_rs2_forwarded,   // for SW data
    // Branch resolution outputs (consumed at top)
    output        ex_branch_taken,
    output [31:0] ex_branch_target
);
    wire [1:0] fA, fB;

    ForwardingUnit u_fwd (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forwardA        (fA),
        .forwardB        (fB)
    );

    reg [31:0] op_a, op_b_pre;
    always @(*) begin
        case (fA)
            2'b10:   op_a = ex_mem_alu_result;
            2'b01:   op_a = wb_wdata;
            default: op_a = id_ex_rd1;
        endcase
        case (fB)
            2'b10:   op_b_pre = ex_mem_alu_result;
            2'b01:   op_b_pre = wb_wdata;
            default: op_b_pre = id_ex_rd2;
        endcase
    end

    wire [31:0] op_b = id_ex_alu_src ? id_ex_imm : op_b_pre;

    ALU u_alu (
        .a          (op_a),
        .b          (op_b),
        .alu_control(id_ex_alu_control),
        .result     (ex_alu_result),
        .zero       ()
    );

    wire branch_cond;
    BranchEval u_bev (
        .funct3(id_ex_funct3),
        .a     (op_a),
        .b     (op_b_pre),
        .take  (branch_cond)
    );

    // Resolve "is this a taken branch / jump?"
    wire is_branch_taken = id_ex_branch & branch_cond;
    wire is_jal          = id_ex_jump   & ~id_ex_jalr;
    wire is_jalr         = id_ex_jump   &  id_ex_jalr;

    assign ex_branch_taken  = is_branch_taken | is_jal | is_jalr;
    // JAL/Branch target = PC + imm   ; JALR target = (rs1 + imm) & ~1
    assign ex_branch_target = is_jalr ? {ex_alu_result[31:1], 1'b0}
                                      : (id_ex_pc + id_ex_imm);

    assign ex_rs2_forwarded = op_b_pre;   // store data goes through forwarding too
endmodule
