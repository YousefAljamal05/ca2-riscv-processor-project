`timescale 1ns/1ps
//==========================================================
// Testbench for PC Module
// Purpose:
//   Tests the behavior of the PC module by applying:
//   - reset
//   - different next_pc values
//   and observing how pc changes over time
//
// Also generates a waveform file (.vcd) so signals can be
// viewed in a waveform viewer.
//==========================================================
// ( MAKE THEM ON THE SAME FILE )

module tb_pc;

    // Testbench signals
    reg clk;                 // Clock signal
    reg reset;               // Reset signal
    reg [63:0] next_pc;      // Input to the PC module
    wire [63:0] pc;          // Output from the PC module

    // Instantiate the PC module under test
    pc uut (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );

    // Clock generation
    // Toggle clock every 5 ns
    // Full clock period = 10 ns
    always #5 clk = ~clk;

    initial begin
        // Create waveform file
        // This file will store signal changes during simulation
        $dumpfile("pc_wave.vcd");

        // Dump all signals inside tb_pc into the waveform file
        $dumpvars(0, tb_pc);

        // Print a message when simulation starts
        $display("Starting PC test...");

        // Continuously print signal values whenever any monitored signal changes
        $monitor("Time=%0t | clk=%b | reset=%b | next_pc=%d | pc=%d", $time, clk, reset, next_pc, pc);

        // Initialize signals
        clk = 0;
        reset = 1;           // Start with reset active
        next_pc = 64'd4;     // Initial next_pc value

        // Keep reset active for 10 ns
        #10;
        reset = 0;           // Release reset

        // Apply different next_pc values every 10 ns
        #10 next_pc = 64'd4;
        #10 next_pc = 64'd8;
        #10 next_pc = 64'd12;
        #10 next_pc = 64'd16;

        // End simulation after some extra time
        #20;
        $finish;
    end

endmodule
