module IF_stage (
    input clk,
    input reset,
    input pc_write,
    input branch_mispredicted, // From EX
    input [63:0] correct_next_pc, // From EX
    input predict_taken, // From Branch Predictor
    input [63:0] predicted_target, // From Branch Predictor
    output [63:0] pc_out,
    output [31:0] instruction_out
);

    wire [63:0] pc_current;
    reg [63:0] pc_next;

    pc PC (
        .clk(clk),
        .reset(reset),
        .pc_write(pc_write), // ADD THIS TO YOUR PC.v MODULE!
        .next_pc(pc_next),
        .pc(pc_current)
    );

    instruction_memory IM (
        .pc(pc_current),
        .instruction(instruction_out)
    );

    // MUX to decide the Next PC
    always @(*) begin
        if (branch_mispredicted) begin
            pc_next = correct_next_pc; // Recovery from EX
        end else if (predict_taken) begin
            pc_next = predicted_target; // Trust the predictor
        end else begin
            pc_next = pc_current + 64'd4; // Default sequential
        end
    end

    assign pc_out = pc_current;
endmodule
