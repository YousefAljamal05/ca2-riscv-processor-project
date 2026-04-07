//==========================================================
// Instruction Memory Module
// Purpose:
//   Stores instructions as bytes and returns one 32-bit
//   instruction based on the current PC address.
//
// Why byte-addressable?
//   The project requires Instruction Memory to be 64K x 1 byte.
//   Since each instruction is 32 bits = 4 bytes, we combine
//   4 consecutive bytes to form one instruction.
//==========================================================

module instruction_memory (
    input [31:0] pc,              // Program counter address
    output [31:0] instruction     // 32-bit instruction output
);

    // Instruction memory: 64K locations, each location is 1 byte
    reg [7:0] mem [0:65535]; // Every Mem location has a 8-Bit which is = 1 Byte

    // Combine 4 consecutive bytes into one 32-bit instruction
    // Little-endian arrangement:
    // mem[pc]     -> lowest byte
    // mem[pc + 1] -> next byte
    // mem[pc + 2] -> next byte
    // mem[pc + 3] -> highest byte
    assign instruction = {mem[pc + 3], mem[pc + 2], mem[pc + 1], mem[pc]};

    // Initialize memory with some sample instructions
    initial begin
        // Example instruction 1 = 0x12345678
        mem[0] = 8'h78;
        mem[1] = 8'h56;
        mem[2] = 8'h34;
        mem[3] = 8'h12;

        // Example instruction 2 = 0xAABBCCDD
        mem[4] = 8'hDD;
        mem[5] = 8'hCC;
        mem[6] = 8'hBB;
        mem[7] = 8'hAA;

        // Example instruction 3 = 0x11223344
        mem[8]  = 8'h44;
        mem[9]  = 8'h33;
        mem[10] = 8'h22;
        mem[11] = 8'h11;
    end

endmodule
