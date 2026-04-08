`timescale 1ns/1ps

module tb_alu;

    reg  [63:0] a;
    reg  [63:0] b;
    reg  [3:0]  alu_control;
    wire [63:0] result;

    alu uut (
        .a(a),
        .b(b),
        .alu_control(alu_control),
        .result(result)
    );

    initial begin

        $display("===== RV64 ALU TEST =====");

        // ADD
        a = 64'd10; b = 64'd5; alu_control = 4'b0000;
        #10 $display("ADD: %d", result);

        // SUB
        alu_control = 4'b0001;
        #10 $display("SUB: %d", result);

        // MUL
        a = 64'd6; b = 64'd4; alu_control = 4'b0010;
        #10 $display("MUL: %d", result);

        // DIV
        alu_control = 4'b0011;
        #10 $display("DIV: %d", result);

        // OR
        a = 64'd12; b = 64'd10; alu_control = 4'b0100;
        #10 $display("OR:  %d", result);

        // AND
        alu_control = 4'b0101;
        #10 $display("AND: %d", result);

        #10;
        $finish;
    end

endmodule
