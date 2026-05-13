//==========================================================
// IF STAGE (Instruction Fetch)
//==========================================================
// Function:
//   - Holds PC
//   - Fetches instruction from memory
//   - Computes next PC (PC + 4)
//
// Datapath:
//   PC → Instruction Memory → Instruction
//   PC + 4 → next PC
//==========================================================
module IF_stage (
    input clk,
    input reset,
    output [63:0] pc_out,
    output [31:0] instruction_out
);

    wire [63:0] pc_current;
    wire [63:0] pc_next;
    // PC Register

    pc PC (
        .clk(clk),
        .reset(reset),
        .next_pc(pc_next),
        .pc(pc_current)
    );

    // Instruction Memory
    instruction_memory IM (
        .pc(pc_current),
        .instruction(instruction_out)
    );
    // Sequential execution (no branching yet)
    assign pc_next = pc_current + 64'd4;
    assign pc_out = pc_current;
endmodule
