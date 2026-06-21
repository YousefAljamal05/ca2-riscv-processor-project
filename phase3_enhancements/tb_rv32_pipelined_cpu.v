//============================================================================
// tb_rv32_pipelined_cpu.v
//   Simple top-level testbench:
//     1. Instantiates rv32_pipelined_cpu
//     2. Generates clock + reset
//     3. Loads program.hex into the instruction memory via $readmemh
//     4. Runs for NUM_CYCLES, then prints all 32 register values
//
//   Compile + run with Icarus Verilog:
//     iverilog -o sim if_stage.v id_stage.v ex_stage.v mem_stage.v wb_stage.v \
//                     pipeline_regs.v rv32_pipelined_cpu.v tb_rv32_pipelined_cpu.v
//     vvp sim
//============================================================================

`timescale 1ns/1ps

module tb_rv32_pipelined_cpu;

    //--------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------
    parameter         CLK_PERIOD  = 10;          // 10 ns -> 100 MHz
    parameter integer NUM_CYCLES  = 200;         // run length after reset
    parameter         HEX_FILE    = "program.hex";

    //--------------------------------------------------------------
    // Clock & reset
    //--------------------------------------------------------------
    reg clk = 1'b0;
    reg rst = 1'b1;

    always #(CLK_PERIOD/2) clk = ~clk;

    //--------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------
    rv32_pipelined_cpu dut (
        .clk(clk),
        .rst(rst)
    );

    //--------------------------------------------------------------
    // Helper task : load a hex file into the I-mem
    //   $readmemh expects one 32-bit word (8 hex digits) per line.
    //   Comments "// ..." are allowed at the end of a line.
    //--------------------------------------------------------------
    task load_program;
        input [255:0] filename;     // up to ~32 chars
        begin
            $display("[TB] Loading program from \"%0s\" into I-mem ...", filename);
            $readmemh(filename, dut.u_if.u_imem.mem);
        end
    endtask

    //--------------------------------------------------------------
    // Helper task : print all 32 registers
    //--------------------------------------------------------------
    task dump_registers;
        integer i;
        begin
            $display("");
            $display("===== Final Register File =====");
            for (i = 0; i < 32; i = i + 1) begin
                $display("  x%0d = %0d (0x%08h)",
                         i,
                         dut.u_id.u_rf.regs[i],
                         dut.u_id.u_rf.regs[i]);
            end
            $display("===============================");
        end
    endtask

    //--------------------------------------------------------------
    // Stimulus
    //--------------------------------------------------------------
    initial begin
        // 1) load program before deasserting reset
        load_program(HEX_FILE);

        // 2) hold reset for a few cycles
        rst = 1'b1;
        #(CLK_PERIOD * 2);
        rst = 1'b0;
        $display("[TB] Reset released at t=%0t ns", $time);

        // 3) let the CPU run
        #(CLK_PERIOD * NUM_CYCLES);

        // 4) dump state and finish
        $display("[TB] Run finished at t=%0t ns", $time);
        dump_registers;
        $finish;
    end

    //--------------------------------------------------------------
    // (Optional) per-cycle PC trace -- uncomment to enable
    //--------------------------------------------------------------
    // integer cyc = 0;
    // always @(posedge clk) begin
    //     if (!rst) begin
    //         cyc = cyc + 1;
    //         $display("[cyc %0d]  PC=0x%08h  IF_inst=0x%08h",
    //                  cyc, dut.u_if.u_pc.pc, dut.u_if.if_instruction);
    //     end
    // end

endmodule
