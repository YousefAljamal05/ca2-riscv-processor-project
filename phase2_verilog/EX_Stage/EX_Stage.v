module EX_Stage (
    input  wire [63:0] current_pc,
    input  wire [63:0] reg_a,
    input  wire [63:0] reg_b,
    input  wire [63:0] imm,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,

    output reg  [63:0] alu_result,   
    output reg  [63:0] next_pc,      
    output reg         take_branch   
);

    wire [63:0] shifted_imm;
    wire [63:0] branch_target_wire;
    wire [63:0] alu_input_b;
    wire [63:0] core_result;
    wire        condition_met;

    reg         alu_src;
    reg [3:0]   alu_ctrl;
    reg         is_branch;
    reg         is_jal;
    reg         is_jalr;

    // 1. Shift Immediate for branch targeting
    shift_left_1 sl1 (.in(imm), .out(shifted_imm));

    // 2. Branch Target Adder
    adder branch_add (.a(current_pc), .b(shifted_imm), .sum(branch_target_wire));

    // 3. ALU Input Mux
    mux_2to1 src_mux (.in0(reg_b), .in1(imm), .sel(alu_src), .out(alu_input_b));

    // 4. ALU Core
    alu_core core (
        .a(reg_a), 
        .b(alu_input_b), 
        .alu_ctrl(alu_ctrl), 
        .result(core_result), 
        .condition_flag(condition_met)
    );

    // Control Decoder
    always @(*) begin
        alu_src   = 1'b0;
        alu_ctrl  = 4'b0000; 
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;

        case (opcode)
            7'h34: begin // R-Type (Logic based on your provided opcodes)
                alu_src = 1'b0;
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000; // Add
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001; // And
                else if (funct3 == 3'h5) alu_ctrl = 4'b0010; // Xor
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011; // Or
                else if (funct3 == 3'h4) alu_ctrl = 4'b0100; // Sltu
                else if (funct3 == 3'h6 && funct7 == 7'h10) alu_ctrl = 4'b0101; // Srl
                else if (funct3 == 3'h6 && funct7 == 7'h30) alu_ctrl = 4'b0110; // Sra
            end
            7'h14: begin // I-Type
                alu_src = 1'b1;
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000; // Addi
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001; // Andi
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011; // Ori
                else if (funct3 == 3'h3) alu_ctrl = 4'b0000; // Ld (Load Doubleword)
            end
            7'h64: begin // Branches
                alu_src = 1'b0;
                is_branch = 1'b1;
                if      (funct3 == 3'h6) alu_ctrl = 4'b0111; // BGE 
                else if (funct3 == 3'h2) alu_ctrl = 4'b1000; // BNE
            end
            7'h70: is_jal  = 1'b1; 
            7'h68: begin // JALR
                alu_src = 1'b1;
                alu_ctrl = 4'b0000;
                is_jalr = 1'b1;
            end
            7'h24: begin // S-Type (Store Doubleword)
                alu_src = 1'b1;
                alu_ctrl = 4'b0000;
            end
        endcase
    end

    // Output Routing
    always @(*) begin
        alu_result  = core_result;
        next_pc     = 64'd0;
        take_branch = 1'b0;

        if (is_branch && condition_met) begin
            next_pc     = branch_target_wire;
            take_branch = 1'b1;
        end 
        else if (is_jal) begin
            alu_result  = current_pc + 64'd4;
            next_pc     = branch_target_wire;
            take_branch = 1'b1;
        end 
        else if (is_jalr) begin
            alu_result  = current_pc + 64'd4;
            next_pc     = core_result;
            take_branch = 1'b1;
        end
    end
endmodule
