//============================================================================
// wb_stage.v
//   WB stage: simple 3:1 write-back mux.
//     mem_to_reg  : 0 = ALU result
//                   1 = Memory load data
//                   2 = PC + 4   (jal / jalr link)
//============================================================================

module WB_Stage (
    input      [1:0]  mem_wb_mem_to_reg,
    input      [31:0] mem_wb_alu_result,
    input      [31:0] mem_wb_mem_data,
    input      [31:0] mem_wb_pc_plus_4,
    output reg [31:0] wb_wdata
);
    always @(*) begin
        case (mem_wb_mem_to_reg)
            2'd0:    wb_wdata = mem_wb_alu_result;
            2'd1:    wb_wdata = mem_wb_mem_data;
            2'd2:    wb_wdata = mem_wb_pc_plus_4;
            default: wb_wdata = mem_wb_alu_result;
        endcase
    end
endmodule
