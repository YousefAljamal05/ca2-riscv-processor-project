//============================================================================
// pipeline_regs.v
//   The four 32-bit-datapath pipeline registers, each with their own
//   reset / stall / flush behavior:
//     - IF_ID_Reg  : write-enable (stall) + flush
//     - ID_EX_Reg  : flush (also used to inject load-use bubble)
//     - EX_MEM_Reg : always advances
//     - MEM_WB_Reg : always advances
//============================================================================

//----------------------------------------------------------------------------
// IF/ID
//----------------------------------------------------------------------------
module IF_ID_Reg (
    input         clk,
    input         rst,
    input         we,                   // 0 on stall
    input         flush,                // 1 on mispredict
    // inputs
    input  [31:0] in_pc,
    input  [31:0] in_pc_plus_4,
    input  [31:0] in_instruction,
    input         in_predict_taken,
    input  [31:0] in_predicted_target,
    // outputs
    output reg [31:0] out_pc,
    output reg [31:0] out_pc_plus_4,
    output reg [31:0] out_instruction,
    output reg        out_predict_taken,
    output reg [31:0] out_predicted_target
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_pc               <= 32'd0;
            out_pc_plus_4        <= 32'd0;
            out_instruction      <= 32'h00000000;
            out_predict_taken    <= 1'b0;
            out_predicted_target <= 32'd0;
        end else if (flush) begin
            out_pc               <= 32'd0;
            out_pc_plus_4        <= 32'd0;
            out_instruction      <= 32'h00000000;   // NOP (opcode=0 -> all-default ctrl)
            out_predict_taken    <= 1'b0;
            out_predicted_target <= 32'd0;
        end else if (we) begin
            out_pc               <= in_pc;
            out_pc_plus_4        <= in_pc_plus_4;
            out_instruction      <= in_instruction;
            out_predict_taken    <= in_predict_taken;
            out_predicted_target <= in_predicted_target;
        end
        // else: hold (stall)
    end
endmodule


//----------------------------------------------------------------------------
// ID/EX
//----------------------------------------------------------------------------
module ID_EX_Reg (
    input         clk,
    input         rst,
    input         flush,                // bubble injection (stall or mispredict)
    // datapath in
    input  [31:0] in_pc,
    input  [31:0] in_pc_plus_4,
    input  [31:0] in_rd1,
    input  [31:0] in_rd2,
    input  [31:0] in_imm,
    input  [4:0]  in_rs1,
    input  [4:0]  in_rs2,
    input  [4:0]  in_rd,
    input  [2:0]  in_funct3,
    input  [6:0]  in_funct7,
    input         in_predict_taken,
    input  [31:0] in_predicted_target,
    // control in
    input         in_reg_write,
    input         in_mem_read,
    input         in_mem_write,
    input         in_alu_src,
    input  [1:0]  in_mem_to_reg,
    input         in_branch,
    input         in_jump,
    input         in_jalr,
    input  [3:0]  in_alu_control,
    // datapath out
    output reg [31:0] out_pc,
    output reg [31:0] out_pc_plus_4,
    output reg [31:0] out_rd1,
    output reg [31:0] out_rd2,
    output reg [31:0] out_imm,
    output reg [4:0]  out_rs1,
    output reg [4:0]  out_rs2,
    output reg [4:0]  out_rd,
    output reg [2:0]  out_funct3,
    output reg [6:0]  out_funct7,
    output reg        out_predict_taken,
    output reg [31:0] out_predicted_target,
    // control out
    output reg        out_reg_write,
    output reg        out_mem_read,
    output reg        out_mem_write,
    output reg        out_alu_src,
    output reg [1:0]  out_mem_to_reg,
    output reg        out_branch,
    output reg        out_jump,
    output reg        out_jalr,
    output reg [3:0]  out_alu_control
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            out_pc               <= 32'd0;
            out_pc_plus_4        <= 32'd0;
            out_rd1              <= 32'd0;
            out_rd2              <= 32'd0;
            out_imm              <= 32'd0;
            out_rs1              <= 5'd0;
            out_rs2              <= 5'd0;
            out_rd               <= 5'd0;
            out_funct3           <= 3'd0;
            out_funct7           <= 7'd0;
            out_predict_taken    <= 1'b0;
            out_predicted_target <= 32'd0;

            out_reg_write   <= 1'b0;
            out_mem_read    <= 1'b0;
            out_mem_write   <= 1'b0;
            out_alu_src     <= 1'b0;
            out_mem_to_reg  <= 2'd0;
            out_branch      <= 1'b0;
            out_jump        <= 1'b0;
            out_jalr        <= 1'b0;
            out_alu_control <= 4'd0;
        end else begin
            out_pc               <= in_pc;
            out_pc_plus_4        <= in_pc_plus_4;
            out_rd1              <= in_rd1;
            out_rd2              <= in_rd2;
            out_imm              <= in_imm;
            out_rs1              <= in_rs1;
            out_rs2              <= in_rs2;
            out_rd               <= in_rd;
            out_funct3           <= in_funct3;
            out_funct7           <= in_funct7;
            out_predict_taken    <= in_predict_taken;
            out_predicted_target <= in_predicted_target;

            out_reg_write   <= in_reg_write;
            out_mem_read    <= in_mem_read;
            out_mem_write   <= in_mem_write;
            out_alu_src     <= in_alu_src;
            out_mem_to_reg  <= in_mem_to_reg;
            out_branch      <= in_branch;
            out_jump        <= in_jump;
            out_jalr        <= in_jalr;
            out_alu_control <= in_alu_control;
        end
    end
endmodule


//----------------------------------------------------------------------------
// EX/MEM
//----------------------------------------------------------------------------
module EX_MEM_Reg (
    input         clk,
    input         rst,
    // datapath in
    input  [31:0] in_pc_plus_4,
    input  [31:0] in_alu_result,
    input  [31:0] in_rs2_data,
    input  [4:0]  in_rd,
    // control in
    input         in_reg_write,
    input         in_mem_read,
    input         in_mem_write,
    input  [1:0]  in_mem_to_reg,
    // datapath out
    output reg [31:0] out_pc_plus_4,
    output reg [31:0] out_alu_result,
    output reg [31:0] out_rs2_data,
    output reg [4:0]  out_rd,
    // control out
    output reg        out_reg_write,
    output reg        out_mem_read,
    output reg        out_mem_write,
    output reg [1:0]  out_mem_to_reg
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_pc_plus_4  <= 32'd0;
            out_alu_result <= 32'd0;
            out_rs2_data   <= 32'd0;
            out_rd         <= 5'd0;
            out_reg_write  <= 1'b0;
            out_mem_read   <= 1'b0;
            out_mem_write  <= 1'b0;
            out_mem_to_reg <= 2'd0;
        end else begin
            out_pc_plus_4  <= in_pc_plus_4;
            out_alu_result <= in_alu_result;
            out_rs2_data   <= in_rs2_data;
            out_rd         <= in_rd;
            out_reg_write  <= in_reg_write;
            out_mem_read   <= in_mem_read;
            out_mem_write  <= in_mem_write;
            out_mem_to_reg <= in_mem_to_reg;
        end
    end
endmodule


//----------------------------------------------------------------------------
// MEM/WB
//----------------------------------------------------------------------------
module MEM_WB_Reg (
    input         clk,
    input         rst,
    // datapath in
    input  [31:0] in_pc_plus_4,
    input  [31:0] in_alu_result,
    input  [31:0] in_mem_data,
    input  [4:0]  in_rd,
    // control in
    input         in_reg_write,
    input  [1:0]  in_mem_to_reg,
    // out
    output reg [31:0] out_pc_plus_4,
    output reg [31:0] out_alu_result,
    output reg [31:0] out_mem_data,
    output reg [4:0]  out_rd,
    output reg        out_reg_write,
    output reg [1:0]  out_mem_to_reg
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_pc_plus_4  <= 32'd0;
            out_alu_result <= 32'd0;
            out_mem_data   <= 32'd0;
            out_rd         <= 5'd0;
            out_reg_write  <= 1'b0;
            out_mem_to_reg <= 2'd0;
        end else begin
            out_pc_plus_4  <= in_pc_plus_4;
            out_alu_result <= in_alu_result;
            out_mem_data   <= in_mem_data;
            out_rd         <= in_rd;
            out_reg_write  <= in_reg_write;
            out_mem_to_reg <= in_mem_to_reg;
        end
    end
endmodule
