module shift_left_1 (
    input  wire [31:0] in,
    output wire [31:0] out
);
    // Shifts left by 1 (appends a 0 to the LSB)
    assign out = {in[30:0], 1'b0};
endmodule