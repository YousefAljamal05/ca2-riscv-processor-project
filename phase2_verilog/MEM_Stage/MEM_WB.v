module MEM_WB (
    input wire clk,
    input wire reset,

    // Control In (from EX_MEM)
    input wire reg_write_in,
    input wire mem_to_reg_in,

    // Data In (from MEM Stage)
    input wire [63:0] read_data_in,
    input wire [63:0] alu_result_in,
    input wire [4:0]  rd_in,

    // Control Out (to Writeback logic)
    output reg reg_write_out,
    output reg mem_to_reg_out,

    // Data Out (to Writeback logic)
    output reg [63:0] read_data_out,
    output reg [63:0] alu_result_out,
    output reg [4:0]  rd_out
);

    always @(posedge clk) begin
        if (reset) begin
            reg_write_out  <= 0;
            mem_to_reg_out <= 0;
            read_data_out  <= 64'd0;
            alu_result_out <= 64'd0;
            rd_out         <= 5'd0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            read_data_out  <= read_data_in;
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
        end
    end

endmodule
