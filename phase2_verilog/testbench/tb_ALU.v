`timescale 1ns / 1ps

module tb_ALU;

    // 1. Declare inputs as regs
    reg [63:0] A;
    reg [63:0] B;
    reg [2:0]  ALUOP;

    // 2. Declare outputs as wires
    wire [63:0] result;
    wire        ZF;
    wire        BF;

    // 3. Instantiate the ALU
    ALU uut (
        .A(A), 
        .B(B), 
        .ALUOP(ALUOP),
        .result(result), 
        .ZF(ZF), 
        .BF(BF)
    );

    // 4. Test Sequence
    initial begin
        // Waveform generation
        $dumpfile("alu_wave.vcd");
        $dumpvars(0, tb_ALU);
        
        // Terminal output monitor
        $display("Time | OP  | A                    | B                    | Result               | ZF | BF");
        $display("-----------------------------------------------------------------------------------------");
        $monitor("%4t | %b | %20d | %20d | %20d |  %b |  %b", $time, ALUOP, A, B, result, ZF, BF);

        // --- TEST CASES ---
        
        // 1. ADD (OP: 000)
        ALUOP = 3'b000; A = 64'd15; B = 64'd10; #10;
        
        // 2. SUB (OP: 001) - Normal subtraction
        ALUOP = 3'b001; A = 64'd20; B = 64'd5;  #10;
        
        // 3. SUB (OP: 001) - Test Zero Flag (A == B)
        ALUOP = 3'b001; A = 64'd10; B = 64'd10; #10;
        
        // 4. SUB (OP: 001) - Test Branch Flag (A < B, signed)
        ALUOP = 3'b001; A = -64'd5; B = 64'd10; #10;
        
        // 5. AND (OP: 010)
        ALUOP = 3'b010; A = 64'b1100; B = 64'b1010; #10;
        
        // 6. OR (OP: 011)
        ALUOP = 3'b011; A = 64'b1100; B = 64'b1010; #10;
        
        // 7. XOR (OP: 100)
        ALUOP = 3'b100; A = 64'b1100; B = 64'b1010; #10;
        
        // 8. SRL - Shift Right Logical (OP: 101)
        ALUOP = 3'b101; A = 64'd16; B = 64'd2; #10;
        
        // 9. SRA - Shift Right Arithmetic (OP: 110)
        ALUOP = 3'b110; A = -64'd16; B = 64'd2; #10;
        
        // 10. SLTU - Set Less Than Unsigned (OP: 111)
        ALUOP = 3'b111; A = 64'd5; B = 64'd25; #10;

        // End simulation safely
        #10 $finish;
    end

endmodule
