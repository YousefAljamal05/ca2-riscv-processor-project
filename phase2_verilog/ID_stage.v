//==========================================================
// ID STAGE (Instruction Decode)
//==========================================================
// Function:
//   - Decode instruction
//   - Read registers
//   - Generate control signals
//   - Generate immediate
//
// Datapath:
//   Instruction → Control Unit
//              → Register File
//              → Immediate Generator
//==========================================================

module ID_stage (
    input clk,

    input [31:0] instruction,
    input [63:0] write_back_data,
    input [4:0] write_reg,
    input reg_write_wb,

    output [63:0] read_data1,
    output [63:0] read_data2,
    output [63:0] imm_out,
    output [4:0] rd,

    output reg_write,
    output mem_read,
    output mem_write,
    output alu_src,
    output mem_to_reg,
    output [3:0] alu_control
);

    // Extract fields
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    assign rd      = instruction[11:7];

    wire [2:0] imm_type;

    // Control Unit
    ControlUnit CU (
        .instruction(instruction),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .alu_control(alu_control),
        .imm_type(imm_type)
    );

    // Register File
   RegFile RF (
        .clk(clk),
        .reg_write(reg_write_wb),
        .rs1(rs1),
        .rs2(rs2),
        .rd(write_reg),
        .write_data(write_back_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // Immediate Generator
    ImmGen IG (
        .instruction(instruction),
        .imm_type(imm_type),
        .imm_out(imm_out)
    );

endmodule


////////////////////////////////////////////



