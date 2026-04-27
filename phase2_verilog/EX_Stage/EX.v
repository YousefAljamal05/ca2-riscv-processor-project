`timescale 1ns / 1ps

module alu (
    input  wire [63:0] current_pc,   // 64-bit Program Counter
    input  wire [63:0] reg_a,        // 64-bit Register A data (R[rs1])
    input  wire [63:0] reg_b,        // 64-bit Register B data (R[rs2])
    input  wire [63:0] imm,          // 64-bit Immediate value 
    input  wire [6:0]  opcode,       // Instruction Opcode
    input  wire [2:0]  funct3,       // funct3 field
    input  wire [6:0]  funct7,       // funct7 field

    output reg  [63:0] alu_result,   // 64-bit Result of data operations, memory address, or link address
    output reg  [63:0] next_pc,      // 64-bit Calculated target PC (ONLY for jumps/branches)
    output reg         take_branch   // HIGH (1) if a branch condition is met or a jump occurs
);

    always @(*) begin
        // Defaults to prevent inferred latches
        alu_result  = 64'd0;
        next_pc     = 64'd0; 
        take_branch = 1'b0; 

        case (opcode)
            // ----------------------------------------------------
            // R-Type Instructions (Official Opcode: 7'h33)
            // ----------------------------------------------------
            7'h33: begin
                if (funct7 == 7'h10 && funct3 == 3'h1)      // 1. Addw
                    alu_result = reg_a + reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h0) // 3. And
                    alu_result = reg_a & reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h5) // 10. Xor
                    alu_result = reg_a ^ reg_b;
                else if (funct7 == 7'h10 && funct3 == 3'h7) // 11. Or
                    alu_result = reg_a | reg_b;
                else if (funct7 == 7'h01 && funct3 == 3'h4) // 13. Sltu
                    alu_result = (reg_a < reg_b) ? 64'd1 : 64'd0; 
                else if (funct7 == 7'h10 && funct3 == 3'h6) // 14. Srl (64-bit uses 6 bits for shift)
                    alu_result = reg_a >> reg_b[5:0];
                else if (funct7 == 7'h30 && funct3 == 3'h6) // 15. Sra (64-bit uses 6 bits for shift)
                    alu_result = $signed(reg_a) >>> reg_b[5:0]; 
            end

            // ----------------------------------------------------
            // I-Type Instructions (Official Opcode: 7'h13)
            // ----------------------------------------------------
            7'h13: begin
                case (funct3)
                    3'h1: alu_result = reg_a + imm; // 2. Addiw
                    3'h0: alu_result = reg_a & imm; // 4. Andi
                    3'h7: alu_result = reg_a | imm; // 12. Ori
                    3'h3: alu_result = reg_a + imm; // 9. Lw (Often has its own load opcode 7'h03, but placed here per original code)
                    default: alu_result = 64'd0;
                endcase
            end

            // ----------------------------------------------------
            // SB-Type Instructions / Branches (Official Opcode: 7'h63)
            // ----------------------------------------------------
            7'h63: begin
                case (funct3)
                    3'h6: begin // 5. BGE
                        if ($signed(reg_a) >= $signed(reg_b)) begin
                            next_pc = current_pc + {imm[62:0], 1'b0};
                            take_branch = 1'b1; // Tell the PC Mux to use next_pc
                        end
                    end
                    3'h2: begin // 6. BNE
                        if (reg_a != reg_b) begin
                            next_pc = current_pc + {imm[62:0], 1'b0};
                            take_branch = 1'b1; // Tell the PC Mux to use next_pc
                        end
                    end
                endcase
            end

            // ----------------------------------------------------
            // UJ-Type Instructions / Jumps (Official Opcode: 7'h6F)
            // ----------------------------------------------------
            7'h6F: begin // 7. JAL
                // Note: Still doing PC+4 here so it can be written to R[rd] via alu_result
                alu_result  = current_pc + 64'd4; 
                next_pc     = current_pc + {imm[62:0], 1'b0};
                take_branch = 1'b1; // Jumps are always taken
            end

            // ----------------------------------------------------
            // JALR Instruction (Official Opcode: 7'h67)
            // ----------------------------------------------------
            7'h67: begin // 8. JALR
                if (funct3 == 3'h1) begin
                    alu_result  = current_pc + 64'd4; 
                    next_pc     = reg_a + imm;
                    take_branch = 1'b1; // Jumps are always taken
                end
            end

            // ----------------------------------------------------
            // S-Type Instructions / Stores (Official Opcode: 7'h23)
            // ----------------------------------------------------
            7'h23: begin // 16. SW
                if (funct3 == 3'h3) begin
                    alu_result = reg_a + imm; // Address calc
                end
            end

            default: begin
                alu_result  = 64'd0;
                next_pc     = 64'd0;
                take_branch = 1'b0;
            end
        endcase
    end

endmodule
