module ID_stage (
    input clk,
    input [31:0] instruction,
    input [63:0] write_back_data,
    input [4:0] write_reg,
    input reg_write_wb,
    input control_mux_sel, // From Hazard Unit

    output [63:0] read_data1,
    output [63:0] read_data2,
    output [63:0] imm_out,
    output [4:0] rs1, // Expose for Hazard Unit
    output [4:0] rs2, // Expose for Hazard Unit
    output [4:0] rd,

    output reg_write,
    output mem_read,
    output mem_write,
    output alu_src,
    output mem_to_reg,
    output [3:0] alu_control
);

    wire raw_reg_write, raw_mem_read, raw_mem_write, raw_alu_src, raw_mem_to_reg;
    wire [3:0] raw_alu_control;

    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd  = instruction[11:7];

    wire [2:0] imm_type;

    ControlUnit CU (
        .instruction(instruction),
        .reg_write(raw_reg_write),
        .mem_read(raw_mem_read),
        .mem_write(raw_mem_write),
        .alu_src(raw_alu_src),
        .mem_to_reg(raw_mem_to_reg),
        .alu_control(raw_alu_control),
        .imm_type(imm_type)
    );

    // Hazard Control Mux: Zero out controls if bubble is inserted
    assign reg_write   = control_mux_sel ? 1'b0 : raw_reg_write;
    assign mem_read    = control_mux_sel ? 1'b0 : raw_mem_read;
    assign mem_write   = control_mux_sel ? 1'b0 : raw_mem_write;
    assign alu_src     = control_mux_sel ? 1'b0 : raw_alu_src;
    assign mem_to_reg  = control_mux_sel ? 1'b0 : raw_mem_to_reg;
    assign alu_control = control_mux_sel ? 4'b0000 : raw_alu_control;

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

    ImmGen IG (
        .instruction(instruction),
        .imm_type(imm_type),
        .imm_out(imm_out)
    );

endmodule
