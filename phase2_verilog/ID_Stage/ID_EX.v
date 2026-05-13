//==========================================================
// ID/EX PIPELINE REGISTER
//==========================================================
// Function: Holds decoded data and control signals safely 
// for the Execute stage on the next clock cycle.
//==========================================================

module ID_EX (
    input wire clk,
    input wire reset,

    // Control Signals In
    input wire reg_write_in, mem_read_in, mem_write_in, alu_src_in, mem_to_reg_in,
    input wire [3:0] alu_control_in,

    // Data In
    input wire [63:0] pc_in,
    input wire [63:0] read_data1_in,
    input wire [63:0] read_data2_in,
    input wire [63:0] imm_in,
    input wire [4:0] rd_in,

    // Control Signals Out
    output reg reg_write_out, mem_read_out, mem_write_out, alu_src_out, mem_to_reg_out,
    output reg [3:0] alu_control_out,

    // Data Out
    output reg [63:0] pc_out,
    output reg [63:0] read_data1_out,
    output reg [63:0] read_data2_out,
    output reg [63:0] imm_out,
    output reg [4:0] rd_out
);

    always @(posedge clk) begin
        if (reset) begin
            reg_write_out   <= 0;
            mem_read_out    <= 0;
            mem_write_out   <= 0;
            alu_src_out     <= 0;
            mem_to_reg_out  <= 0;
            alu_control_out <= 4'b0000;
            pc_out          <= 64'd0;
            read_data1_out  <= 64'd0;
            read_data2_out  <= 64'd0;
            imm_out         <= 64'd0;
            rd_out          <= 5'd0;
        end else begin
            reg_write_out   <= reg_write_in;
            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;
            alu_src_out     <= alu_src_in;
            mem_to_reg_out  <= mem_to_reg_in;
            alu_control_out <= alu_control_in;
            pc_out          <= pc_in;
            read_data1_out  <= read_data1_in;
            read_data2_out  <= read_data2_in;
            imm_out         <= imm_in;
            rd_out          <= rd_in;
        end
    end

endmodule
