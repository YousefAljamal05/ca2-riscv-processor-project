//==========================================================
// WB STAGE (Write Back)
//==========================================================
// Function:
//   - Select correct data to write to register file
//
// Datapath:
//   (ALU Result OR Memory Data) → Register File
//==========================================================

module WB_stage (
    input mem_to_reg,

    input [63:0] alu_result,
    input [63:0] mem_data,

    output [63:0] write_back_data
);

    // Select data source
    assign write_back_data = mem_to_reg ? mem_data : alu_result;

endmodule

