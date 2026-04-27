`timescale 1ns / 1ps

module alu (
    input  wire [31:0] current_pc,   // Current Program Counter
    input  wire [31:0] reg_a,        // Register A data (R[rs1])
    input  wire [31:0] reg_b,        // Register B data (R[rs2])
    input  wire [31:0] imm,          // Immediate value 
    input  wire [6:0]  opcode,       // Instruction Opcode
    input  wire [2:0]  funct3,       // funct3 field
    input  wire [6:0]  funct7,       // funct7 field

    output reg  [31:0] alu_result,   // Result of data operations, memory address, or link address
    output reg  [31:0] next_pc,      // Calculated target PC (ONLY for jumps/branches)
    output reg         take_branch   // HIGH (1) if a branch condition is met or a jump occurs
);

    always @(*) begin
        // Defaults to prevent inferred latches
        alu_result  = 32'd0;
        next_pc     = 32'd0; 
        take_branch = 1'b0; 

        case (opcode)
            // ----------------------------------------------------
            // R-Type Instructions (Opcode: 34)
            // ----------------------------------------------------
            7'h34: begin
                if (funct7 == 7'h10 && funct3 == 3'h1)      // 1. Addw
                    alu_result = reg_a + reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h0) // 3. And
                    alu_result = reg_a & reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h5) // 10. Xor
                    alu_result = reg_a ^ reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h7) // 11. Or
                    alu_result = reg_a | reg_b;
                else if (funct7 == 7'h01 && funct3 == 3'h4) // 13. Sltu
                    alu_result = (reg_a < reg_b) ? 32'd1 : 32'd0; 
                else if (funct7 == 7'h10 && funct3 == 3'h6) // 14. Srl
                    alu_result = reg_a >> reg_b[4:0];
                else if (funct7 == 7'h30 && funct3 == 3'h6) // 15. Sra
                    alu_result = $signed(reg_a) >>> reg_b[4:0]; 
            end

            // ----------------------------------------------------
            // I-Type Instructions (Opcode: 14)
            // ----------------------------------------------------
            7'h14: begin
                case (funct3)
                    3'h1: alu_result = reg_a + imm; // 2. Addiw
                    3'h0: alu_result = reg_a & imm; // 4. Andi
                    3'h7: alu_result = reg_a | imm; // 12. Ori
                    3'h3: alu_result = reg_a + imm; // 9. Lw 
                    default: alu_result = 32'd0;
                endcase
            end

            // ----------------------------------------------------
            // SB-Type Instructions / Branches (Opcode: 64)
            // ----------------------------------------------------
            7'h64: begin
                case (funct3)
                    3'h6: begin // 5. BGE
                        if ($signed(reg_a) >= $signed(reg_b)) begin
                            next_pc = current_pc + {imm[30:0], 1'b0};
                            take_branch = 1'b1; // Tell the PC Mux to use next_pc
                        end
                    end
                    3'h2: begin // 6. BNE
                        if (reg_a != reg_b) begin
                            next_pc = current_pc + {imm[30:0], 1'b0};
                            take_branch = 1'b1; // Tell the PC Mux to use next_pc
                        end
                    end
                endcase
            end

            // ----------------------------------------------------
            // UJ-Type Instructions / Jumps (Opcode: 70)
            // ----------------------------------------------------
            7'h70: begin // 7. JAL
                // Note: Still doing PC+4 here so it can be written to R[rd] via alu_result
                alu_result  = current_pc + 32'd4; 
                next_pc     = current_pc + {imm[30:0], 1'b0};
                take_branch = 1'b1; // Jumps are always taken
            end

            // ----------------------------------------------------
            // JALR Instruction (Opcode: 68)
            // ----------------------------------------------------
            7'h68: begin // 8. JALR
                if (funct3 == 3'h1) begin
                    alu_result  = current_pc + 32'd4; 
                    next_pc     = reg_a + imm;
                    take_branch = 1'b1; // Jumps are always taken
                end
            end

            // ----------------------------------------------------
            // S-Type Instructions / Stores (Opcode: 24)
            // ----------------------------------------------------
            7'h24: begin // 16. SW
                if (funct3 == 3'h3) begin
                    alu_result = reg_a + imm; // Address calc
                end
            end

            default: begin
                alu_result  = 32'd0;
                next_pc     = 32'd0;
                take_branch = 1'b0;
            end
        endcase
    end

endmodule
