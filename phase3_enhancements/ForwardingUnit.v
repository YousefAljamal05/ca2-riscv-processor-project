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
