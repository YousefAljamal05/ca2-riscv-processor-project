module shift_left_1 (
    input  wire [63:0] in,
    output wire [63:0] out
);
    assign out = {in[62:0], 1'b0};
endmodule
