`timescale 1ns / 1ps

module tb_WB_stage;

    // 1. Declare inputs as regs
    reg         mem_to_reg;
    reg  [63:0] alu_result;
    reg  [63:0] mem_data;

    // 2. Declare outputs as wires
    wire [63:0] write_back_data;

    // 3. Instantiate the Unit Under Test (UUT)
    WB_stage uut (
        .mem_to_reg(mem_to_reg),
        .alu_result(alu_result),
        .mem_data(mem_data),
        .write_back_data(write_back_data)
    );

    // 4. Test Sequence
    initial begin
        // Waveform generation setup
        $dumpfile("wb_stage_wave.vcd");
        $dumpvars(0, tb_WB_stage);

        // Terminal output monitor
        $display("=========================================================================================");
        $display("Time | mem_to_reg | ALU Result           | Memory Data          | Write Back Data      ");
        $display("=========================================================================================");
        $monitor("%4t |          %b | %20h | %20h | %20h", 
                 $time, mem_to_reg, alu_result, mem_data, write_back_data);

        // --- TEST VECTORS ---

        // Test Case 1: Select ALU Result (R-Type or I-Type math instructions)
        // mem_to_reg = 0, so write_back_data should equal alu_result
        alu_result = 64'hAAAA_BBBB_CCCC_DDDD;
        mem_data   = 64'h1111_2222_3333_4444;
        mem_to_reg = 1'b0;
        #10;

        // Test Case 2: Select Memory Data (Load instructions like LD)
        // mem_to_reg = 1, so write_back_data should switch to mem_data
        mem_to_reg = 1'b1;
        #10;

        // Test Case 3: Change incoming memory data while still selecting it
        mem_data   = 64'hFFFF_FFFF_0000_0000;
        #10;

        // Test Case 4: Switch back to ALU result
        mem_to_reg = 1'b0;
        #10;

        // End simulation safely
        $display("=========================================================================================");
        $finish;
    end

endmodule
