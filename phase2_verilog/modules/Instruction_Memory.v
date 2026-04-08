//==========================================================
// RV64 Instruction Memory
//
// Stores instructions as bytes (64K x 1 byte).
// Each instruction is 32 bits (4 bytes).
//
// PC is 64-bit in RV64, but since memory size is 64K,
// we use only the lower 16 bits of PC for indexing.
//==========================================================

module instruction_memory (
    input  [63:0] pc,          // 64-bit Program Counter (RV64)
    output [31:0] instruction  // 32-bit instruction
);

    // 64K memory locations, each location is 1 byte
    reg [7:0] mem [0:65535];

    // Even though PC is 64-bit, only the lower 16 bits are used for memory indexing
    wire [15:0] addr = pc[15:0]; 

    // Combine 4 consecutive bytes into one 32-bit instruction
    // Little-endian format
    assign instruction = {
        mem[addr + 3],
        mem[addr + 2],
        mem[addr + 1],
        mem[addr]
    };

    // Initialize memory with sample instructions
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
