//==========================================================
// RV64 Register File
//==========================================================
// Description:
//
// This module implements the 32 general-purpose registers
// (x0 to x31) used in RISC-V.
//
// Each register is 64 bits wide (RV64 architecture).
//
// The 5-bit inputs rs1, rs2, and rd come directly from
// specific bit fields of the 32-bit instruction:
//
// R-type instruction format:
// 31      25 24   20 19   15 14  12 11    7 6      0
// | funct7 | rs2 | rs1 | funct3 |  rd  | opcode |
//
// So:
//   rs1 = instruction[19:15]
//   rs2 = instruction[24:20]
//   rd  = instruction[11:7]
//
// Since there are 32 registers, 5 bits are needed
// (2^5 = 32).
//
// Behavior:
// - Write occurs on positive clock edge.
// - Read is combinational.
// - Register x0 always remains zero.
//==========================================================

module register_file (
    input clk,                      // Clock signal
    input reg_write,                // Write enable
    input [4:0] rs1,                // Source register 1 (from instruction[19:15])
    input [4:0] rs2,                // Source register 2 (from instruction[24:20])
    input [4:0] rd,                 // Destination register (from instruction[11:7])
    input [63:0] write_data,        // Data to write into rd
    output [63:0] read_data1,       // Data from rs1
    output [63:0] read_data2        // Data from rs2
);

    // 32 registers, each 64-bit wide
    reg [63:0] regs [0:31];

    integer i;

    // Initialize all registers to 0
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 64'd0;
    end

    // Write operation (synchronous)
    //  On clock edge, if writing is enabled and the register is not x0, update that register with new data.
    always @(posedge clk) begin
     
        if (reg_write && rd != 5'd0) 
            regs[rd] <= write_data;
    end

    //These lines implement the two read ports of the register file by selecting one 
    //of the 32 registers using the 5-bit register index and immediately driving the output with that register’s 64-bit value
    assign read_data1 = regs[rs1];
    assign read_data2 = regs[rs2];

endmodule
