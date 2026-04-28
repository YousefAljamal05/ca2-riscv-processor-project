module alu_core (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [63:0] result,
    output reg         condition_flag 
);
    always @(*) begin
        result = 64'd0;
        condition_flag = 1'b0;

        case (alu_ctrl)
            4'b0000: result = a + b;                               // ADD (64-bit)
            4'b0001: result = a & b;                               // AND
            4'b0010: result = a ^ b;                               // XOR
            4'b0011: result = a | b;                               // OR
            4'b0100: result = (a < b) ? 64'd1 : 64'd0;             // SLTU
            4'b0101: result = a >> b[5:0];                         // SRL (Uses 6 bits for 64-bit shift)
            4'b0110: result = $signed(a) >>> b[5:0];               // SRA (Uses 6 bits for 64-bit shift)
            
            // Branch Evaluations
            4'b0111: condition_flag = ($signed(a) >= $signed(b));  // BGE
            4'b1000: condition_flag = (a != b);                    // BNE
            default: result = 64'd0;
        endcase
    end
endmodule
