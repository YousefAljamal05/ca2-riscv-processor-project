`timescale 1ns/1ps
//==========================================================
// Testbench for Instruction Memory
// Purpose:
//   Applies different PC values and checks whether the
//   instruction memory returns the correct 32-bit instruction.
//==========================================================

module tb_instruction_memory;

    // Testbench input signal
    reg [31:0] pc;

    // Testbench output signal
    wire [31:0] instruction;

    // Instantiate the instruction memory module
    instruction_memory uut (
        .pc(pc),
        .instruction(instruction)
    );

        // Print header
        $display("Testing Instruction Memory...");
        $display("-------------------------------------------");
        $display(" Time   |   pc   |   instruction");
        $display("-------------------------------------------");

        // Continuously monitor changes
        $monitor("%-7t | %-6d | 0x%h", $time, pc, instruction);

        // --------------------------------------------------
        // Generate PC signal values
        // --------------------------------------------------

        // Test first instruction
        pc = 32'd0;
        #10;

        // Test second instruction
        pc = 32'd4;
        #10;

        // Test third instruction
        pc = 32'd8;
        #10;

        // End simulation
        $finish;
    end

endmodule
