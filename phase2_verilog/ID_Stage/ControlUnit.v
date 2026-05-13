module ControlUnit (
    input  [31:0] instruction,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,      // 0 = reg, 1 = imm
    output reg        mem_to_reg,   // 0 = ALU result, 1 = mem data
    output reg        branch,       // is a conditional branch
    output reg        jump,         // is a jal / jalr
    output reg        jalr,         // is specifically jalr
    output reg [3:0]  alu_control,
    output reg [2:0]  imm_type
);
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire       bit30  = instruction[30];

    localparam R_TYPE = 7'b0110011;  // 0x33
    localparam I_TYPE = 7'b0010011;  // 0x13
    localparam LOAD   = 7'b0000011;  // 0x03
    localparam STORE  = 7'b0100011;  // 0x23
    localparam BRANCH = 7'b1100011;  // 0x63
    localparam JAL    = 7'b1101111;  // 0x6F
    localparam JALR   = 7'b1100111;  // 0x67
