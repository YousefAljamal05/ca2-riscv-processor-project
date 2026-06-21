//============================================================================
// mem_stage.v
//   MEM stage and its sub-module:
//     - Data_Memory : 2048 x 32-bit array (8 KB total), indexed by addr[12:2]
//                     Combinational read, synchronous write.
//     - MEM_Stage   : trivial wrapper around Data_Memory
//============================================================================

module Data_Memory (
    input         clk,
    input         rst,
    input         mem_read,
    input         mem_write,
    input  [31:0] addr,
    input  [31:0] wdata,
    output [31:0] rdata
);
    // 2048 entries x 32 bits = 8 KB total
    reg [31:0] mem [0:2047];

    // word-addressed by addr[12:2]  (bits [1:0] are byte-offset within a word)
    wire [10:0] idx = addr[12:2];

    // Read: combinational, returns 0 when not reading
    assign rdata = mem_read ? mem[idx] : 32'd0;

    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1) mem[i] = 32'd0;
    end

    // Write: synchronous
    always @(posedge clk) begin
        if (mem_write) mem[idx] <= wdata;
    end
endmodule


module MEM_Stage (
    input         clk,
    input         rst,
    // from EX/MEM register
    input         ex_mem_mem_read,
    input         ex_mem_mem_write,
    input  [31:0] ex_mem_alu_result,
    input  [31:0] ex_mem_rs2_data,
    // output to MEM/WB register
    output [31:0] mem_rdata
);
    Data_Memory u_dmem (
        .clk      (clk),
        .rst      (rst),
        .mem_read (ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .addr     (ex_mem_alu_result),
        .wdata    (ex_mem_rs2_data),
        .rdata    (mem_rdata)
    );
endmodule
