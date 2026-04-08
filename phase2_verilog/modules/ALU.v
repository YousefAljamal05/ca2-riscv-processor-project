module alu (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  alu_control,
    output reg [63:0] result
);

    always @(*) begin
        case (alu_control)

            4'b0000: result = a + b;
            4'b0001: result = a - b;
            4'b0010: result = a * b;

            4'b0011: begin
                if (b != 0)
                    result = a / b;
                else
                    result = 64'd0;
            end

            4'b0100: result = a | b;
            4'b0101: result = a & b;

            default: result = 64'd0;

        endcase
    end

endmodule
