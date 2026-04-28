`timescale 1ns / 1ps

module EX_tb;

    // ----------------------------------------------------
    // 1. Signals Declaration (64-bit)
    // ----------------------------------------------------
    reg [63:0] current_pc, reg_a, reg_b, imm;
    reg [6:0]  opcode, funct7;
    reg [2:0]  funct3;
    
    wire [63:0] alu_result, next_pc;
    wire         take_branch;

    // Track total errors
    integer errors = 0;

    // ----------------------------------------------------
    // 2. Instantiate the ALU (UUT)
    // ----------------------------------------------------
    EX_Stage uut (
        .current_pc (current_pc),
        .reg_a      (reg_a),
        .reg_b      (reg_b),
        .imm        (imm),
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_result (alu_result),
        .next_pc    (next_pc),
        .take_branch(take_branch)
    );

    // ----------------------------------------------------
    // 3. Helper Task for Automatic Verification
    // ----------------------------------------------------
    task check_output;
        input [80*8:1] test_name; 
        input [63:0] exp_result;
        input [63:0] exp_next_pc;
        input        exp_branch;
        begin
            #1; // Wait for combinational logic to settle
            $display("--------------------------------------------------------------------------------");
            $display("TEST: %s", test_name);
            $display("INPUTS : PC=%0d | RegA=0x%016h | RegB=0x%016h | Imm=0x%016h", current_pc, reg_a, reg_b, imm);
            $display("EXPECT : Res=0x%016h | NextPC=%0d | Br=%b", exp_result, exp_next_pc, exp_branch);
            $display("ACTUAL : Res=0x%016h | NextPC=%0d | Br=%b", alu_result, next_pc, take_branch);
            
            if (alu_result !== exp_result || next_pc !== exp_next_pc || take_branch !== exp_branch) begin
                $display("STATUS : [FAIL] <== ERROR");
                errors = errors + 1;
            end else begin
                $display("STATUS : [PASS]");
            end
        end
    endtask

    // ----------------------------------------------------
    // 4. Main Test Sequence (The 16 Original Cases)
    // ----------------------------------------------------
    initial begin
        $dumpfile("alu_64_waves.vcd");
        $dumpvars(0, EX_tb);

        // Initialize
        current_pc = 64'd0; reg_a = 64'd0; reg_b = 64'd0; imm = 64'd0;
        opcode = 7'd0; funct3 = 3'd0; funct7 = 7'd0;

        $display("\n================ STARTING 64-BIT ALU TESTS ================");

        // --- 1. Add (R-Type) ---
        opcode = 7'h34; funct3 = 3'h1; funct7 = 7'h10;
        reg_a = 64'h0000_0000_FFFF_FFFF; reg_b = 64'h0000_0000_0000_0001;
        check_output("1. Add (64-bit Boundary)", 64'h0000_0001_0000_0000, 64'd0, 1'b0);

        // --- 2. Addi (I-Type) ---
        opcode = 7'h14; funct3 = 3'h1; 
        reg_a = 64'd100; imm = -64'd20; 
        check_output("2. Addi (100 - 20)", 64'd80, 64'd0, 1'b0);

        // --- 3. And (R-Type) ---
        opcode = 7'h34; funct3 = 3'h0; funct7 = 7'h10;
        reg_a = 64'h0F0F_0F0F_0F0F_0F0F; reg_b = 64'hF0F0_F0F0_F0F0_F0F0;
        check_output("3. And", 64'h0000_0000_0000_0000, 64'd0, 1'b0);

        // --- 4. Andi (I-Type) ---
        opcode = 7'h14; funct3 = 3'h0; 
        reg_a = 64'hFFFF_FFFF_FFFF_FFFF; imm = 64'h0000_0000_0000_00FF;
        check_output("4. Andi", 64'h0000_0000_0000_00FF, 64'd0, 1'b0);

        // --- 5a. BGE - TAKEN (Signed comparison) ---
        opcode = 7'h64; funct3 = 3'h6; 
        current_pc = 64'd1000; reg_a = 64'd5; reg_b = -64'd2; imm = 64'd12; // 12 << 1 = 24
        check_output("5a. BGE (Taken: 5 >= -2)", 64'd0, 64'd1024, 1'b1);

        // --- 5b. BGE - NOT TAKEN ---
        opcode = 7'h64; funct3 = 3'h6; 
        current_pc = 64'd1000; reg_a = -64'd5; reg_b = 64'd2; imm = 64'd12; 
        check_output("5b. BGE (Not Taken: -5 < 2)", 64'd0, 64'd0, 1'b0);

        // --- 6a. BNE - TAKEN ---
        opcode = 7'h64; funct3 = 3'h2; 
        current_pc = 64'd500; reg_a = 64'd10; reg_b = 64'd11; imm = 64'd8; // 8 << 1 = 16
        check_output("6a. BNE (Taken: 10 != 11)", 64'd0, 64'd516, 1'b1);

        // --- 6b. BNE - NOT TAKEN ---
        opcode = 7'h64; funct3 = 3'h2; 
        current_pc = 64'd500; reg_a = 64'd10; reg_b = 64'd10; imm = 64'd8;
        check_output("6b. BNE (Not Taken: 10 == 10)", 64'd0, 64'd0, 1'b0);

        // --- 7. Jal (UJ-Type) ---
        opcode = 7'h70; 
        current_pc = 64'd200; imm = 64'd20; // 20 << 1 = 40. NextPC = 240. Result = 204
        check_output("7. Jal (Jump And Link)", 64'd204, 64'd240, 1'b1);

        // --- 8. Jalr (I-Type Jump) ---
        opcode = 7'h68; funct3 = 3'h1; 
        current_pc = 64'd300; reg_a = 64'd1000; imm = 64'd44; // NextPC = 1044. Result = 304
        check_output("8. Jalr (Jump And Link Register)", 64'd304, 64'd1044, 1'b1);

        // --- 9. Ld (I-Type Memory Address) ---
        opcode = 7'h14; funct3 = 3'h3; 
        reg_a = 64'd4000; imm = 64'd16; 
        check_output("9. Ld (Address Calculation)", 64'd4016, 64'd0, 1'b0);

        // --- 10. Xor (R-Type) ---
        opcode = 7'h34; funct3 = 3'h5; funct7 = 7'h10;
        reg_a = 64'hAAAA_AAAA_AAAA_AAAA; reg_b = 64'h5555_5555_5555_5555;
        check_output("10. Xor", 64'hFFFF_FFFF_FFFF_FFFF, 64'd0, 1'b0);

        // --- 11. Or (R-Type) ---
        opcode = 7'h34; funct3 = 3'h7; funct7 = 7'h10;
        reg_a = 64'h0000_FFFF_0000_0000; reg_b = 64'h0000_0000_FFFF_0000;
        check_output("11. Or", 64'h0000_FFFF_FFFF_0000, 64'd0, 1'b0);

        // --- 12. Ori (I-Type) ---
        opcode = 7'h14; funct3 = 3'h7; 
        reg_a = 64'h0; imm = 64'h1234_5678_9ABC_DEF0;
        check_output("12. Ori", 64'h1234_5678_9ABC_DEF0, 64'd0, 1'b0);

        // --- 13. Sltu (Unsigned comparison) ---
        opcode = 7'h34; funct3 = 3'h4; funct7 = 7'h01;
        reg_a = 64'd10; reg_b = 64'd20; 
        check_output("13. Sltu (10 < 20)", 64'd1, 64'd0, 1'b0);

        // --- 14. Srl (Logical Shift Right) ---
        opcode = 7'h34; funct3 = 3'h6; funct7 = 7'h10;
        reg_a = 64'hF000_0000_0000_0000; reg_b = 64'd4; 
        check_output("14. Srl", 64'h0F00_0000_0000_0000, 64'd0, 1'b0);

        // --- 15. Sra (Arithmetic Shift Right) ---
        opcode = 7'h34; funct3 = 3'h6; funct7 = 7'h30;
        reg_a = 64'hF000_0000_0000_0000; reg_b = 64'd4; 
        check_output("15. Sra (Sign Extension)", 64'hFF00_0000_0000_0000, 64'd0, 1'b0);

        // --- 16. Sd (S-Type Memory Address) ---
        opcode = 7'h24; funct3 = 3'h3; 
        reg_a = 64'd8000; imm = 64'd32; 
        check_output("16. Sd (Address Calculation)", 64'd8032, 64'd0, 1'b0);

        // ----------------------------------------------------
        // 5. Final Report
        // ----------------------------------------------------
        $display("\n===========================================================");
        if (errors == 0)
            $display("  SUCCESS: All 16 64-bit operations passed!");
        else
            $display("  WARNING: %0d tests FAILED.", errors);
        $display("===========================================================\n");

        $finish;
    end

endmodule
