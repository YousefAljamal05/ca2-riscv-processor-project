module data_memory (
    input clk,
    input mem_write,
    input mem_read,
    input [63:0] addr,
    input [63:0] write_data,
    output reg [63:0] read_data
);

    reg [63:0] mem [0:255]; // 256 locations

    // Write (synchronous)
    always @(posedge clk) begin
        if (mem_write)
            mem[addr[7:0]] <= write_data;
    end

    // Read (combinational)
    always @(*) begin
        if (mem_read)
            read_data = mem[addr[7:0]];
        else
            read_data = 64'd0;
    end
endmodule
