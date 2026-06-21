//============================================================================
// rv32_pipelined_cpu.v
//   Top module : interconnects the five pipeline stages and four pipeline
//   registers. Handles
//      - the PC mux (mispredict > predict-taken > PC+4),
//      - stall (load-use) propagation,
//      - flush (mispredict) propagation,
//      - the branch-predictor update channel from EX back to IF.
//
//   All sub-module instantiations use named port mapping.
//============================================================================

module rv32_pipelined_cpu (
    input clk,
    input rst
);
    //-------------------------------------------------------------------
    // IF stage wires
    //-------------------------------------------------------------------
    wire [31:0] if_pc, if_pc_plus_4, if_instruction;
    wire        if_predict_taken;
    wire [31:0] if_predicted_target;

    //-------------------------------------------------------------------
    // IF/ID register outputs
    //-------------------------------------------------------------------
    wire [31:0] ifid_pc, ifid_pc_plus_4, ifid_instruction;
    wire        ifid_predict_taken;
    wire [31:0] ifid_predicted_target;

    //-------------------------------------------------------------------
    // ID stage wires
    //-------------------------------------------------------------------
    wire [31:0] id_rd1, id_rd2, id_imm;
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7, id_opcode;
    wire        id_reg_write, id_mem_read, id_mem_write, id_alu_src;
    wire [1:0]  id_mem_to_reg;
    wire        id_branch, id_jump, id_jalr;
    wire [3:0]  id_alu_control;
    wire        stall;

    //-------------------------------------------------------------------
    // ID/EX register outputs
    //-------------------------------------------------------------------
    wire [31:0] idex_pc, idex_pc_plus_4, idex_rd1, idex_rd2, idex_imm;
    wire [4:0]  idex_rs1, idex_rs2, idex_rd;
    wire [2:0]  idex_funct3;
    wire [6:0]  idex_funct7;
    wire        idex_predict_taken;
    wire [31:0] idex_predicted_target;
    wire        idex_reg_write, idex_mem_read, idex_mem_write, idex_alu_src;
    wire [1:0]  idex_mem_to_reg;
    wire        idex_branch, idex_jump, idex_jalr;
    wire [3:0]  idex_alu_control;

    //-------------------------------------------------------------------
    // EX stage outputs
    //-------------------------------------------------------------------
    wire [31:0] ex_alu_result, ex_rs2_forwarded;
    wire        ex_branch_taken;
    wire [31:0] ex_branch_target;

    //-------------------------------------------------------------------
    // EX/MEM register outputs
    //-------------------------------------------------------------------
    wire [31:0] exmem_pc_plus_4, exmem_alu_result, exmem_rs2_data;
    wire [4:0]  exmem_rd;
    wire        exmem_reg_write, exmem_mem_read, exmem_mem_write;
    wire [1:0]  exmem_mem_to_reg;

    //-------------------------------------------------------------------
    // MEM stage outputs
    //-------------------------------------------------------------------
    wire [31:0] mem_rdata;

    //-------------------------------------------------------------------
    // MEM/WB register outputs
    //-------------------------------------------------------------------
    wire [31:0] memwb_pc_plus_4, memwb_alu_result, memwb_mem_data;
    wire [4:0]  memwb_rd;
    wire        memwb_reg_write;
    wire [1:0]  memwb_mem_to_reg;

    //-------------------------------------------------------------------
    // WB stage
    //-------------------------------------------------------------------
    wire [31:0] wb_wdata;

    //-------------------------------------------------------------------
    // Branch / mispredict / PC-mux glue
    //-------------------------------------------------------------------
    wire is_branch_or_jump_ex = idex_branch | idex_jump;

    // Mispredict when:
    //   - EX has a branch/jump AND
    //     ( predicted-taken disagrees with actual, OR taken-but-target-mismatch )
    wire mispredict = is_branch_or_jump_ex && (
                        (ex_branch_taken    != idex_predict_taken) ||
                        (ex_branch_taken && (ex_branch_target != idex_predicted_target))
                      );

    // The "corrected" PC when EX detects a mispredict:
    //   - if actually taken -> the actual target
    //   - if actually not-taken (we wrongly predicted taken) -> idex_pc + 4
    wire [31:0] mispredict_pc = ex_branch_taken ? ex_branch_target
                                                : (idex_pc + 32'd4);

    // PC priority: mispredict > IF predict-taken > PC+4
    wire [31:0] next_pc =
        mispredict       ? mispredict_pc       :
        if_predict_taken ? if_predicted_target :
                           if_pc_plus_4;

    // Control signals to pipeline registers
    wire pc_write    = (~stall) | mispredict;
    wire if_id_we    = ~stall;
    wire if_id_flush = mispredict;
    wire id_ex_flush = stall | mispredict;

    // BP update channel : only for resolved branches/jumps
    wire        bp_update_en     = is_branch_or_jump_ex;
    wire [31:0] bp_update_pc     = idex_pc;
    wire        bp_update_taken  = ex_branch_taken;
    wire [31:0] bp_update_target = ex_branch_target;

    //===================================================================
    // IF stage
    //===================================================================
    IF_Stage u_if (
        .clk                (clk),
        .rst                (rst),
        .pc_write           (pc_write),
        .next_pc            (next_pc),
        .bp_update_en       (bp_update_en),
        .bp_update_pc       (bp_update_pc),
        .bp_update_taken    (bp_update_taken),
        .bp_update_target   (bp_update_target),
        .if_pc              (if_pc),
        .if_pc_plus_4       (if_pc_plus_4),
        .if_instruction     (if_instruction),
        .if_predict_taken   (if_predict_taken),
        .if_predicted_target(if_predicted_target)
    );

    //===================================================================
    // IF/ID
    //===================================================================
    IF_ID_Reg u_if_id (
        .clk                 (clk),
        .rst                 (rst),
        .we                  (if_id_we),
        .flush               (if_id_flush),
        .in_pc               (if_pc),
        .in_pc_plus_4        (if_pc_plus_4),
        .in_instruction      (if_instruction),
        .in_predict_taken    (if_predict_taken),
        .in_predicted_target (if_predicted_target),
        .out_pc              (ifid_pc),
        .out_pc_plus_4       (ifid_pc_plus_4),
        .out_instruction     (ifid_instruction),
        .out_predict_taken   (ifid_predict_taken),
        .out_predicted_target(ifid_predicted_target)
    );

    //===================================================================
    // ID stage
    //===================================================================
    ID_Stage u_id (
        .clk              (clk),
        .rst              (rst),
        .if_id_instruction(ifid_instruction),
        .wb_reg_write     (memwb_reg_write),
        .wb_rd            (memwb_rd),
        .wb_wdata         (wb_wdata),
        .id_ex_rd         (idex_rd),
        .id_ex_mem_read   (idex_mem_read),
        .id_rd1           (id_rd1),
        .id_rd2           (id_rd2),
        .id_imm           (id_imm),
        .id_rs1           (id_rs1),
        .id_rs2           (id_rs2),
        .id_rd            (id_rd),
        .id_funct3        (id_funct3),
        .id_funct7        (id_funct7),
        .id_opcode        (id_opcode),
        .id_reg_write     (id_reg_write),
        .id_mem_read      (id_mem_read),
        .id_mem_write     (id_mem_write),
        .id_alu_src       (id_alu_src),
        .id_mem_to_reg    (id_mem_to_reg),
        .id_branch        (id_branch),
        .id_jump          (id_jump),
        .id_jalr          (id_jalr),
        .id_alu_control   (id_alu_control),
        .stall            (stall)
    );

    //===================================================================
    // ID/EX
    //===================================================================
    ID_EX_Reg u_id_ex (
        .clk                 (clk),
        .rst                 (rst),
        .flush               (id_ex_flush),
        .in_pc               (ifid_pc),
        .in_pc_plus_4        (ifid_pc_plus_4),
        .in_rd1              (id_rd1),
        .in_rd2              (id_rd2),
        .in_imm              (id_imm),
        .in_rs1              (id_rs1),
        .in_rs2              (id_rs2),
        .in_rd               (id_rd),
        .in_funct3           (id_funct3),
        .in_funct7           (id_funct7),
        .in_predict_taken    (ifid_predict_taken),
        .in_predicted_target (ifid_predicted_target),
        .in_reg_write        (id_reg_write),
        .in_mem_read         (id_mem_read),
        .in_mem_write        (id_mem_write),
        .in_alu_src          (id_alu_src),
        .in_mem_to_reg       (id_mem_to_reg),
        .in_branch           (id_branch),
        .in_jump             (id_jump),
        .in_jalr             (id_jalr),
        .in_alu_control      (id_alu_control),
        .out_pc              (idex_pc),
        .out_pc_plus_4       (idex_pc_plus_4),
        .out_rd1             (idex_rd1),
        .out_rd2             (idex_rd2),
        .out_imm             (idex_imm),
        .out_rs1             (idex_rs1),
        .out_rs2             (idex_rs2),
        .out_rd              (idex_rd),
        .out_funct3          (idex_funct3),
        .out_funct7          (idex_funct7),
        .out_predict_taken   (idex_predict_taken),
        .out_predicted_target(idex_predicted_target),
        .out_reg_write       (idex_reg_write),
        .out_mem_read        (idex_mem_read),
        .out_mem_write       (idex_mem_write),
        .out_alu_src         (idex_alu_src),
        .out_mem_to_reg      (idex_mem_to_reg),
        .out_branch          (idex_branch),
        .out_jump            (idex_jump),
        .out_jalr            (idex_jalr),
        .out_alu_control     (idex_alu_control)
    );

    //===================================================================
    // EX stage
    //===================================================================
    EX_Stage u_ex (
        .id_ex_pc         (idex_pc),
        .id_ex_rd1        (idex_rd1),
        .id_ex_rd2        (idex_rd2),
        .id_ex_imm        (idex_imm),
        .id_ex_rs1        (idex_rs1),
        .id_ex_rs2        (idex_rs2),
        .id_ex_funct3     (idex_funct3),
        .id_ex_alu_src    (idex_alu_src),
        .id_ex_alu_control(idex_alu_control),
        .id_ex_branch     (idex_branch),
        .id_ex_jump       (idex_jump),
        .id_ex_jalr       (idex_jalr),
        .ex_mem_rd        (exmem_rd),
        .ex_mem_reg_write (exmem_reg_write),
        .ex_mem_alu_result(exmem_alu_result),
        .mem_wb_rd        (memwb_rd),
        .mem_wb_reg_write (memwb_reg_write),
        .wb_wdata         (wb_wdata),
        .ex_alu_result    (ex_alu_result),
        .ex_rs2_forwarded (ex_rs2_forwarded),
        .ex_branch_taken  (ex_branch_taken),
        .ex_branch_target (ex_branch_target)
    );

    //===================================================================
    // EX/MEM
    //===================================================================
    EX_MEM_Reg u_ex_mem (
        .clk           (clk),
        .rst           (rst),
        .in_pc_plus_4  (idex_pc_plus_4),
        .in_alu_result (ex_alu_result),
        .in_rs2_data   (ex_rs2_forwarded),
        .in_rd         (idex_rd),
        .in_reg_write  (idex_reg_write),
        .in_mem_read   (idex_mem_read),
        .in_mem_write  (idex_mem_write),
        .in_mem_to_reg (idex_mem_to_reg),
        .out_pc_plus_4 (exmem_pc_plus_4),
        .out_alu_result(exmem_alu_result),
        .out_rs2_data  (exmem_rs2_data),
        .out_rd        (exmem_rd),
        .out_reg_write (exmem_reg_write),
        .out_mem_read  (exmem_mem_read),
        .out_mem_write (exmem_mem_write),
        .out_mem_to_reg(exmem_mem_to_reg)
    );

    //===================================================================
    // MEM stage
    //===================================================================
    MEM_Stage u_mem (
        .clk              (clk),
        .rst              (rst),
        .ex_mem_mem_read  (exmem_mem_read),
        .ex_mem_mem_write (exmem_mem_write),
        .ex_mem_alu_result(exmem_alu_result),
        .ex_mem_rs2_data  (exmem_rs2_data),
        .mem_rdata        (mem_rdata)
    );

    //===================================================================
    // MEM/WB
    //===================================================================
    MEM_WB_Reg u_mem_wb (
        .clk           (clk),
        .rst           (rst),
        .in_pc_plus_4  (exmem_pc_plus_4),
        .in_alu_result (exmem_alu_result),
        .in_mem_data   (mem_rdata),
        .in_rd         (exmem_rd),
        .in_reg_write  (exmem_reg_write),
        .in_mem_to_reg (exmem_mem_to_reg),
        .out_pc_plus_4 (memwb_pc_plus_4),
        .out_alu_result(memwb_alu_result),
        .out_mem_data  (memwb_mem_data),
        .out_rd        (memwb_rd),
        .out_reg_write (memwb_reg_write),
        .out_mem_to_reg(memwb_mem_to_reg)
    );

    //===================================================================
    // WB stage
    //===================================================================
    WB_Stage u_wb (
        .mem_wb_mem_to_reg(memwb_mem_to_reg),
        .mem_wb_alu_result(memwb_alu_result),
        .mem_wb_mem_data  (memwb_mem_data),
        .mem_wb_pc_plus_4 (memwb_pc_plus_4),
        .wb_wdata         (wb_wdata)
    );
endmodule
