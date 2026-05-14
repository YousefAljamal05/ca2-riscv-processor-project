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
//   7. Hex file loading (tb.hex)
//==========================================================================

`timescale 1ns/1ps

module tb_pipelined_cpu;

    reg clk;
    reg reset;
    reg [31:0] dynamic_nop_addr;

    // Instantiate the top-level design
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
            // Path derived from: dut -> IF_STAGE (IF_stage) -> IM (instruction_memory)
            dut.IF_STAGE.IM.mem[addr+0] = word[7:0];
            dut.IF_STAGE.IM.mem[addr+1] = word[15:8];
            dut.IF_STAGE.IM.mem[addr+2] = word[23:16];
            dut.IF_STAGE.IM.mem[addr+3] = word[31:24];
        end
    endtask

    // Task to automatically load instructions and return the final address
    task load_hex_file;
        input  [255*8:1] filename;
        output [31:0]    end_addr; 
        
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
            // Path derived from: dut -> ID_STAGE (ID_stage) -> RF (RegFile)
            $display("------------------------------------------------------------");
            $display(" t=%0t  PC=0x%0h", $time, dut.if_pc);
            $display("  x1 = %0d (0x%0h)", $signed(dut.ID_STAGE.RF.regs[1]), dut.ID_STAGE.RF.regs[1]);
            $display("  x2 = %0d (0x%0h)", $signed(dut.ID_STAGE.RF.regs[2]), dut.ID_STAGE.RF.regs[2]);
            $display("  x3 = %0d (0x%0h)", $signed(dut.ID_STAGE.RF
