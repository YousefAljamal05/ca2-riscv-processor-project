module rv64_pipelined_cpu(
    input clk,
    input reset
);

    // =========================================================================
    // WIRES & CONNECTIONS
    // =========================================================================
    
    // --- Hazard & Prediction Wires ---
    wire pc_write, if_id_write, control_mux_sel;
    wire [1:0] forwardA, forwardB;
    wire predict_taken_if;
    wire [63:0] predicted_target_if;
    wire branch_mispredicted_ex;
    wire is_branch_or_jump_ex;
    wire [63:0] correct_next_pc_ex;

    // --- Flush Wires ---
    // If a branch is mispredicted, we flush the IF/ID and ID/EX registers to clear wrong instructions
    wire flush_pipeline = branch_mispredicted_ex;

    // --- IF Stage Wires ---
    wire [63:0] if_pc;
    wire [31:0] if_instruction;

    // --- IF/ID Register Wires ---
    wire [63:0] id_pc;
    wire [31:0] id_instruction;

    // --- ID Stage Wires ---
    wire id_reg_write, id_mem_read, id_mem_write, id_alu_src, id_mem_to_reg;
    wire [3:0] id_alu_control;
    wire [63:0] id_read_data1, id_read_data2, id_imm;
    wire [4:0] id_rs1, id_rs2, id_rd;

    // --- ID/EX Register Wires ---
    wire ex_reg_write, ex_mem_read, ex_mem_write, ex_alu_src, ex_mem_to_reg;
    wire [3:0] ex_alu_control;
    wire [63:0] ex_pc, ex_read_data1, ex_read_data2, ex_imm;
    wire [4:0] ex_rs1, ex_rs2, ex_rd;
    wire ex_predict_taken;

    // --- EX Stage Wires ---
    wire [63:0] ex_alu_result;
    wire ex_take_branch;

    // --- EX/MEM Register Wires ---
    wire mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire [63:0] mem_alu_result, mem_write_data;
    wire [4:0] mem_rd;

    // --- MEM Stage Wires ---
    wire [63:0] mem_read_data;

    // --- MEM/WB Register Wires ---
    wire wb_reg_write, wb_mem_to_reg;
    wire [63:0] wb_read_data, wb_alu_result;
    wire [4:0] wb_rd;

    // --- WB Stage Logic ---
    wire [63:0] wb_final_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;


    // =========================================================================
    // PHASE 3 UNITS
    // =========================================================================

    HazardDetectionUnit HDU (
        .id_ex_mem_read(ex_mem_read),
        .id_ex_rd(ex_rd),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .control_mux_sel(control_mux_sel)
    );

    ForwardingUnit FW (
        .id_ex_rs1(ex_rs1),
        .id_ex_rs2(ex_rs2),
        .ex_mem_rd(mem_rd),
        .ex_mem_reg_write(mem_reg_write),
        .mem_wb_rd(wb_rd),
        .mem_wb_reg_write(wb_reg_write),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );

    BranchPredictor BP (
        .clk(clk),
        .reset(reset),
        // IF Request
        .if_pc(if_pc),
        .predict_taken(predict_taken_if),
        .predicted_target(predicted_target_if),
        // EX Update
        .update_en(is_branch_or_jump_ex),
        .update_pc(ex_pc),
        .update_taken(ex_take_branch),
        .update_target(correct_next_pc_ex)
    );


    // =========================================================================
    // PIPELINE STAGES & REGISTERS
    // =========================================================================

    // 1. INSTRUCTION FETCH
    IF_stage IF_STAGE (
        .clk(clk),
        .reset(reset),
        .pc_write(pc_write),
        .branch_mispredicted(branch_mispredicted_ex),
        .correct_next_pc(correct_next_pc_ex),
        .predict_taken(predict_taken_if),
        .predicted_target(predicted_target_if),
        .pc_out(if_pc),
        .instruction_out(if_instruction)
    );

    IF_ID IF_ID_REG (
        .clk(clk),
        .reset(reset),
        .if_id_write(if_id_write),
        .flush(flush_pipeline),
        .pc_in(if_pc),
        .instruction_in(if_instruction),
        .pc_out(id_pc),
        .instruction_out(id_instruction)
    );

    // 2. INSTRUCTION DECODE
    ID_stage ID_STAGE (
        .clk(clk),
        .instruction(id_instruction),
        .write_back_data(wb_final_data),
        .write_reg(wb_rd),
        .reg_write_wb(wb_reg_write),
        .control_mux_sel(control_mux_sel),
        .read_data1(id_read_data1),
        .read_data2(id_read_data2),
        .imm_out(id_imm),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(id_rd),
        .reg_write(id_reg_write),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .alu_src(id_alu_src),
        .mem_to_reg(id_mem_to_reg),
        .alu_control(id_alu_control)
    );

    ID_EX ID_EX_REG (
        .clk(clk),
        .reset(reset),
        .flush(flush_pipeline), // Flush if mispredict
        
        .reg_write_in(id_reg_write), .mem_read_in(id_mem_read), 
        .mem_write_in(id_mem_write), .alu_src_in(id_alu_src), 
        .mem_to_reg_in(id_mem_to_reg), .alu_control_in(id_alu_control),
        
        .pc_in(id_pc), .read_data1_in(id_read_data1), .read_data2_in(id_read_data2),
        .imm_in(id_imm), .rs1_in(id_rs1), .rs2_in(id_rs2), .rd_in(id_rd),
        .predict_taken_in(predict_taken_if),
        
        .reg_write_out(ex_reg_write), .mem_read_out(ex_mem_read), 
        .mem_write_out(ex_mem_write), .alu_src_out(ex_alu_src), 
        .mem_to_reg_out(ex_mem_to_reg), .alu_control_out(ex_alu_control),
        
        .pc_out(ex_pc), .read_data1_out(ex_read_data1), .read_data2_out(ex_read_data2),
        .imm_out(ex_imm), .rs1_out(ex_rs1), .rs2_out(ex_rs2), .rd_out(ex_rd),
        .predict_taken_out(ex_predict_taken)
    );

    // 3. EXECUTE
    EX_Stage EX_STAGE (
        .current_pc(ex_pc),
        .reg_a(ex_read_data1),
        .reg_b(ex_read_data2),
        .imm(ex_imm),
        // Decode opcode inside EX or pass fields:
        // Note: You must pass instruction fields to EX or have ID decode opcode/funct3/funct7.
        // Assuming ID passes the instruction forward, you might need to extract them here:
        .opcode(ex_imm[6:0]), // Make sure you pass the instruction to EX in reality, or extract it in ID!
        .funct3(ex_imm[14:12]), 
        .funct7(ex_imm[31:25]),
        // (NOTE: In a real pipeline, the full 32-bit instruction is usually passed to EX, or ID breaks it down. 
        // For now, ensure your ID_EX passes opcode/funct3/funct7 if your EX expects them.)

        .forwardA(forwardA),
        .forwardB(forwardB),
        .ex_mem_data(mem_alu_result), // Forwarded from EX/MEM
        .mem_wb_data(wb_final_data),  // Forwarded from MEM/WB
        .predict_taken(ex_predict_taken),

        .alu_result(ex_alu_result),
        .next_pc(correct_next_pc_ex),
        .take_branch(ex_take_branch),
        
        .branch_mispredicted(branch_mispredicted_ex),
        .is_branch_or_jump(is_branch_or_jump_ex)
    );

    EX_MEM EX_MEM_REG (
        .clk(clk),
        .reset(reset),
        
        .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read), 
        .mem_write_in(ex_mem_write), .mem_to_reg_in(ex_mem_to_reg),
        
        .alu_result_in(ex_alu_result), .reg_b_in(ex_read_data2), .rd_in(ex_rd),
        
        .reg_write_out(mem_reg_write), .mem_read_out(mem_mem_read), 
        .mem_write_out(mem_mem_write), .mem_to_reg_out(mem_mem_to_reg),
        
        .alu_result_out(mem_alu_result), .write_data_out(mem_write_data), .rd_out(mem_rd)
    );

    // 4. MEMORY
    MEM_stage MEM_STAGE (
        .clk(clk),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .alu_result(mem_alu_result),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );

    MEM_WB MEM_WB_REG (
        .clk(clk),
        .reset(reset),
        
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg),
        .read_data_in(mem_read_data), .alu_result_in(mem_alu_result), .rd_in(mem_rd),
        
        .reg_write_out(wb_reg_write), .mem_to_reg_out(wb_mem_to_reg),
        .read_data_out(wb_read_data), .alu_result_out(wb_alu_result), .rd_out(wb_rd)
    );

endmodule
