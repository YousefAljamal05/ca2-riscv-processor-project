//==========================================================
// IF/ID PIPELINE REGISTER
//==========================================================
// Function:
//   Acts as a barrier between the Fetch and Decode stages.
//   Captures the PC and Instruction on the rising clock edge
//   and passes them safely to the ID stage.
//==========================================================

module IF_ID (
    input wire clk,
    input wire reset,
    
    // Inputs from IF Stage
    input wire [63:0] pc_in,
    input wire [31:0] instruction_in,
    
    // Outputs to ID Stage
    output reg [63:0] pc_out,
    output reg [31:0] instruction_out
);

    always @(posedge clk) begin
        if (reset) begin
            pc_out          <= 64'd0;
            // 0x00000013 is the standard RISC-V NOP (addi x0, x0, 0)
            instruction_out <= 32'h00000013; 
        end else begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
        end
    end

endmodule
