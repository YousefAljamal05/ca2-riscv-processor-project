//==========================================================
// CONTROL UNIT
//==========================================================
// Function: 
//   Reads the 32-bit instruction and tells the rest of the 
//   CPU what to do by turning specific "control wires" on (1) or off (0).
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
    wire [6:0] opcode = instruction[6:0];   // Tells us the type of instruction (ADD, LOAD, STORE)
    wire [2:0] funct3 = instruction[14:12]; // Gives more specific details
    wire bit30        = instruction[30];    // Helps tell the difference between ADD and SUB

    // 2. Define the RISC-V Opcodes (makes the code readable)
    localparam R_TYPE = 7'b0110011; // add, sub, and, or
    localparam I_TYPE = 7'b0010011; // addi
    localparam LOAD   = 7'b0000011; // lw
    localparam STORE  = 7'b0100011; // sw
    localparam BRANCH = 7'b1100011; // beq

    // 3. Determine the output signals based on the opcode
    always @(*) begin
        // DEFAULT VALUES: We set everything to 0 first. 
        // This is a Verilog trick to prevent hardware bugs called "latches".
        reg_write   = 0;
        mem_read    = 0;
        mem_write   = 0;
        alu_src     = 0;
        mem_to_reg  = 0;
        alu_control = 4'b0000; 
        imm_type    = 3'b000;

        // Turn on specific signals based on the instruction
        case (opcode)
            
            R_TYPE: begin
                reg_write = 1;       // We are writing a result to a register
                // alu_src stays 0 because we are using two registers, not an immediate
                
                // Determine exact ALU math operation
                if (funct3 == 3'b000 && bit30 == 1'b1)
                    alu_control = 4'b0110; // SUB
                else if (funct3 == 3'b000)
                    alu_control = 4'b0010; // ADD
                else if (funct3 == 3'b111)
                    alu_control = 4'b0000; // AND
                else if (funct3 == 3'b110)
                    alu_control = 4'b0001; // OR
            end

            I_TYPE: begin
                reg_write = 1;       // We write the result back to a register
                alu_src   = 1;       // The ALU needs to use the Immediate value
                imm_type  = 3'b000;  // Tell ImmGen to generate an I-Type Immediate
                alu_control = 4'b0010; // ADD (for ADDI)
            end

            LOAD: begin
                reg_write  = 1;      // We are saving memory data into a register
                mem_read   = 1;      // We need to read from Data Memory
                alu_src    = 1;      // ALU uses Immediate for address calculation
                mem_to_reg = 1;      // The data going to the register comes from MEMORY, not the ALU
                imm_type   = 3'b000; // I-Type Immediate
                alu_control = 4'b0010; // ADD (Base address + offset)
            end

            STORE: begin
                mem_write = 1;       // We are writing data TO Data Memory
                alu_src   = 1;       // ALU uses Immediate for address calculation
                imm_type  = 3'b001;  // Tell ImmGen to generate an S-Type Immediate
                alu_control = 4'b0010; // ADD (Base address + offset)
            end

            BRANCH: begin
                // No registers or memory are written
                imm_type  = 3'b010;  // Tell ImmGen to generate a B-Type Immediate
                alu_control = 4'b0110; // SUB (Subtract to compare the two registers)
            end

        endcase
    end
endmodule