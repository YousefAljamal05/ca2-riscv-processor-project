module MEM_stage (
    input clk,

    input mem_read,
    input mem_write,

    input [63:0] alu_result,   // address
    input [63:0] write_data,

    output [63:0] read_data
);

    data_memory DM (
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .addr(alu_result),
        .write_data(write_data),
        .read_data(read_data)
    );

endmodule
