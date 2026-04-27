`timescale 1ns / 1ps
module tb_ID_stage;

    // 1. Declare inputs as regs
    reg         clk;
    reg  [31:0] instruction;
    reg  [63:0] write_back_data;
    reg  [4:0]  write_reg;
    reg         reg_write_wb;

    // 2. Declare outputs as wires
    wire [63:0] read_data1;
    wire [63:0] read_data2;
    wire [63:0] imm_out;
    wire [4:0]  rd;
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;
    wire        mem_to_reg;
    wire [3:0]  alu_control;

    // 3. Instantiate the Unit Under Test (UUT)
    ID_stage uut (
        .clk(clk),
        .instruction(instruction),
        .write_back_data(write_back_data),
        .write_reg(write_reg),
        .reg_write_wb(reg_write_wb),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .imm_out(imm_out),
        .rd(rd),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .alu_control(alu_control)
    );

    // 4. Clock Generation (Ticks every 5ns)
    always #5 clk = ~clk;

    // 5. Test Sequence
   initial begin
       //  Waveform generation
        $dumpfile("id_stage_wave.vcd");
        $dumpvars(0, tb_ID_stage);

        // Initialize all inputs to 0
        clk = 0;
        instruction = 32'b0;
        write_back_data = 64'b0;
        write_reg = 5'b0;
        reg_write_wb = 1'b0;

        // Wait for stability
        #10;

        // --- TEST CASE 1: Instruction Decoding ---
        // Let's synthesize an instruction to test field extraction:
        // rd [11:7]   = 5  (00101)
        // rs1 [19:15] = 1  (00001)
        // rs2 [24:20] = 2  (00010)
        // Format: [31:25]_[rs2]_[rs1]_[14:12]_[rd]_[6:0]
        instruction = 32'b0000000_00010_00001_000_00101_0000000;
        #10;

        // --- TEST CASE 2: Write-Back Phase ---
        // Simulate a previous instruction writing data back to the register file
        // Writing the value 64'hDEADBEEF into Register 5
        reg_write_wb = 1'b1;
        write_reg = 5'd5;
        write_back_data = 64'hDEADBEEF;
        #10;
        
        // Turn off write-back enable
        reg_write_wb = 1'b0;

        // --- TEST CASE 3: Read Back Data ---
        // Feed a new instruction that tries to read from rs1 = 5
        // If your register file works, read_data1 should output DEADBEEF
        // rs1 [19:15] = 5  (00101)
        instruction = 32'b0000000_00000_00101_000_00000_0000000;
        #20;

        // End simulation safely
        $finish;
    end

endmodule