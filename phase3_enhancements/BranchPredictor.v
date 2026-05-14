
//==========================================================================
//  BRANCH PREDICTOR  (dynamic, 2-bit saturating + small BTB)
//
//   - 16 entries, indexed by pc[5:2]
//   - Each entry holds  : 2-bit counter, valid bit, tag (upper PC bits),
//                         target address (BTB)
//   - 2-bit FSM states  : 00 strongly NT, 01 weakly NT, 10 weakly T, 11 strongly T
//   - Predict TAKEN when counter MSB == 1
//   - Updated in EX stage on every resolved branch / jump
//
//   Outputs in IF stage:
//      predict_taken      : prediction bit
//      predicted_target   : target if predicted taken (else don't care)
//==========================================================================
module BranchPredictor (
    input              clk,
    input              reset,

    // Prediction request (IF stage)
    input      [63:0]  if_pc,
    output reg         predict_taken,
    output reg [63:0]  predicted_target,

    // Update from EX stage
    input              update_en,         // a branch/jump was resolved
    input      [63:0]  update_pc,
    input              update_taken,
    input      [63:0]  update_target
);
    // 16 entries
    reg [1:0]  counter [0:15];
    reg        valid   [0:15];
    reg [57:0] tag     [0:15];   // 64 - 4 idx - 2 offset = 58 bits (bits 63..6 of PC)
    reg [63:0] target  [0:15];

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            counter[i] = 2'b01;     // weakly not-taken
            valid[i]   = 1'b0;
            tag[i]     = 58'd0;
            target[i]  = 64'd0;
        end
    end

    wire [3:0]  rd_idx  = if_pc[5:2];
    wire [57:0] rd_tag  = if_pc[63:6];   // was [63:8] -- bits 7:6 were uncovered, causing 0x14/0x54 aliasing
    wire [3:0]  wr_idx  = update_pc[5:2];
    wire [57:0] wr_tag  = update_pc[63:6];

    // Combinational lookup
    always @(*) begin
        if (valid[rd_idx] && (tag[rd_idx] == rd_tag) && counter[rd_idx][1]) begin
            predict_taken    = 1'b1;
            predicted_target = target[rd_idx];
        end else begin
            predict_taken    = 1'b0;
            predicted_target = 64'd0;
        end
    end

    // Update on resolved branch / jump in EX
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                counter[i] <= 2'b01;
                valid[i]   <= 1'b0;
            end
        end else if (update_en) begin
            valid[wr_idx]  <= 1'b1;
            tag[wr_idx]    <= wr_tag;
            target[wr_idx] <= update_target;

            // 2-bit saturating counter update
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
