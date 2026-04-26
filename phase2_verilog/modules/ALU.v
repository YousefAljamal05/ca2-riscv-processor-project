//==========================================================
// 64-bit ALU Module
//==========================================================
module ALU(
    input      [63:0] A, 
    input      [63:0] B, 
    input      [2:0]  ALUOP,
    output reg [63:0] result, 
    output reg        ZF, 
    output reg        BF
);

    always @* begin
        // Default outputs to prevent unwanted latches
        result = 64'b0;
        ZF     = 1'b0; 
        BF     = 1'b0; 
        
        // ALU Operations
        case (ALUOP)
            3'b000: result = A + B;       // ADD
            
            3'b001: begin                 // SUB (Also sets branching flags)
                result = A - B;
                ZF     = (A == B);        // Zero Flag: 1 if A equals B
                BF     = ($signed(A) >= $signed(B)); // Branch Flag: 1 if A >= B (signed)
            end   
            
            3'b010: result = A & B;       // AND
            
            3'b011: result = A | B;       // OR
            
            3'b100: result = A ^ B;       // XOR
            
            3'b101: result = A >> B;      // SRL (Shift Right Logical - fills with 0s)
            
            3'b110: result = $signed(A) >>> B; // SRA (Shift Right Arithmetic - keeps sign)
            
            3'b111: result = (A < B);     // SLTU (Set Less Than Unsigned - evaluates to 1 or 0)
            
            default: result = 64'b0;      // Fallback safety
        endcase
    end
    
endmodule
