`timescale 1ns/1ps
//==========================================================
// Tests extraction and 64-bit sign-extension
// of I, S, SB, and UJ type immediates.
//==========================================================

module tb_imm_gen;

    reg  [31:0] instruction;
    reg  [2:0]  imm_type;
    wire [63:0] imm_out;

    // Instantiate Immediate Generator
    imm_gen uut (
        .instruction(instruction),
        .imm_type(imm_type),
        .imm_out(imm_out)
    );

    initial begin
        //--------------------------------------------------
        // I-Type Example
        // imm = 10 (0000000001010)
        //--------------------------------------------------
        instruction = 32'b000000000101_00000_000_00000_0000000;
        imm_type = 3'b000;
        #10;
        $display("I-Type Immediate =          %d", imm_out);

        //--------------------------------------------------
        // S-Type Example
        // imm = 20 (0000000010100)
        //--------------------------------------------------
        instruction = 32'b0000001_00000_00000_000_00100_0000000;
        imm_type = 3'b001;
        #10;
        $display("S-Type Immediate =          %d", imm_out);

        //--------------------------------------------------
        // SB-Type Example (branch offset)
        // small positive offset example
        //--------------------------------------------------
        instruction = 32'b0_000001_00000_00000_000_0001_0_0000000;
        imm_type = 3'b010;
        #10;
        $display("SB-Type Immediate =         %d", imm_out);

        //--------------------------------------------------
        // UJ-Type Example (jal offset)
        //--------------------------------------------------
        instruction = 32'b0_00000000_1_0000000000_00000_0000000;
        imm_type = 3'b011;
        #10;
        $display("UJ-Type Immediate =         %d", imm_out);

        //--------------------------------------------------
        // Negative I-Type Example (imm = -4)
        //--------------------------------------------------
        instruction = 32'b111111111100_00000_000_00000_0000000;
        imm_type = 3'b000;
        #10;
        $display("Negative I-Type Immediate = %d", $signed(imm_out));

        #10;
        $finish;
    end

endmodule
