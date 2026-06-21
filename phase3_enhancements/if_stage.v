//============================================================================
// if_stage.v
//   IF stage and its sub-modules:
//     - PC                 : 32-bit program counter
//     - Instruction_Memory : word-addressed instruction memory
//     - BranchPredictor    : 2-bit saturating counter + 16-entry BTB
//     - IF_Stage           : wraps the three above
//============================================================================

//----------------------------------------------------------------------------
// Program Counter
//----------------------------------------------------------------------------
module PC (
    input             clk,
    input             rst,
    input             pc_write,    // 0 = freeze (used by hazard unit)
    input      [31:0] next_pc,
    output reg [31:0] pc
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else if (pc_write)
            pc <= next_pc;
    end
endmodule


//----------------------------------------------------------------------------
// Instruction Memory
//   - Word-addressed; reads inst[addr[31:2]].
//   - $readmemh from the testbench fills `mem`.
//----------------------------------------------------------------------------
module Instruction_Memory #(
    parameter MEM_WORDS = 1024
) (
    input  [31:0] addr,
    output [31:0] instruction
);
    reg [31:0] mem [0:MEM_WORDS-1];

    assign instruction = mem[addr[31:2]];

    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h00000000;   // NOP-ish default
    end
endmodule


//----------------------------------------------------------------------------
// Branch Predictor (2-bit saturating + small BTB)
//   - 16 entries, indexed by pc[5:2].
//   - Tag = pc[31:6] (everything above the index). This prevents PCs that
//     differ only in bits [7:6] etc. from aliasing.
//   - Trained in EX stage on every resolved branch / jump.
//----------------------------------------------------------------------------
module BranchPredictor (
    input             clk,
    input             rst,
    // IF-stage prediction lookup
    input      [31:0] if_pc,
    output reg        predict_taken,
    output reg [31:0] predicted_target,
    // Update from EX stage
    input             update_en,
    input      [31:0] update_pc,
    input             update_taken,
    input      [31:0] update_target
);
    reg [1:0]  counter [0:15];
    reg        valid   [0:15];
    reg [25:0] tag     [0:15];   // 32 - 4 idx - 2 offset = 26 bits
    reg [31:0] btb_tgt [0:15];

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            counter[i] = 2'b01;       // weakly not-taken
            valid[i]   = 1'b0;
            tag[i]     = 26'd0;
            btb_tgt[i] = 32'd0;
        end
    end

    wire [3:0]  rd_idx = if_pc[5:2];
    wire [25:0] rd_tag = if_pc[31:6];
    wire [3:0]  wr_idx = update_pc[5:2];
    wire [25:0] wr_tag = update_pc[31:6];

    // Combinational lookup
    always @(*) begin
        if (valid[rd_idx] && (tag[rd_idx] == rd_tag) && counter[rd_idx][1]) begin
            predict_taken    = 1'b1;
            predicted_target = btb_tgt[rd_idx];
        end else begin
            predict_taken    = 1'b0;
            predicted_target = 32'd0;
        end
    end

    // Sequential update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                counter[i] <= 2'b01;
                valid[i]   <= 1'b0;
            end
        end else if (update_en) begin
            valid[wr_idx]   <= 1'b1;
            tag[wr_idx]     <= wr_tag;
            btb_tgt[wr_idx] <= update_target;
            if (update_taken) begin
                if (counter[wr_idx] != 2'b11)
                    counter[wr_idx] <= counter[wr_idx] + 2'b01;
            end else begin
                if (counter[wr_idx] != 2'b00)
                    counter[wr_idx] <= counter[wr_idx] - 2'b01;
            end
        end
    end
endmodule


//----------------------------------------------------------------------------
// IF_Stage : top-level wrapper for the IF stage
//----------------------------------------------------------------------------
module IF_Stage (
    input         clk,
    input         rst,
    // pipeline control
    input         pc_write,           // 0 = stall PC
    input  [31:0] next_pc,            // selected by top module
    // BP update (from EX)
    input         bp_update_en,
    input  [31:0] bp_update_pc,
    input         bp_update_taken,
    input  [31:0] bp_update_target,
    // outputs
    output [31:0] if_pc,
    output [31:0] if_pc_plus_4,
    output [31:0] if_instruction,
    output        if_predict_taken,
    output [31:0] if_predicted_target
);
    wire [31:0] pc_w;

    PC u_pc (
        .clk     (clk),
        .rst     (rst),
        .pc_write(pc_write),
        .next_pc (next_pc),
        .pc      (pc_w)
    );

    Instruction_Memory u_imem (
        .addr        (pc_w),
        .instruction (if_instruction)
    );

    BranchPredictor u_bp (
        .clk             (clk),
        .rst             (rst),
        .if_pc           (pc_w),
        .predict_taken   (if_predict_taken),
        .predicted_target(if_predicted_target),
        .update_en       (bp_update_en),
        .update_pc       (bp_update_pc),
        .update_taken    (bp_update_taken),
        .update_target   (bp_update_target)
    );

    assign if_pc        = pc_w;
    assign if_pc_plus_4 = pc_w + 32'd4;
endmodule
