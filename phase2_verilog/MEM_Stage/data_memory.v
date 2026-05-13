//==========================================================
// DATA MEMORY MODULE (RAM)
//==========================================================
// Description:
// This module acts as the RAM for the processor, executing 
// Load and Store instructions.
//==========================================================

module data_memory (
    // --- Inputs ---
    input clk,                  // The heartbeat of the processor. Memory needs to know exactly when to save.
    input mem_write,            // Permission signal from Control Unit: 1 = allowed to write/save data.
    input mem_read,             // Permission signal from Control Unit: 1 = allowed to read/output data.
    input [63:0] addr,          // The 64-bit address calculated by the ALU (Where to look).
    input [63:0] write_data,    // The 64-bit data coming from the Register File to be saved.
    
    // --- Outputs ---
    output reg [63:0] read_data // The 64-bit data being pulled out of memory.
);

    //======================================================
    // STORAGE ARRAY
    //======================================================
    reg [7:0] memory [0:8191];

    //======================================================
    // WRITE LOGIC (Synchronous)
    //======================================================
    // Writing data is dangerous, so it waits for the clock tick (posedge clk). 
    // This ensures the address and data are perfectly stable before making a permanent save.
    always @(posedge clk) begin
        if (mem_write)
            // Why addr[7:0]? The incoming address is 64-bit, but we only have 256 slots.
            // 8 bits (7 down to 0) gives exactly 256 combinations. Stripping the top 
            // bits prevents the processor from asking for an index larger than 255.
            mem[addr[7:0]] <= write_data;
    end

    //======================================================
    // READ LOGIC (Combinational)
    //======================================================
    // Reading data does not permanently change anything, so it happens instantly 
    // without waiting for a clock tick (*). This ensures the instruction can finish 
    // within a single clock cycle without stalling the processor.
    always @(*) begin
        if (mem_read)
            read_data = mem[addr[7:0]]; // Instantly output data if reading is allowed
        else
            read_data = 64'd0;          // Output zeros if not reading (prevents garbage data)
    end
    
endmodule
