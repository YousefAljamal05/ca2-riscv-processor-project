//============================================================================
// tb_rv32_pipelined_cpu.v
//   Complete Testbench with:
//     1. Cycle Counter
//     2. Automatic Stop after 3 NOPs (0x00000000 or 0x00000013)
//     3. Integrated Register Dump
//============================================================================

`timescale 1ns/1ps

module tb_rv32_pipelined_cpu;

    //--------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------
    parameter         CLK_PERIOD  = 10;          // 100 MHz
    parameter integer NUM_CYCLES  = 500;         // Watchdog limit
    parameter         HEX_FILE    = "program.hex";

    //--------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cyc = 0;
    integer nop_count = 0;

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    //--------------------------------------------------------------
    // DUT Instance
    //--------------------------------------------------------------
    rv32_pipelined_cpu dut (
        .clk(clk),
        .rst(rst)
    );

    //--------------------------------------------------------------
    // Main Stimulus & Logic
    //--------------------------------------------------------------
    initial begin
        // 1. Load the program into memory
        load_program(HEX_FILE);

        // 2. Reset Sequence
        rst = 1'b1;
        #(CLK_PERIOD * 2);
        rst = 1'b0;
        $display("[TB] Reset released. Simulation starting...");
    end

    // Monitor cycles and instructions
    always @(posedge clk) begin
        if (!rst) begin
            cyc = cyc + 1;

            // Output trace for every cycle
            $display("[cyc %0d]  PC=0x%08h  IF_inst=0x%08h", 
                     cyc, dut.u_if.u_pc.pc, dut.u_if.if_instruction);

            // NOP Detection logic (Catching both standard and zeroed memory)
            if (dut.u_if.if_instruction == 32'h00000013 || 
                dut.u_if.if_instruction == 32'h00000000) begin
                nop_count = nop_count + 1;
            end else begin
                nop_count = 0; // Reset if a real instruction is found
            end

            // Check Termination Conditions
            if (nop_count >= 3) begin
                $display("\n[TB] SUCCESS: 3 consecutive NOPs detected. Ending simulation.");
                terminate_sim();
            end else if (cyc >= NUM_CYCLES) begin
                $display("\n[TB] WARNING: Reached maximum cycle limit (%0d).", NUM_CYCLES);
                terminate_sim();
            end
        end
    end

    //--------------------------------------------------------------
    // Helper Tasks
    //--------------------------------------------------------------

    task load_program;
        input [255:0] filename;
        begin
            $display("[TB] Loading hex file: %0s", filename);
            $readmemh(filename, dut.u_if.u_imem.mem);
        end
    endtask

    task terminate_sim;
        begin
            $display("[TB] Final Cycle Count: %0d", cyc);
            $display("[TB] Simulation time: %0t ns", $time);
            dump_registers();
            $finish;
        end
    endtask

    task dump_registers;
        integer i;
        begin
            $display("\n===== Final Register File State =====");
            for (i = 0; i < 32; i = i + 1) begin
                $display("  x%2d = %0d (0x%08h)",
                         i,
                         dut.u_id.u_rf.regs[i],
                         dut.u_id.u_rf.regs[i]);
            end
            $display("=====================================\n");
        end
    endtask

endmodule