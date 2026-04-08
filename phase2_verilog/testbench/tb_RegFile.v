`timescale 1ns/1ps
//==========================================================
// Testbench for 64-bit Register File
//
// This testbench:
// - Generates clock
// - Writes values to registers
// - Reads values back
// - Confirms x0 remains zero
// - Generates waveform file
//==========================================================

module tb_register_file;

    reg clk;
    reg reg_write;
    reg [4:0] rs1, rs2, rd;
    reg [63:0] write_data;
    wire [63:0] read_data1, read_data2;

    // Instantiate Register File
    register_file uut (
        .clk(clk),
        .reg_write(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("rf64_wave.vcd");
        $dumpvars(0, tb_register_file);

        $display("Testing 64-bit Register File");

        clk = 0;
        reg_write = 0;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        write_data = 0;

        // Write 100 into x1
        #2;
        reg_write = 1;
        rd = 5'd1;
        write_data = 64'd100;
        #10;

        // Write 500 into x2
        rd = 5'd2;
        write_data = 64'd500;
        #10;

        // Stop writing
        reg_write = 0;

        // Read x1 and x2
        rs1 = 5'd1;
        rs2 = 5'd2;
        #10;

        // Try writing into x0 (should not change)
        reg_write = 1;
        rd = 5'd0;
        write_data = 64'd999;
        #10;

        reg_write = 0;
        rs1 = 5'd0;
        rs2 = 5'd1;
        #10;

        $finish;
    end

endmodule
