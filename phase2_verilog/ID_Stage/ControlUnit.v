//==========================================================
// CONTROL UNIT
//==========================================================
// Function: 
//   Reads the 32-bit instruction and tells the rest of the 
//   CPU what to do based on the CUSTOM project opcode table.
//==========================================================

module ControlUnit (
    input  [31:0] instruction,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg alu_src,
    output reg mem_to_reg,
    output reg [3:0] alu_control,
    output reg [2:0] imm_type
);

    // 1. Extract the important parts of the instruction
    wire [6:0] opcode = instruction[6:0];   
    wire [2:0] funct3 = instruction[14:12]; 
    wire [6:0] funct7 = instruction[31:25]; 

    // 2. Define the Custom Opcodes (from the provided Image in HEX)
    localparam OPCODE_R     = 7'h34; // Addw, And, Xor, Or, sltu, srl, sra
    localparam OPCODE_I_LW  = 7'h14; // Addiw, Andi, Ori AND Load Word (Lw)
    localparam OPCODE_S     = 7'h24; // sw
    localparam OPCODE_SB    = 7'h64; // bge, bne
    localparam OPCODE_UJ    = 7'h70; // jal
    localparam OPCODE_JALR  = 7'h68; // jalr

    // 3. Determine the output signals based on the custom table
    always @(*) begin
        // DEFAULT VALUES: Prevent hardware latches
        reg_write   = 0;
        mem_read    = 0;
        mem_write   = 0;
        alu_src     = 0;
        mem_to_reg  = 0;
        alu_control = 4'b0000; 
        imm_type    = 3'b000;

        case (opcode)
            
            OPCODE_R: begin
                reg_write = 1;       // Writing result to a register
                alu_src   = 0;       // Use two registers (rs1, rs2)
                
                // Determine exact ALU math operation using custom funct3/funct7
                if      (funct3 == 3'h1 && funct7 == 7'h10) alu_control = 4'b0000; // ADD (Addw)
                else if (funct3 == 3'h0 && funct7 == 7'h10) alu_control = 4'b0001; // AND
                else if (funct3 == 3'h7 && funct7 == 7'h10) alu_control = 4'b0010; // OR
                else if (funct3 == 3'h5 && funct7 == 7'h10) alu_control = 4'b0011; // XOR
                else if (funct3 == 3'h4 && funct7 == 7'h01) alu_control = 4'b0100; // SLTU
                else if (funct3 == 3'h6 && funct7 == 7'h10) alu_control = 4'b0101; // SRL
                else if (funct3 == 3'h6 && funct7 == 7'h30) alu_control = 4'b0110; // SRA
            end

            OPCODE_I_LW: begin
                reg_write = 1;       
                alu_src   = 1;       // ALU uses the Immediate value
                
                // CRITICAL: Since Lw and I-Type ALU share Opcode 14, we check funct3
                if (funct3 == 3'h3) begin
                    // It is a Load Word (Lw)
                    mem_read    = 1;
                    mem_to_reg  = 1;       // Data comes from MEMORY
                    imm_type    = 3'b000;  // I-Type Immediate
                    alu_control = 4'b0000; // ADD (Base + offset)
                end else begin
                    // It is an ALU Immediate (Addiw, Andi, Ori)
                    mem_to_reg  = 0;       // Data comes from ALU
                    imm_type    = 3'b000;  // I-Type Immediate
                    
                    if      (funct3 == 3'h1) alu_control = 4'b0000; // Addiw
                    else if (funct3 == 3'h0) alu_control = 4'b0001; // Andi
                    else if (funct3 == 3'h7) alu_control = 4'b0010; // Ori
                end
            end

            OPCODE_S: begin // sw
                mem_write   = 1;       // Writing data TO Data Memory
                alu_src     = 1;       // ALU uses Immediate
                imm_type    = 3'b001;  // S-Type Immediate
                alu_control = 4'b0000; // ADD (Base + offset)
            end

            OPCODE_SB: begin // bge, bne
                alu_src     = 0;       // Compare rs1 and rs2
                imm_type    = 3'b010;  // B-Type Immediate
                
                if      (funct3 == 3'h6) alu_control = 4'b0111; // BGE
                else if (funct3 == 3'h2) alu_control = 4'b1000; // BNE
            end

            OPCODE_UJ: begin // jal
                reg_write   = 1;
                imm_type    = 3'b011;  // UJ-Type Immediate
                alu_control = 4'b1001; // JAL Command
            end

            OPCODE_JALR: begin // jalr
                reg_write   = 1;
                alu_src     = 1;
                imm_type    = 3'b000;  // I-Type Immediate
                alu_control = 4'b1010; // JALR Command
            end

        endcase
    end
endmodule
