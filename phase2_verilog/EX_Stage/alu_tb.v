`timescale 1ns / 1ps

module alu_tb;

    // ----------------------------------------------------
    // 1. Signals Declaration
    // ----------------------------------------------------
    reg [31:0] current_pc, reg_a, reg_b, imm;
    reg [6:0]  opcode, funct7;
    reg [2:0]  funct3;
    
    wire [31:0] alu_result, next_pc;
    wire        take_branch;

    // Track total errors
    integer errors = 0;

    // ----------------------------------------------------
    // 2. Instantiate the ALU
    // ----------------------------------------------------
    alu uut (
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
        input [80*8:1] test_name; // String up to 80 chars
        input [31:0] exp_result;
        input [31:0] exp_next_pc;
        input        exp_branch;
        begin
            #1; // Wait for combinational logic to settle
            $display("--------------------------------------------------------------------------------");
            $display("TEST: %s", test_name);
            $display("INPUTS : PC=%0d | RegA=0x%08h | RegB=0x%08h | Imm=0x%08h", current_pc, reg_a, reg_b, imm);
            $display("OUTPUTS: Result=0x%08h | NextPC=%0d | Branch=%b", alu_result, next_pc, take_branch);
            $display("EXPECT : Result=0x%08h | NextPC=%0d | Branch=%b", exp_result, exp_next_pc, exp_branch);
            
            if (alu_result !== exp_result || next_pc !== exp_next_pc || take_branch !== exp_branch) begin
                $display("STATUS : [FAIL] <==== ERROR HERE!");
                errors = errors + 1;
            end else begin
                $display("STATUS : [PASS]");
            end
        end
    endtask

    // ----------------------------------------------------
    // 4. Main Test Sequence
    // ----------------------------------------------------
    initial begin
        // Waveform generation for GTKWave
        $dumpfile("alu_waves.vcd");
        $dumpvars(0, alu_tb);

        // Initialize
        current_pc = 32'd0; reg_a = 32'd0; reg_b = 32'd0; imm = 32'd0;
        opcode = 7'd0; funct3 = 3'd0; funct7 = 7'd0;

        $display("\n================================================================================");
        $display("                          STARTING EXTENSIVE ALU TESTS                            ");
        $display("================================================================================");

        // --- 1. Addw (R-Type) ---
        opcode = 7'h34; funct3 = 3'h1; funct7 = 7'h10;
        reg_a = 32'd50; reg_b = 32'd25;
        check_output("1. Addw (R[rd] = R[rs1] + R[rs2])", 32'd75, 32'd0, 1'b0);

        // --- 2. Addiw (I-Type) ---
        opcode = 7'h14; funct3 = 3'h1; 
        reg_a = 32'd100; imm = -32'd20; // 100 - 20 = 80 (0x50)
        check_output("2. Addiw (R[rd] = R[rs1] + imm)", 32'd80, 32'd0, 1'b0);

        // --- 3. And (R-Type) ---
        opcode = 7'h34; funct3 = 3'h0; funct7 = 7'h10;
        reg_a = 32'h0F0F_0F0F; reg_b = 32'hF0F0_F0F0;
        check_output("3. And (R[rd] = R[rs1] & R[rs2])", 32'h0000_0000, 32'd0, 1'b0);

        // --- 4. Andi (I-Type) ---
        opcode = 7'h14; funct3 = 3'h0; 
        reg_a = 32'hFFFF_FFFF; imm = 32'h0000_00FF;
        check_output("4. Andi (R[rd] = R[rs1] & imm)", 32'h0000_00FF, 32'd0, 1'b0);

        // --- 5a. BGE - TAKEN (Signed comparison) ---
        opcode = 7'h64; funct3 = 3'h6; 
        current_pc = 32'd1000; reg_a = 32'd5; reg_b = -32'd2; imm = 32'd12; // 12 << 1 = 24
        check_output("5a. BGE (Taken: 5 >= -2)", 32'd0, 32'd1024, 1'b1);

        // --- 5b. BGE - NOT TAKEN ---
        opcode = 7'h64; funct3 = 3'h6; 
        current_pc = 32'd1000; reg_a = -32'd5; reg_b = 32'd2; imm = 32'd12; 
        check_output("5b. BGE (Not Taken: -5 < 2)", 32'd0, 32'd0, 1'b0);

        // --- 6a. BNE - TAKEN ---
        opcode = 7'h64; funct3 = 3'h2; 
        current_pc = 32'd500; reg_a = 32'd10; reg_b = 32'd11; imm = 32'd8; // 8 << 1 = 16
        check_output("6a. BNE (Taken: 10 != 11)", 32'd0, 32'd516, 1'b1);

        // --- 6b. BNE - NOT TAKEN ---
        opcode = 7'h64; funct3 = 3'h2; 
        current_pc = 32'd500; reg_a = 32'd10; reg_b = 32'd10; imm = 32'd8;
        check_output("6b. BNE (Not Taken: 10 == 10)", 32'd0, 32'd0, 1'b0);

        // --- 7. Jal (UJ-Type) ---
        opcode = 7'h70; 
        current_pc = 32'd200; imm = 32'd20; // 20 << 1 = 40. NextPC = 240. Result = 204
        check_output("7. Jal (Jump And Link)", 32'd204, 32'd240, 1'b1);

        // --- 8. Jalr (I-Type Jump) ---
        opcode = 7'h68; funct3 = 3'h1; 
        current_pc = 32'd300; reg_a = 32'd1000; imm = 32'd44; // NextPC = 1044. Result = 304
        check_output("8. Jalr (Jump And Link Register)", 32'd304, 32'd1044, 1'b1);

        // --- 9. Lw (I-Type Memory) ---
        opcode = 7'h14; funct3 = 3'h3; 
        reg_a = 32'd4000; imm = 32'd16; // 4000 + 16 = 4016
        check_output("9. Lw (Address Calculation)", 32'd4016, 32'd0, 1'b0);

        // --- 10. Xor (R-Type) ---
        opcode = 7'h34; funct3 = 3'h5; funct7 = 7'h10;
        reg_a = 32'hAAAA_AAAA; reg_b = 32'h5555_5555;
        check_output("10. Xor (R[rd] = R[rs1] ^ R[rs2])", 32'hFFFF_FFFF, 32'd0, 1'b0);

        // --- 11. Or (R-Type) ---
        opcode = 7'h34; funct3 = 3'h7; funct7 = 7'h10;
        reg_a = 32'h00FF_0000; reg_b = 32'h0000_FF00;
        check_output("11. Or (R[rd] = R[rs1] | R[rs2])", 32'h00FF_FF00, 32'd0, 1'b0);

        // --- 12. Ori (I-Type) ---
        opcode = 7'h14; funct3 = 3'h7; 
        reg_a = 32'h0000_0000; imm = 32'h1234_5678;
        check_output("12. Ori (R[rd] = R[rs1] | imm)", 32'h1234_5678, 32'd0, 1'b0);

        // --- 13a. sltu - TRUE (Unsigned comparison) ---
        opcode = 7'h34; funct3 = 3'h4; funct7 = 7'h01;
        reg_a = 32'd10; reg_b = 32'd20; 
        check_output("13a. Sltu (True: 10 < 20)", 32'd1, 32'd0, 1'b0);

        // --- 13b. sltu - FALSE ---
        opcode = 7'h34; funct3 = 3'h4; funct7 = 7'h01;
        reg_a = 32'd20; reg_b = 32'd10; 
        check_output("13b. Sltu (False: 20 > 10)", 32'd0, 32'd0, 1'b0);

        // --- 14. srl (Logical Shift Right) ---
        opcode = 7'h34; funct3 = 3'h6; funct7 = 7'h10;
        reg_a = 32'hF000_0000; reg_b = 32'd4; // Shift right by 4. F becomes 0, so 0x0F000000
        check_output("14. Srl (Logical Shift Right)", 32'h0F00_0000, 32'd0, 1'b0);

        // --- 15. sra (Arithmetic Shift Right) ---
        opcode = 7'h34; funct3 = 3'h6; funct7 = 7'h30;
        reg_a = 32'hF000_0000; reg_b = 32'd4; // Shift arithmetic 4. Sign extends, so 0xFF000000
        check_output("15. Sra (Arithmetic Shift Right)", 32'hFF00_0000, 32'd0, 1'b0);

        // --- 16. sw (S-Type Memory) ---
        opcode = 7'h24; funct3 = 3'h3; 
        reg_a = 32'd8000; imm = 32'd32; // 8000 + 32 = 8032
        check_output("16. Sw (Address Calculation)", 32'd8032, 32'd0, 1'b0);

        // ----------------------------------------------------
        // 5. Final Report
        // ----------------------------------------------------
        $display("\n================================================================================");
        if (errors == 0)
            $display("  SUCCESS: All operations passed! The ALU is ready for the pipeline.  ");
        else
            $display("  WARNING: %0d tests FAILED. Check the logs above. ", errors);
        $display("================================================================================\n");

        $finish;
    end

endmodule