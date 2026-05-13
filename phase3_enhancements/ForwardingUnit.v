module ForwardingUnit (
    input wire [4:0] rs1_ID_EX,
    input wire [4:0] rs2_ID_EX,
    
    input wire [4:0] rd_EX_MEM,
    input wire reg_write_EX_MEM,
    
    input wire [4:0] rd_MEM_WB,
    input wire reg_write_MEM_WB,
    
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin
        // Default: no forwarding (use data from ID/EX)
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX Hazard (ALU-ALU Forwarding)
        if (reg_write_EX_MEM && (rd_EX_MEM != 0) && (rd_EX_MEM == rs1_ID_EX))
            forward_a = 2'b10;
        if (reg_write_EX_MEM && (rd_EX_MEM != 0) && (rd_EX_MEM == rs2_ID_EX))
            forward_b = 2'b10;

        // MEM Hazard (Double Data Forwarding)
        // Only forward from MEM/WB if we aren't ALREADY forwarding from EX/MEM
        if (reg_write_MEM_WB && (rd_MEM_WB != 0) && (rd_MEM_WB == rs1_ID_EX) &&
            !(reg_write_EX_MEM && (rd_EX_MEM != 0) && (rd_EX_MEM == rs1_ID_EX)))
            forward_a = 2'b01;
            
        if (reg_write_MEM_WB && (rd_MEM_WB != 0) && (rd_MEM_WB == rs2_ID_EX) &&
            !(reg_write_EX_MEM && (rd_EX_MEM != 0) && (rd_EX_MEM == rs2_ID_EX)))
            forward_b = 2'b01;
    end
endmodule
