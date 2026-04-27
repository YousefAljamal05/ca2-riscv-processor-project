`timescale 1ns / 1ps

module tb_IF_stage;

    // 1. Declare inputs as regs
    reg clk;
    reg reset;

    // 2. Declare outputs as wires
    wire [63:0] pc_out;
    wire [31:0] instruction_out;

    // 3. Instantiate the Unit Under Test (UUT)
    IF_stage uut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc_out),
        .instruction_out(instruction_out)
    );

    // 4. Clock Generation (Ticks every 5ns, full period = 10ns)
    always #5 clk = ~clk;

    // 5. Test Sequence
    initial begin
        // Setup Waveform generation for Wavetrace
        $dumpfile("if_stage_wave.vcd");
        $dumpvars(0, tb_IF_stage);

        // Initialize inputs
        clk = 0;
        reset = 1; // Turn ON reset initially to set PC to 0

        // Wait a bit, then turn OFF reset to let the PC start counting
        #10;
        reset = 0;

        // Let the simulation run for 50ns (5 clock cycles)
        // You should see pc_out go: 0 -> 4 -> 8 -> 12 -> 16
        // instruction_out should update based on what is in your instruction memory
        #50;

        // End simulation safely
        $finish;
    end

endmodule
