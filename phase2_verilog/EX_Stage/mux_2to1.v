module mux_2to1 (
    input  wire [31:0] in0,  // Selected when sel = 0
    input  wire [31:0] in1,  // Selected when sel = 1
    input  wire        sel,
    output wire [31:0] out
);
    assign out = sel ? in1 : in0;
endmodule