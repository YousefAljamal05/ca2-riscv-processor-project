module EX_Stage (
    input  wire [31:0] current_pc,
    input  wire [31:0] reg_a,
    input  wire [31:0] reg_b,
    input  wire [31:0] imm,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,

    output reg  [31:0] alu_result,   
    output reg  [31:0] next_pc,      
    output reg         take_branch   
);

    // --- Internal Wires for the Diagram ---
    wire [31:0] shifted_imm;
    wire [31:0] branch_target_wire;
    wire [31:0] alu_input_b;
    wire [31:0] core_result;
    wire        condition_met;

    // --- Control Signals (The Blue Bubbles) ---
    reg        alu_src;
    reg [3:0]  alu_ctrl;
    reg        is_branch;
    reg        is_jal;
    reg        is_jalr;

    // ----------------------------------------------------
    // Component Instantiations (Routing the Datapath)
    // ----------------------------------------------------
    
    // 1. Shift Left 1
    shift_left_1 sl1 (
        .in(imm), 
        .out(shifted_imm)
    );

    // 2. Add (Calculates Branch Target)
    adder branch_add (
        .a(current_pc), 
        .b(shifted_imm), 
        .sum(branch_target_wire)
    );

    // 3. Mux (Chooses between Register B and Immediate)
    mux_2to1 src_mux (
        .in0(reg_b), 
        .in1(imm), 
        .sel(alu_src), 
        .out(alu_input_b)
    );

    // 4. Main ALU Core
    alu_core core (
        .a(reg_a), 
        .b(alu_input_b), 
        .alu_ctrl(alu_ctrl), 
        .result(core_result), 
        .condition_flag(condition_met)
    );

    // ----------------------------------------------------
    // ALU Control Decoder (The Blue Bubbles Logic)
    // ----------------------------------------------------
    always @(*) begin
        // Default control states
        alu_src   = 1'b0;
        alu_ctrl  = 4'b0000; 
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;

        case (opcode)
            7'h34: begin // R-Type
                alu_src = 1'b0; // Use Reg_B
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000; // Addw
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001; // And
                else if (funct3 == 3'h5) alu_ctrl = 4'b0010; // Xor
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011; // Or
                else if (funct3 == 3'h4) alu_ctrl = 4'b0100; // Sltu
                else if (funct3 == 3'h6 && funct7 == 7'h10) alu_ctrl = 4'b0101; // Srl
                else if (funct3 == 3'h6 && funct7 == 7'h30) alu_ctrl = 4'b0110; // Sra
            end
            
            7'h14: begin // I-Type
                alu_src = 1'b1; // Use Immediate
                if      (funct3 == 3'h1) alu_ctrl = 4'b0000; // Addiw
                else if (funct3 == 3'h0) alu_ctrl = 4'b0001; // Andi
                else if (funct3 == 3'h7) alu_ctrl = 4'b0011; // Ori
                else if (funct3 == 3'h3) alu_ctrl = 4'b0000; // Lw (Add base + offset)
            end
            
            7'h64: begin // SB-Type (Branches)
                alu_src = 1'b0; // Use Reg_B for comparison
                is_branch = 1'b1;
                if      (funct3 == 3'h6) alu_ctrl = 4'b0111; // BGE 
                else if (funct3 == 3'h2) alu_ctrl = 4'b1000; // BNE
            end
            
            7'h70: is_jal  = 1'b1; // UJ-Type (Jump and Link)
            
            7'h68: begin // I-Type (JALR)
                alu_src = 1'b1;
                alu_ctrl = 4'b0000; // Need ALU to add reg_a + imm
                is_jalr = 1'b1;
            end
            
            7'h24: begin // S-Type (Store)
                alu_src = 1'b1; // Use Immediate
                alu_ctrl = 4'b0000; // Add base + offset
            end
        endcase
    end

    // ----------------------------------------------------
    // Output Logic Routing
    // ----------------------------------------------------
    always @(*) begin
        // By default, just pass out the ALU math result and zero the rest
        alu_result  = core_result;
        next_pc     = 32'd0;
        take_branch = 1'b0;

        // Override logic for Branches and Jumps
        if (is_branch && condition_met) begin
            next_pc     = branch_target_wire; // From the Adder module!
            take_branch = 1'b1;
        end 
        else if (is_jal) begin
            alu_result  = current_pc + 32'd4; // Return address
            next_pc     = branch_target_wire; // From the Adder module!
            take_branch = 1'b1;
        end 
        else if (is_jalr) begin
            alu_result  = current_pc + 32'd4; // Return address
            next_pc     = core_result;        // RegA + Imm (From ALU Core)
            take_branch = 1'b1;
        end
    end

endmodule