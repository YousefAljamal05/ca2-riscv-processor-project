//==========================================================
// EX/MEM PIPELINE REGISTER
//==========================================================

module EX_MEM (
    input wire clk,
    input wire reset,

    // Control Signals In (from ID_EX)
    input wire reg_write_in, mem_read_in, mem_write_in, mem_to_reg_in,

    // Data In (from EX Stage)
    input wire [63:0] alu_result_in,
    input wire [63:0] reg_b_in,      // Data to store in memory
    input wire [4:0]  rd_in,

    // Control Signals Out
    output reg reg_write_out, mem_read_out, mem_write_out, mem_to_reg_out,

    // Data Out
    output reg [63:0] alu_result_out,
    output reg [63:0] write_data_out,
    output reg [4:0]  rd_out
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
            write_data_out <= reg_b_in;
            rd_out         <= rd_in;
        end
    end

endmodule
