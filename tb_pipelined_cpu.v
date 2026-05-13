//==========================================================================
// PHASE 3 - TESTBENCH
//
// Runs six benchmarks against the pipelined CPU:
//   1. ALU-ALU forwarding   (EX hazard)
//   2. Load-use hazard      (must stall 1 cycle)
//   3. Double data hazard   (EX vs MEM priority)
//   4. Branch (taken)
//   5. If-statement
//   6. Loop
//
// Select benchmark with `define BENCH n` (or change the parameter below).
// Simulator command examples:
//    iverilog -o sim rv64_pipelined_cpu.v tb_pipelined_cpu.v
//    vvp sim                                       (runs default BENCH = 1)
//    vvp sim +BENCH=4                              (runs benchmark 4)
//==========================================================================

`timescale 1ns/1ps

module tb_pipelined_cpu;

    reg clk;
    reg reset;
    reg [31:0] dynamic_nop_addr;

    // Instantiate the design under test
    rv64_pipelined_cpu dut (
        .clk(clk),
        .reset(reset)
    );

    // -------------------------------------------------------- clock
    initial clk = 0;
    always #5 clk = ~clk;     // 10ns period, 100 MHz

    // -------------------------------------------------------- benchmark selector
    integer BENCH;
    integer max_cycles;
    integer i;

    // helper: write a 32-bit instruction in little-endian into IM
    task put_instr(input integer addr, input [31:0] word);
        begin
            dut.IM.mem[addr+0] = word[7:0];
            dut.IM.mem[addr+1] = word[15:8];
            dut.IM.mem[addr+2] = word[23:16];
            dut.IM.mem[addr+3] = word[31:24];
        end
    endtask

    // Task to automatically load instructions and return the final address
    task load_hex_file;
        input  [255*8:1] filename;
        output [31:0]    end_addr; // <--- NEW: Sends the final address back
        
        reg [31:0] temp_mem [0:1023];
        integer i;
        integer last_index;
        begin
            last_index = 0;
            
            // 1. Fill the buffer with X's
            for (i = 0; i < 1024; i = i + 1) begin
                temp_mem[i] = 32'hxxxxxxxx; 
            end
            
            // 2. Read the hex text file into the buffer array
            $readmemh(filename, temp_mem);
            
            // 3. Loop through and load instructions into your memory
            for (i = 0; i < 1024; i = i + 1) begin
                if (temp_mem[i] !== 32'hxxxxxxxx) begin
                    put_instr(i * 4, temp_mem[i]); 
                    last_index = i; // Keep tracking the highest index we hit
                end
            end
            
            // 4. Calculate the very next available address (index + 1, multiplied by 4)
            end_addr = (last_index + 1) * 4;
            
            $display(">>> Successfully loaded instructions from %s", filename);
            $display(">>> Next available address for NOPs: %0d", end_addr);
        end
    endtask

    // helper: fill rest of IM with NOP (addi x0,x0,0 = 0x00000013)
    task fill_nops(input integer start_addr);
        integer a;
        begin
            for (a = start_addr; a < 256; a = a + 4)
                put_instr(a, 32'h00000013);
        end
    endtask

    // helper: dump key registers
    task dump_regs;
        begin
            $display("------------------------------------------------------------");
            $display(" t=%0t  PC=0x%0h", $time, dut.pc_current);
            $display("  x1 = %0d (0x%0h)", $signed(dut.RF.regs[1]), dut.RF.regs[1]);
            $display("  x2 = %0d (0x%0h)", $signed(dut.RF.regs[2]), dut.RF.regs[2]);
            $display("  x3 = %0d (0x%0h)", $signed(dut.RF.regs[3]), dut.RF.regs[3]);
            $display("  x4 = %0d (0x%0h)", $signed(dut.RF.regs[4]), dut.RF.regs[4]);
            $display("  x5 = %0d (0x%0h)", $signed(dut.RF.regs[5]), dut.RF.regs[5]);
            $display("  x6 = %0d (0x%0h)", $signed(dut.RF.regs[6]), dut.RF.regs[6]);
            $display("  x7 = %0d (0x%0h)", $signed(dut.RF.regs[7]), dut.RF.regs[7]);
            $display("  x8 = %0d (0x%0h)", $signed(dut.RF.regs[8]), dut.RF.regs[8]);
            $display("  x9 = %0d (0x%0h)", $signed(dut.RF.regs[9]), dut.RF.regs[9]);
            $display("------------------------------------------------------------");
        end
    endtask

    // -------------------------------------------------------- LOAD BENCHMARK
    task load_benchmark(input integer n);
        begin
            // Clear memory first
            for (i = 0; i < 256; i = i + 1)
                dut.IM.mem[i] = 8'h00;

            case (n)
            //-----------------------------------------------------------
            // BENCHMARK 1 : ALU-ALU forwarding (EX & MEM)
            //-----------------------------------------------------------
            1: begin
                $display("\n>>> BENCHMARK 1 : ALU-ALU FORWARDING\n");
                put_instr( 0, 32'h00500093);  // addi x1, x0, 5
                put_instr( 4, 32'h00a00113);  // addi x2, x0, 10
                put_instr( 8, 32'h002081b3);  // add  x3, x1, x2     -> x3 = 15
                put_instr(12, 32'h40118233);  // sub  x4, x3, x1     -> x4 = 10  (EX hazard on x3)
                put_instr(16, 32'h003272b3);  // and  x5, x4, x3     -> x5 = 10 AND 15 = 10 (EX on x4, MEM on x3)
                put_instr(20, 32'h0042e333);  // or   x6, x5, x4     -> x6 = 10 | 10 = 10 (EX on x5, MEM on x4)
                fill_nops(24);
                max_cycles = 30;
            end

            //-----------------------------------------------------------
            // BENCHMARK 2 : Load-use hazard
            //-----------------------------------------------------------
            2: begin
                $display("\n>>> BENCHMARK 2 : LOAD-USE HAZARD\n");
                put_instr( 0, 32'h00000093);  // addi x1, x0, 0
                put_instr( 4, 32'h06300113);  // addi x2, x0, 99
                put_instr( 8, 32'h0020b023);  // sd   x2, 0(x1)
                put_instr(12, 32'h0000b183);  // ld   x3, 0(x1)      -> x3 = 99
                put_instr(16, 32'h00118233);  // add  x4, x3, x1     <- LOAD-USE: needs stall
                put_instr(20, 32'h00120293);  // addi x5, x4, 1      -> EX hazard on x4
                fill_nops(24);
                max_cycles = 30;
            end

            //-----------------------------------------------------------
            // BENCHMARK 3 : Double data hazard (EX vs MEM priority)
            //-----------------------------------------------------------
            3: begin
                $display("\n>>> BENCHMARK 3 : DOUBLE DATA HAZARD\n");
                put_instr( 0, 32'h00200113);  // addi x2, x0, 2
                put_instr( 4, 32'h00300193);  // addi x3, x0, 3
                put_instr( 8, 32'h00400213);  // addi x4, x0, 4
                put_instr(12, 32'h003100b3);  // add  x1, x2, x3      -> x1 = 5
                put_instr(16, 32'h004080b3);  // add  x1, x1, x4      -> x1 = 9  (EX hazard)
                put_instr(20, 32'h004082b3);  // add  x5, x1, x4      -> x5 = 13 (MEM hazard, take newer x1)
                fill_nops(24);
                max_cycles = 30;
            end

            //-----------------------------------------------------------
            // BENCHMARK 4 : Branch taken
            //-----------------------------------------------------------
            4: begin
                $display("\n>>> BENCHMARK 4 : BRANCH (TAKEN)\n");
                put_instr( 0, 32'h00500093);  // addi x1, x0, 5
                put_instr( 4, 32'h00500113);  // addi x2, x0, 5
                put_instr( 8, 32'h00208663);  // beq  x1, x2, +12      <- taken
                put_instr(12, 32'h0aa00193);  // addi x3, x0, 0xAA     <- SHOULD BE FLUSHED
                put_instr(16, 32'h0bb00213);  // addi x4, x0, 0xBB     <- SHOULD BE FLUSHED
                put_instr(20, 32'h05500293);  // addi x5, x0, 0x55     <- branch target
                fill_nops(24);
                max_cycles = 30;
            end

            //-----------------------------------------------------------
            // BENCHMARK 5 : If statement
            //-----------------------------------------------------------
            5: begin
                $display("\n>>> BENCHMARK 5 : IF-STATEMENT\n");
                put_instr( 0, 32'h00700093);  // addi x1, x0, 7
                put_instr( 4, 32'h00800113);  // addi x2, x0, 8
                put_instr( 8, 32'h00208663);  // beq  x1, x2, +12      <- NOT taken (7 != 8)
                put_instr(12, 32'h00200193);  // addi x3, x0, 2        <- ELSE branch (executes)
                put_instr(16, 32'h0080006f);  // jal  x0, +8           <- skip THEN
                put_instr(20, 32'h00100193);  // addi x3, x0, 1        <- THEN branch (SKIPPED)
                put_instr(24, 32'h06300213);  // addi x4, x0, 99       <- joiner
                fill_nops(28);
                max_cycles = 35;
            end

            //-----------------------------------------------------------
            // BENCHMARK 6 : Loop
            //-----------------------------------------------------------
            6: begin
                $display("\n>>> BENCHMARK 6 : LOOP (sum 1..4 = 10)\n");
                put_instr( 0, 32'h00000093);  // addi x1, x0, 0     i  = 0
                put_instr( 4, 32'h00400113);  // addi x2, x0, 4     n  = 4
                put_instr( 8, 32'h00000193);  // addi x3, x0, 0     sum= 0
                // loop:
                put_instr(12, 32'h00108093);  // addi x1, x1, 1
                put_instr(16, 32'h001181b3);  // add  x3, x3, x1
                put_instr(20, 32'hfe209ce3);  // bne  x1, x2, -8    -> back to 0x0c
                put_instr(24, 32'h3e700213);  // addi x4, x0, 999   done
                fill_nops(28);
                max_cycles = 80;
            end

            7: begin
                $display("\n>>> BENCHMARK 7 : diggity dawg\n");
                
                // Loads the file AND saves the final address into 'dynamic_nop_addr'
                load_hex_file("tb.hex", dynamic_nop_addr);
                
                // Automatically starts filling NOPs exactly where the hex file left off!
                fill_nops(dynamic_nop_addr); 
                
                max_cycles = 80;
            end
            endcase
        end
    endtask

    // -------------------------------------------------------- expected results check
    task check_results(input integer n);
        begin
            $display("\n----- FINAL RESULTS -----");
            dump_regs;
            case (n)
            1: begin
                if (dut.RF.regs[3] == 64'd15 && dut.RF.regs[4] == 64'd10 &&
                    dut.RF.regs[5] == 64'd10 && dut.RF.regs[6] == 64'd10)
                    $display(">>> BENCH 1 PASSED (forwarding correct)");
                else
                    $display(">>> BENCH 1 FAILED (expected x3=15 x4=10 x5=10 x6=10)");
            end
            2: begin
                if (dut.RF.regs[3] == 64'd99 && dut.RF.regs[4] == 64'd99 &&
                    dut.RF.regs[5] == 64'd100)
                    $display(">>> BENCH 2 PASSED (load-use stall worked)");
                else
                    $display(">>> BENCH 2 FAILED (expected x3=99 x4=99 x5=100)");
            end
            3: begin
                if (dut.RF.regs[1] == 64'd9 && dut.RF.regs[5] == 64'd13)
                    $display(">>> BENCH 3 PASSED (double hazard, took newer)");
                else
                    $display(">>> BENCH 3 FAILED (expected x1=9 x5=13)");
            end
            4: begin
                if (dut.RF.regs[3] == 64'd0 && dut.RF.regs[4] == 64'd0 &&
                    dut.RF.regs[5] == 64'h55)
                    $display(">>> BENCH 4 PASSED (branch taken, flushed correctly)");
                else
                    $display(">>> BENCH 4 FAILED (expected x3=0 x4=0 x5=0x55)");
            end
            5: begin
                if (dut.RF.regs[3] == 64'd2 && dut.RF.regs[4] == 64'd99)
                    $display(">>> BENCH 5 PASSED (if-else picked ELSE)");
                else
                    $display(">>> BENCH 5 FAILED (expected x3=2 x4=99)");
            end
            6: begin
                if (dut.RF.regs[1] == 64'd4 && dut.RF.regs[3] == 64'd10 &&
                    dut.RF.regs[4] == 64'd999)
                    $display(">>> BENCH 6 PASSED (loop summed correctly)");
                else
                    $display(">>> BENCH 6 FAILED (expected x1=4 x3=10 x4=999)");
            end
            endcase
        end
    endtask

    // -------------------------------------------------------- main flow
    initial begin
        // pick benchmark from plusarg, default = 1
        if (!$value$plusargs("BENCH=%d", BENCH))
            BENCH = 1;

        // Reset
        reset = 1;
        max_cycles = 30;
        load_benchmark(BENCH);

        // Hold reset 2 cycles
        #12;
        reset = 0;

        // Run
        repeat (max_cycles) @(posedge clk);

        // Final report
        check_results(BENCH);
        $display("\nSimulation finished at t=%0t\n", $time);
        $finish;
    end

    // -------------------------------------------------------- per-cycle trace
    integer cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) begin
        if (!reset) begin
            cycle_count = cycle_count + 1;
            $display("[cyc %0d]  PC=0x%02h  IF_inst=0x%08h  | ID.PC=0x%02h  | EX.rd=%0d alu=0x%0h | MEM.rd=%0d data=0x%0h | WB.rd=%0d wdata=0x%0h | stall=%b flush=%b mispred=%b",
                cycle_count,
                dut.pc_current[7:0],
                dut.if_instruction,
                dut.id_pc[7:0],
                dut.ex_rd, dut.alu_result,
                dut.mem_rd_w, dut.mem_alu_result_w,
                dut.wb_rd, dut.wb_write_data,
                dut.hazard_bubble, dut.flush_from_branch, dut.mispredict);
        end
    end

endmodule
