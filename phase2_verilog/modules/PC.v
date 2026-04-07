//==========================================================
// PC Module
// Purpose:
//   Holds the current program counter (PC) value.
//   On each positive edge of the clock:
//     - if reset is active, PC becomes 0
//     - otherwise, PC is updated with next_pc
//     
// Why is the PC 32-bit?
//   The processor datapath is designed as a 32-bit system.
//   Registers, ALU inputs/outputs, immediates, and address
//   calculations are all handled as 32-bit values.
//   Even though the instruction memory size itself may need
//   fewer address bits, using a 32-bit PC keeps the design
//   consistent and makes branch/jump address calculations
//   simpler later in the CPU design.
//==========================================================

module pc (
    input clk,               // Clock signal
    input reset,             // Reset signal
    input [31:0] next_pc,    // Next PC value (32-bit for consistency with datapath)
    output reg [31:0] pc     // Current PC value (32-bit program counter)
);

    // Update PC on the positive edge of the clock
    always @(posedge clk) begin
        if (reset)
            pc <= 32'd0;     // If reset is 1, set PC to 0
        else
            pc <= next_pc;   // Otherwise load next_pc into PC
    end

endmodule



