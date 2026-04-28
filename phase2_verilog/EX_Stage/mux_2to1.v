module mux_2to1 (
    input  wire [63:0] in0,
    input  wire [63:0] in1,
    input  wire         sel,
    output wire [63:0] out
);
    assign out = sel ? in1 : in0;
endmodule
