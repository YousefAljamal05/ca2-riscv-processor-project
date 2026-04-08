
//==========================================================
// Purpose:
//   Extracts the immediate field from a 32-bit instruction
//   and sign-extends it to 64 bits (RV64 datapath).
//
// Why is sign extension needed?
//   In RV64, registers are 64-bit wide.
//   Immediate fields in instructions are smaller (12, 13, or 21 bits).
//   To preserve negative values, we replicate the sign bit
//   (MSB of immediate) up to 64 bits.
//
// imm_type encoding:
//   000 -> I-type   (addi, lw, jalr)
//   001 -> S-type   (sw)
//   010 -> SB-type  (bne, bge)
//   011 -> UJ-type  (jal)
//
// Instruction is always 32 bits in RISC-V,
// even in RV64 architecture.
//==========================================================

module imm_gen (
    input  [31:0] instruction,  // 32-bit RISC-V instruction
    input  [2:0]  imm_type,     // Select which immediate format to extract
    output reg [63:0] imm_out   // 64-bit sign-extended immediate
);

    always @(*) begin
        case (imm_type)

            //--------------------------------------------------
            
            // I-TYPE IMMEDIATE
            // Format:
            // instruction[31:20] = imm[11:0]
            //
            // We extract instruction[31:20]
            //   remember that in I Type the 20-31 are IMM bits to 64 bits.
            //
            // 64 - 12 = 52 bits → replicate sign bit 52 times
            //--------------------------------------------------
            3'b000: begin
                imm_out = {
                    {52{instruction[31]}},  // replicate sign bit (MSB of immediate) ------->>>> 
                    instruction[31:20]      // actual 12-bit immediate
                };
            end

            //--------------------------------------------------
            // S-TYPE IMMEDIATE
            // Format:
            // imm[11:5] = instruction[31:25]
            // imm[4:0]  = instruction[11:7]
            //
            // Immediate is split into two parts in instruction.
            // Combine them, then sign-extend to 64 bits.
            //--------------------------------------------------
            3'b001: begin
                imm_out = {
                    {52{instruction[31]}},  // sign extension
                    instruction[31:25],     // upper immediate bits
                    instruction[11:7]       // lower immediate bits
                };
            end

            //--------------------------------------------------
            // SB-TYPE (Branch) IMMEDIATE
            //
            // Format in instruction:
            // imm[12]   = instruction[31]
            // imm[10:5] = instruction[30:25]
            // imm[4:1]  = instruction[11:8]
            // imm[11]   = instruction[7]
            // lowest bit = 0 (because instructions are word-aligned)
            //
            // Total immediate width = 13 bits
            // 64 - 13 = 51 bits for sign extension
            //--------------------------------------------------
            3'b010: begin
                imm_out = {
                    {51{instruction[31]}},  // sign extension
                    instruction[31],        // imm[12]
                    instruction[7],         // imm[11]
                    instruction[30:25],     // imm[10:5]
                    instruction[11:8],      // imm[4:1]
                    1'b0                    // last bit always 0
                };
            end

            //--------------------------------------------------
            // UJ-TYPE (Jump) IMMEDIATE
            //
            // Format in instruction:
            // imm[20]   = instruction[31]
            // imm[10:1] = instruction[30:21]
            // imm[11]   = instruction[20]
            // imm[19:12]= instruction[19:12]
            // lowest bit = 0
            //
            // Total immediate width = 21 bits
            // 64 - 21 = 43 bits for sign extension
            //--------------------------------------------------
            3'b011: begin
                imm_out = {
                    {43{instruction[31]}},  // sign extension
                    instruction[31],        // imm[20]
                    instruction[19:12],     // imm[19:12]
                    instruction[20],        // imm[11]
                    instruction[30:21],     // imm[10:1]
                    1'b0                    // last bit always 0
                };
            end

            //--------------------------------------------------
            // Default case
            //--------------------------------------------------
            default: imm_out = 64'd0;

        endcase
    end

endmodule
