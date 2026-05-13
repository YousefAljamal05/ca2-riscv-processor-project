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
