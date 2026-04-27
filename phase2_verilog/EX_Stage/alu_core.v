module alu_core (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output reg         condition_flag // Acts like the "Zero" output in your diagram
);
    always @(*) begin
        result = 32'd0;
        condition_flag = 1'b0;

        case (alu_ctrl)
            4'b0000: result = a + b;                          // ADD
            4'b0001: result = a & b;                          // AND
            4'b0010: result = a ^ b;                          // XOR
            4'b0011: result = a | b;                          // OR
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;        // SLTU
            4'b0101: result = a >> b[4:0];                    // SRL
            4'b0110: result = $signed(a) >>> b[4:0];          // SRA
            
            // Branch Evaluations (Uses condition_flag instead of result)
            4'b0111: condition_flag = ($signed(a) >= $signed(b)); // BGE Compare
            4'b1000: condition_flag = (a != b);                   // BNE Compare
            default: result = 32'd0;
        endcase
    end
endmodule