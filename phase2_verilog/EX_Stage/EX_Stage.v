module EX_Stage (
    input  wire [63:0] current_pc,
    input  wire [63:0] reg_a,
    input  wire [63:0] reg_b,
    input  wire [63:0] imm,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    
    // NEW FORWARDING INPUTS
    input  wire [1:0]  forwardA,
    input  wire [1:0]  forwardB,
    input  wire [63:0] ex_mem_data, // Data forwarded from EX/MEM
    input  wire [63:0] mem_wb_data, // Data forwarded from MEM/WB
    input  wire        predict_taken,

    output reg  [63:0] alu_result,   
    output reg  [63:0] next_pc,      
    output reg         take_branch,  
    
    // NEW MISPREDICT OUTPUTS
    output wire        branch_mispredicted,
    output wire        is_branch_or_jump // For updating Predictor
);

    wire [63:0] shifted_imm;
    wire [63:0] branch_target_wire;
    wire [63:0] core_result;
    wire        condition_met;

    reg         alu_src;
    reg [3:0]   alu_ctrl;
    reg         is_branch;
    reg         is_jal;
    reg         is_jalr;

    reg [63:0] forwarded_a;
    reg [63:0] forwarded_b;
    wire [63:0] alu_input_b;

    // 1. FORWARDING MULTIPLEXERS
    always @(*) begin
        case(forwardA)
            2'b00: forwarded_a = reg_a;
            2'b10: forwarded_a = ex_mem_data;
            2'b01: forwarded_a = mem_wb_data;
            default: forwarded_a = reg_a;
        endcase

        case(forwardB)
            2'b00: forwarded_b = reg_b;
            2'b10: forwarded_b = ex_mem_data;
            2'b01: forwarded_b = mem_wb_data;
            default: forwarded_b = reg_b;
        endcase
    end

    // 2. Shift Immediate & Branch Target
    shift_left_1 sl1 (.in(imm), .out(shifted_imm));
    adder branch_add (.a(current_pc), .b(shifted_imm), .sum(branch_target_wire));

    // 3. ALU Input B Mux
    mux_2to1 src_mux (.in0(forwarded_b), .in1(imm), .sel(alu_src), .out(alu_input_b));

    // 4. ALU Core (Using forwarded_a instead of reg_a)
    alu_core core (
        .a(forwarded_a), 
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
            7'h34: begin // R-Type
                alu_src = 1'b0;
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000;
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001;
                else if (funct3 == 3'h5) alu_ctrl = 4'b0010;
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011;
                else if (funct3 == 3'h4) alu_ctrl = 4'b0100;
                else if (funct3 == 3'h6 && funct7 == 7'h10) alu_ctrl = 4'b0101;
                else if (funct3 == 3'h6 && funct7 == 7'h30) alu_ctrl = 4'b0110;
            end
            7'h14: begin // I-Type
                alu_src = 1'b1;
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000;
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001;
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011;
                else if (funct3 == 3'h3) alu_ctrl = 4'b0000;
            end
            7'h64: begin // Branches
                alu_src = 1'b0;
                is_branch = 1'b1;
                if      (funct3 == 3'h6) alu_ctrl = 4'b0111; 
                else if (funct3 == 3'h2) alu_ctrl = 4'b1000; 
            end
            7'h70: is_jal  = 1'b1; 
            7'h68: begin // JALR
                alu_src = 1'b1;
                alu_ctrl = 4'b0000;
                is_jalr = 1'b1;
            end
            7'h24: begin // S-Type
                alu_src = 1'b1;
                alu_ctrl = 4'b0000;
            end
        endcase
    end

    // Output Routing & Mispredict Detection
    always @(*) begin
        alu_result  = core_result;
        next_pc     = current_pc + 64'd4; // Default recovery if predicted taken but shouldn't have
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

    // Identify if the branch predictor guessed wrong
    assign branch_mispredicted = (is_branch || is_jal || is_jalr) && (take_branch != predict_taken);
    assign is_branch_or_jump = (is_branch || is_jal || is_jalr);

endmodule
