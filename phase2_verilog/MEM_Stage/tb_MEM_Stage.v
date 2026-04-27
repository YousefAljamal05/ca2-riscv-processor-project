`timescale 1ns / 1ps

module tb_MEM_stage;

    // --- Signals ---
    reg clk;
    reg mem_read;
    reg mem_write;
    reg [63:0] alu_result;  // The memory address
    reg [63:0] write_data;  // Data to store
    wire [63:0] read_data;  // Data loaded from memory

    // --- Instantiate the Module ---
    MEM_stage uut (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_result(alu_result),
        .write_data(write_data),
        .read_data(read_data)
    );

    // --- Clock Generation ---
    always #5 clk = ~clk;

    // --- Advanced Test Sequence ---
    initial begin
        $dumpfile("mem_stage_wave.vcd");
        $dumpvars(0, tb_MEM_stage);

        // 1. Initialize to zero
        clk = 0;
        mem_read = 0;
        mem_write = 0;
        alu_result = 64'd0;
        write_data = 64'd0;
        
        $display("--- STARTING ADVANCED MEMORY TESTS ---");
        #10; 

        // ==========================================
        // TEST 1: The Basic Write & Read
        // ==========================================
        $display("\nTest 1: Normal Write and Read at Address 16");
        alu_result = 64'd16;
        write_data = 64'hAAAA_BBBB_CCCC_DDDD;
        mem_write = 1;     
        #10; // Wait for write
        
        mem_write = 0;     // Turn off write
        mem_read = 1;      // Turn on read
        #10; // Wait for read
        $display("Expected: aaaa_bbbb_cccc_dddd | Got: %h", read_data);

        // ==========================================
        // TEST 2: The "Write Protection" Test (Harder)
        // ==========================================
        // What happens if we give it data, but mem_write is OFF? 
        // It should NOT save the new data.
        $display("\nTest 2: Write Protection (Trying to write with mem_write=0)");
        alu_result = 64'd16;
        write_data = 64'h9999_9999_9999_9999; // Try to sneak this data in
        mem_write = 0;                        // BUT keep permission OFF
        mem_read = 0;
        #10; 
        
        // Now let's read Address 16 again. It should still have the old AAAA data!
        mem_read = 1;
        #10;
        $display("Expected: aaaa_bbbb_cccc_dddd | Got: %h", read_data);

        // ==========================================
        // TEST 3: The "Read Protection" Test (Harder)
        // ==========================================
        // If mem_read is OFF, the output MUST be zero, even if the address is valid.
        $display("\nTest 3: Read Protection (mem_read=0)");
        alu_result = 64'd16;
        mem_read = 0;  // Turn OFF read permission
        #10;
        $display("Expected: 0000000000000000 | Got: %h", read_data);

        // ==========================================
        // TEST 4: The Overwrite Test
        // ==========================================
        // Now we actually overwrite Address 16 legitimately to make sure it can update.
        $display("\nTest 4: Legitimate Overwrite of Address 16");
        alu_result = 64'd16;
        write_data = 64'h1111_2222_3333_4444; 
        mem_write = 1;  // Proper write permission
        mem_read = 0;
        #10;
        
        mem_write = 0;
        mem_read = 1;   // Read it back
        #10;
        $display("Expected: 1111_2222_3333_4444 | Got: %h", read_data);
        
        $display("\n--- TESTS COMPLETE ---");
        $finish;
    end

endmodule
