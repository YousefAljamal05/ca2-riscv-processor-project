//==========================================================
// DATA MEMORY TESTBENCH
//==========================================================
// Description:
// A testbench is an artificial environment we build to "plug in" 
// our module and test it. It does not synthesize into actual hardware.
// Instead, it generates fake signals (like a clock and data) to see 
// how our hardware module reacts.
//==========================================================

`timescale 1ns / 1ps // Tells the simulator: 1 time unit = 1ns, with a precision of 1ps

module tb_data_memory;

    //======================================================
    // 1. SIGNAL DECLARATIONS (Registers vs Wires)
    //======================================================
    // WHY REGS? In a testbench, any signal that WE control (the inputs) 
    // must be declared as a 'reg'. This allows us to manually change their 
    // values inside an 'initial' block and hold that value over time.
    reg clk;
    reg mem_write;
    reg mem_read;
    reg [63:0] addr;
    reg [63:0] write_data;

    // WHY WIRES? Any signal that comes OUT of the module must be a 'wire'.
    // We don't control this value; the module continuously drives it.
    wire [63:0] read_data;

    //======================================================
    // 2. MODULE INSTANTIATION (Plugging it in)
    //======================================================
    // Here we take our actual hardware module (data_memory), give it a 
    // nickname (uut = Unit Under Test), and wire our testbench signals 
    // directly into its physical ports.
    data_memory uut (
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
    );

    //======================================================
    // 3. CLOCK GENERATION
    //======================================================
    // This creates our artificial heartbeat. 
    // Every 5 nanoseconds (#5), the clock flips its state (~clk).
    // This creates a continuous square wave with a full period of 10ns.
    always #5 clk = ~clk;

    //======================================================
    // 4. TEST SEQUENCE
    //======================================================
    // The 'initial' block runs exactly once from top to bottom when 
    // the simulation starts. It executes sequentially.
    initial begin
        // --- Setup for Wavetrace ---
        // These commands tell the simulator to record every single 
        // signal change and dump it into a file so we can view the graph.
        $dumpfile("data_memory_wave.vcd");
        $dumpvars(0, tb_data_memory);

        // --- Initialization ---
        // WHY INITIALIZE? In Verilog, variables start as 'x' (unknown). 
        // If we don't set them to 0, they might corrupt our memory.
        clk = 0;
        mem_write = 0;
        mem_read = 0;
        addr = 64'd0;
        write_data = 64'd0;

        // Wait 10ns (one full clock cycle) before doing anything.
        #10;

        // ==========================================
        // TEST 1: Write Data to Memory
        // ==========================================
        addr = 64'd8;              // Target memory address 8
        write_data = 64'hDEADBEEF; // Data we want to save
        mem_write = 1;             // Turn ON write permission
        mem_read = 0;              // Keep read OFF
        
        // Wait 10ns to allow the clock edge to trigger the save operation inside the module.
        #10;               
        mem_write = 0;             // Turn OFF write permission so we don't accidentally overwrite it later

        // ==========================================
        // TEST 2: Read Data from Memory
        // ==========================================
        // We leave the address at 8, but switch to read mode.
        mem_read = 1;              // Turn ON read permission
        
        // Wait 10ns to give ourselves time to look at the 'read_data' output on the waveform graph.
        #10;               

        // ==========================================
        // TEST 3: Test Read Permission (mem_read = 0)
        // ==========================================
        // If we turn off mem_read, the output should instantly drop to zero, 
        // protecting the data from being viewed.
        mem_read = 0;
        
        #10;               

        // ==========================================
        // TEST 4: Write and Read to a different address
        // ==========================================
        // Let's prove the memory array can hold multiple different items.
        addr = 64'd16;             // Move to address 16
        write_data = 64'hCAFEBABE; // New data
        mem_write = 1;             // Turn write ON
        
        #10;                       // Wait for clock tick to save
        mem_write = 0;             // Turn write OFF
        mem_read = 1;              // Turn read ON to look at our newly saved data
        
        #20;                       // Let it sit for a moment so the graph looks nice

        // Safely end the simulation so it doesn't run forever
        $finish;
    end

endmodule
