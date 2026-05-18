`timescale 1ns/1ps

module RISCV_TOP (
    // General Signals
    input  wire        CLK,
    input  wire        RSTn,

    // I-Memory Signals
    output wire        I_MEM_CSN,
    input  wire [31:0] I_MEM_DI,
    output wire [11:0] I_MEM_ADDR,

    // D-Memory Signals
    output wire        D_MEM_CSN,
    input  wire [31:0] D_MEM_DI,
    output wire [31:0] D_MEM_DOUT,
    output wire [11:0] D_MEM_ADDR,
    output wire        D_MEM_WEN,
    output wire [3:0]  D_MEM_BE,

    // RegFile Signals
    output wire        RF_WE,
    output wire [4:0]  RF_RA1,
    output wire [4:0]  RF_RA2,
    output wire [4:0]  RF_WA1,
    input  wire [31:0] RF_RD1,
    input  wire [31:0] RF_RD2,
    output wire [31:0] RF_WD,

    output wire        HALT,
    output reg  [31:0] NUM_INST,
    output reg  [31:0] OUTPUT_PORT
);

    // ============================================================

    // Global memory chip-selects
    // ============================================================
    assign I_MEM_CSN = ~RSTn;
    assign D_MEM_CSN = ~RSTn;

    // ============================================================
    // IF stage
    // ============================================================
    reg [11:0] pc;
    wire [11:0] pc_plus4 = pc + 12'd4;

    wire pc_write;
    wire if_id_write;
    wire id_ex_flush_from_hazard;

    wire branch_taken_ex;
    wire [11:0] branch_target_ex;

    wire flush_pipeline = branch_taken_ex;
    wire [11:0] pc_next = branch_taken_ex ? branch_target_ex : pc_plus4;

    assign I_MEM_ADDR = pc;

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            pc <= 12'd0;
        end else if (pc_write) begin
            pc <= pc_next;
        end
    end

    // ============================================================
    // IF/ID pipeline register
    // ============================================================
    wire [11:0] if_id_pc;
    wire [31:0] if_id_inst;

    pipe_if_id u_pipe_if_id (
        .clk      (CLK),
        .rstn     (RSTn),
        .write_en (if_id_write),
        .flush    (flush_pipeline),
        .pc_in    (pc),
        .inst_in  (I_MEM_DI),
        .pc_out   (if_id_pc),
        .inst_out (if_id_inst)
    );

    // ============================================================
    // ID stage
    // ============================================================
    wire [6:0] opcode_id = if_id_inst[6:0];
    wire [4:0] rd_id     = if_id_inst[11:7];
    wire [2:0] funct3_id = if_id_inst[14:12];
    wire [4:0] rs1_id    = if_id_inst[19:15];
    wire [4:0] rs2_id    = if_id_inst[24:20];
    wire [6:0] funct7_id = if_id_inst[31:25];

    wire [31:0] imm_id;

    imm_gen u_imm_gen (
        .inst (if_id_inst),
        .imm  (imm_id)
    );

    wire reg_write_id;
    wire mem_read_id;
    wire mem_write_id;
    wire mem_to_reg_id;
    wire alu_src_id;
    wire branch_id;
    wire jump_id;
    wire [3:0] alu_ctrl_id;

    control_unit u_control_unit (
        .opcode    (opcode_id),
        .funct3    (funct3_id),
        .funct7    (funct7_id),
        .reg_write (reg_write_id),
        .mem_read  (mem_read_id),
        .mem_write (mem_write_id),
        .mem_to_reg(mem_to_reg_id),
        .alu_src   (alu_src_id),
        .branch    (branch_id),
        .jump      (jump_id),
        .alu_ctrl  (alu_ctrl_id)
    );

    assign RF_RA1 = rs1_id;
    assign RF_RA2 = rs2_id;

    // ============================================================
    // ID/EX pipeline register
    // ============================================================
    wire        id_ex_reg_write;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire        id_ex_mem_to_reg;
    wire        id_ex_alu_src;
    wire        id_ex_branch;
    wire        id_ex_jump;
    wire [3:0]  id_ex_alu_ctrl;
    wire [11:0] id_ex_pc;
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire [4:0]  id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire [6:0]  id_ex_opcode;
    wire [31:0] id_ex_inst;

    wire id_ex_flush = flush_pipeline | id_ex_flush_from_hazard;

    pipe_id_ex u_pipe_id_ex (
        .clk              (CLK),
        .rstn             (RSTn),
        .flush            (id_ex_flush),
        .reg_write_in     (reg_write_id),
        .mem_read_in      (mem_read_id),
        .mem_write_in     (mem_write_id),
        .mem_to_reg_in    (mem_to_reg_id),
        .alu_src_in       (alu_src_id),
        .branch_in        (branch_id),
        .jump_in          (jump_id),
        .alu_ctrl_in      (alu_ctrl_id),
        .pc_in            (if_id_pc),
        .rs1_data_in      (RF_RD1),
        .rs2_data_in      (RF_RD2),
        .imm_in           (imm_id),
        .rs1_in           (rs1_id),
        .rs2_in           (rs2_id),
        .rd_in            (rd_id),
        .funct3_in        (funct3_id),
        .opcode_in        (opcode_id),
        .inst_in          (if_id_inst),
        .reg_write_out    (id_ex_reg_write),
        .mem_read_out     (id_ex_mem_read),
        .mem_write_out    (id_ex_mem_write),
        .mem_to_reg_out   (id_ex_mem_to_reg),
        .alu_src_out      (id_ex_alu_src),
        .branch_out       (id_ex_branch),
        .jump_out         (id_ex_jump),
        .alu_ctrl_out     (id_ex_alu_ctrl),
        .pc_out           (id_ex_pc),
        .rs1_data_out     (id_ex_rs1_data),
        .rs2_data_out     (id_ex_rs2_data),
        .imm_out          (id_ex_imm),
        .rs1_out          (id_ex_rs1),
        .rs2_out          (id_ex_rs2),
        .rd_out           (id_ex_rd),
        .funct3_out       (id_ex_funct3),
        .opcode_out       (id_ex_opcode),
        .inst_out         (id_ex_inst)
    );

    // ============================================================
    // Hazard unit
    // ============================================================
    hazard_unit u_hazard_unit (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (rs1_id),
        .if_id_rs2      (rs2_id),
        .pc_write       (pc_write),
        .if_id_write    (if_id_write),
        .id_ex_flush    (id_ex_flush_from_hazard)
    );

    // ============================================================
    // EX stage
    // ============================================================
    wire [1:0] forward_a;
    wire [1:0] forward_b;

    wire        ex_mem_reg_write;
    wire [4:0]  ex_mem_rd;
    wire [31:0] ex_mem_alu_result;

    wire        mem_wb_reg_write;
    wire [4:0]  mem_wb_rd;
    wire [31:0] wb_write_data;

    forwarding_unit u_forwarding_unit (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .ex_mem_rd        (ex_mem_rd),
        .mem_wb_rd        (mem_wb_rd),
        .ex_mem_reg_write (ex_mem_reg_write),
        .mem_wb_reg_write (mem_wb_reg_write),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    reg [31:0] alu_in_a;
    reg [31:0] forwarded_rs2;

    always @(*) begin
        case (forward_a)
            2'b10: alu_in_a = ex_mem_alu_result;
            2'b01: alu_in_a = wb_write_data;
            default: alu_in_a = id_ex_rs1_data;
        endcase

        case (forward_b)
            2'b10: forwarded_rs2 = ex_mem_alu_result;
            2'b01: forwarded_rs2 = wb_write_data;
            default: forwarded_rs2 = id_ex_rs2_data;
        endcase
    end

    wire [31:0] alu_in_b = id_ex_alu_src ? id_ex_imm : forwarded_rs2;
    wire [31:0] alu_result_ex;
    wire alu_zero_ex;

    alu u_alu (
        .a        (alu_in_a),
        .b        (alu_in_b),
        .alu_ctrl (id_ex_alu_ctrl),
        .result   (alu_result_ex),
        .zero     (alu_zero_ex)
    );

    branch_unit u_branch_unit (
        .opcode        (id_ex_opcode),
        .funct3        (id_ex_funct3),
        .branch        (id_ex_branch),
        .jump          (id_ex_jump),
        .pc            (id_ex_pc),
        .rs1_value     (alu_in_a),
        .rs2_value     (forwarded_rs2),
        .imm           (id_ex_imm),
        .branch_taken  (branch_taken_ex),
        .branch_target (branch_target_ex)
    );

    wire [31:0] ex_result_final = id_ex_jump ? {20'd0, id_ex_pc + 12'd4} : alu_result_ex;

    // ============================================================
    // EX/MEM pipeline register
    // ============================================================
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire        ex_mem_mem_to_reg;
    wire [31:0] ex_mem_rs2_data;
    wire [2:0]  ex_mem_funct3;
    wire [31:0] ex_mem_inst;
    wire        ex_mem_branch;
    wire        ex_mem_branch_taken;
    wire        ex_mem_jump;
    wire [11:0] ex_mem_branch_target;

    pipe_ex_mem u_pipe_ex_mem (
        .clk               (CLK),
        .rstn              (RSTn),
        .reg_write_in      (id_ex_reg_write),
        .mem_read_in       (id_ex_mem_read),
        .mem_write_in      (id_ex_mem_write),
        .mem_to_reg_in     (id_ex_mem_to_reg),
        .alu_result_in     (ex_result_final),
        .rs2_data_in       (forwarded_rs2),
        .rd_in             (id_ex_rd),
        .funct3_in         (id_ex_funct3),
        .inst_in           (id_ex_inst),
        .branch_in         (id_ex_branch),
        .branch_taken_in   (branch_taken_ex),
        .jump_in           (id_ex_jump),
        .branch_target_in  (branch_target_ex),
        .reg_write_out     (ex_mem_reg_write),
        .mem_read_out      (ex_mem_mem_read),
        .mem_write_out     (ex_mem_mem_write),
        .mem_to_reg_out    (ex_mem_mem_to_reg),
        .alu_result_out    (ex_mem_alu_result),
        .rs2_data_out      (ex_mem_rs2_data),
        .rd_out            (ex_mem_rd),
        .funct3_out        (ex_mem_funct3),
        .inst_out          (ex_mem_inst),
        .branch_out        (ex_mem_branch),
        .branch_taken_out  (ex_mem_branch_taken),
        .jump_out          (ex_mem_jump),
        .branch_target_out (ex_mem_branch_target)
    );

    // ============================================================
    // MEM stage
    // ============================================================
    assign D_MEM_ADDR = ex_mem_alu_result[11:0];
    assign D_MEM_DOUT = ex_mem_rs2_data;
    assign D_MEM_WEN  = ~ex_mem_mem_write; // Matches common active-low WEN convention from your previous code

    store_byte_enable u_store_byte_enable (
        .mem_write (ex_mem_mem_write),
        .funct3    (ex_mem_funct3),
        .addr      (ex_mem_alu_result[1:0]),
        .be        (D_MEM_BE)
    );

    wire [31:0] load_data_mem;

    load_extender u_load_extender (
        .data_in  (D_MEM_DI),
        .funct3   (ex_mem_funct3),
        .addr     (ex_mem_alu_result[1:0]),
        .data_out (load_data_mem)
    );

    // ============================================================
    // MEM/WB pipeline register
    // ============================================================
    wire        mem_wb_mem_write;
    wire        mem_wb_branch;
    wire        mem_wb_branch_taken;
    wire        mem_wb_jump;
    wire [11:0] mem_wb_branch_target;
    wire        mem_wb_mem_to_reg;
    wire [31:0] mem_wb_mem_data;
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_inst;

    pipe_mem_wb u_pipe_mem_wb (
        .clk               (CLK),
        .rstn              (RSTn),

        .reg_write_in      (ex_mem_reg_write),
        .mem_write_in      (ex_mem_mem_write),
        .branch_in         (ex_mem_branch),
        .branch_taken_in   (ex_mem_branch_taken),
        .jump_in           (ex_mem_jump),
        .branch_target_in  (ex_mem_branch_target),
        .mem_to_reg_in     (ex_mem_mem_to_reg),
        .mem_data_in       (load_data_mem),
        .alu_result_in     (ex_mem_alu_result),
        .rd_in             (ex_mem_rd),
        .inst_in           (ex_mem_inst),

        .reg_write_out     (mem_wb_reg_write),
        .mem_write_out     (mem_wb_mem_write),
        .branch_out        (mem_wb_branch),
        .branch_taken_out  (mem_wb_branch_taken),
        .jump_out          (mem_wb_jump),
        .branch_target_out (mem_wb_branch_target),
        .mem_to_reg_out    (mem_wb_mem_to_reg),
        .mem_data_out      (mem_wb_mem_data),
        .alu_result_out    (mem_wb_alu_result),
        .rd_out            (mem_wb_rd),
        .inst_out          (mem_wb_inst)
    );

    // ============================================================
    // WB stage
    // ============================================================
    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result;

    assign RF_WE  = mem_wb_reg_write && (mem_wb_rd != 5'd0);
    assign RF_WA1 = mem_wb_rd;
    assign RF_WD  = wb_write_data;

    assign HALT = (mem_wb_inst == 32'h00008067); // Common ret instruction halt convention for simple testbenches

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            NUM_INST    <= 32'd0;
            OUTPUT_PORT <= 32'd0;
        end else begin
            if (mem_wb_inst != 32'h00000013 &&
                mem_wb_inst !== 32'bx &&
                mem_wb_inst != 32'd0) begin

                NUM_INST <= NUM_INST + 32'd1;

                if (mem_wb_mem_write) begin
                    // Store instruction: output store target byte address
                    OUTPUT_PORT <= {20'd0, mem_wb_alu_result[11:0]};
                end else if (mem_wb_jump) begin
                    // Jump instruction: output link address / write-back data
                    OUTPUT_PORT <= wb_write_data;
                end else if (mem_wb_branch) begin
                    // Branch instruction: output taken/not-taken
                    OUTPUT_PORT <= {31'd0, mem_wb_branch_taken};
                end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0)) begin
                    // Register-write instruction: output write-back data
                    OUTPUT_PORT <= wb_write_data;
                end
            end
        end
    end

endmodule

// ================================================================
// IF/ID pipeline register
// ================================================================
module pipe_if_id (
    input  wire        clk,
    input  wire        rstn,
    input  wire        write_en,
    input  wire        flush,
    input  wire [11:0] pc_in,
    input  wire [31:0] inst_in,
    output reg  [11:0] pc_out,
    output reg  [31:0] inst_out
);
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pc_out   <= 12'd0;
            inst_out <= 32'h00000013; // NOP: ADDI x0, x0, 0
        end else if (flush) begin
            pc_out   <= 12'd0;
            inst_out <= 32'h00000013;
        end else if (write_en) begin
            pc_out   <= pc_in;
            inst_out <= inst_in;
        end
    end
endmodule

// ================================================================
// ID/EX pipeline register
// ================================================================
module pipe_id_ex (
    input  wire        clk,
    input  wire        rstn,
    input  wire        flush,

    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        alu_src_in,
    input  wire        branch_in,
    input  wire        jump_in,
    input  wire [3:0]  alu_ctrl_in,
    input  wire [11:0] pc_in,
    input  wire [31:0] rs1_data_in,
    input  wire [31:0] rs2_data_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rs1_in,
    input  wire [4:0]  rs2_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    input  wire [6:0]  opcode_in,
    input  wire [31:0] inst_in,

    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         alu_src_out,
    output reg         branch_out,
    output reg         jump_out,
    output reg  [3:0]  alu_ctrl_out,
    output reg  [11:0] pc_out,
    output reg  [31:0] rs1_data_out,
    output reg  [31:0] rs2_data_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rs1_out,
    output reg  [4:0]  rs2_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg  [6:0]  opcode_out,
    output reg  [31:0] inst_out
);
    always @(posedge clk or negedge rstn) begin
        if (!rstn || flush) begin
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            alu_src_out    <= 1'b0;
            branch_out     <= 1'b0;
            jump_out       <= 1'b0;
            alu_ctrl_out   <= 4'd0;
            pc_out         <= 12'd0;
            rs1_data_out   <= 32'd0;
            rs2_data_out   <= 32'd0;
            imm_out        <= 32'd0;
            rs1_out        <= 5'd0;
            rs2_out        <= 5'd0;
            rd_out         <= 5'd0;
            funct3_out     <= 3'd0;
            opcode_out     <= 7'd0;
            inst_out       <= 32'h00000013;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_src_out    <= alu_src_in;
            branch_out     <= branch_in;
            jump_out       <= jump_in;
            alu_ctrl_out   <= alu_ctrl_in;
            pc_out         <= pc_in;
            rs1_data_out   <= rs1_data_in;
            rs2_data_out   <= rs2_data_in;
            imm_out        <= imm_in;
            rs1_out        <= rs1_in;
            rs2_out        <= rs2_in;
            rd_out         <= rd_in;
            funct3_out     <= funct3_in;
            opcode_out     <= opcode_in;
            inst_out       <= inst_in;
        end
    end
endmodule

// ================================================================
// EX/MEM pipeline register
// ================================================================
module pipe_ex_mem (
    input  wire        clk,
    input  wire        rstn,

    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire [31:0] alu_result_in,
    input  wire [31:0] rs2_data_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    input  wire [31:0] inst_in,
    input  wire        branch_in,
    input  wire        branch_taken_in,
    input  wire        jump_in,
    input  wire [11:0] branch_target_in,

    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] rs2_data_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg  [31:0] inst_out,
    output reg         branch_out,
    output reg         branch_taken_out,
    output reg         jump_out,
    output reg [11:0]  branch_target_out
);
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            alu_result_out <= 32'd0;
            rs2_data_out   <= 32'd0;
            rd_out         <= 5'd0;
            funct3_out     <= 3'd0;
            inst_out       <= 32'h00000013;
            branch_out     <= 1'b0;
            branch_taken_out <= 1'b0;
            jump_out       <= 1'b0;
            branch_target_out <= 12'd0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_result_out <= alu_result_in;
            rs2_data_out   <= rs2_data_in;
            rd_out         <= rd_in;
            funct3_out     <= funct3_in;
            inst_out       <= inst_in;
            branch_out     <= branch_in;
            branch_taken_out <= branch_taken_in;
            jump_out       <= jump_in;
            branch_target_out <= branch_target_in;
        end
    end
endmodule

// ================================================================
// MEM/WB pipeline register
// ================================================================
module pipe_mem_wb (
    input  wire        clk,
    input  wire        rstn,

    input  wire        reg_write_in,
    input  wire        mem_write_in,
    input  wire        branch_in,
    input  wire        branch_taken_in,
    input  wire        jump_in,
    input  wire [11:0] branch_target_in,
    input  wire        mem_to_reg_in,
    input  wire [31:0] mem_data_in,
    input  wire [31:0] alu_result_in,
    input  wire [4:0]  rd_in,
    input  wire [31:0] inst_in,

    output reg         reg_write_out,
    output reg         mem_write_out,
    output reg         branch_out,
    output reg         branch_taken_out,
    output reg         jump_out,
    output reg [11:0]  branch_target_out,
    output reg         mem_to_reg_out,
    output reg  [31:0] mem_data_out,
    output reg  [31:0] alu_result_out,
    output reg  [4:0]  rd_out,
    output reg  [31:0] inst_out
);
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            reg_write_out     <= 1'b0;
            mem_write_out     <= 1'b0;
            branch_out        <= 1'b0;
            branch_taken_out  <= 1'b0;
            jump_out          <= 1'b0;
            branch_target_out <= 12'd0;
            mem_to_reg_out    <= 1'b0;
            mem_data_out      <= 32'd0;
            alu_result_out    <= 32'd0;
            rd_out            <= 5'd0;
            inst_out          <= 32'h00000013;
        end else begin
            reg_write_out     <= reg_write_in;
            mem_write_out     <= mem_write_in;
            branch_out        <= branch_in;
            branch_taken_out  <= branch_taken_in;
            jump_out          <= jump_in;
            branch_target_out <= branch_target_in;
            mem_to_reg_out    <= mem_to_reg_in;
            mem_data_out      <= mem_data_in;
            alu_result_out    <= alu_result_in;
            rd_out            <= rd_in;
            inst_out          <= inst_in;
        end
    end
endmodule

// ================================================================
// Control unit
// ================================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        alu_src,
    output reg        branch,
    output reg        jump,
    output reg [3:0]  alu_ctrl
);
    localparam OP_RTYPE = 7'b0110011;
    localparam OP_ITYPE = 7'b0010011;
    localparam OP_LOAD  = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BRANCH= 7'b1100011;
    localparam OP_JAL   = 7'b1101111;
    localparam OP_JALR  = 7'b1100111;

    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_SLT = 4'd5;
    localparam ALU_SLTU= 4'd6;
    localparam ALU_SLL = 4'd7;
    localparam ALU_SRL = 4'd8;
    localparam ALU_SRA = 4'd9;

    always @(*) begin
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_ctrl   = ALU_ADD;

        case (opcode)
            OP_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                case (funct3)
                    3'b000: alu_ctrl = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b111: alu_ctrl = ALU_AND;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b101: alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            OP_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;  // ADDI
                    3'b111: alu_ctrl = ALU_AND;  // ANDI
                    3'b110: alu_ctrl = ALU_OR;   // ORI
                    3'b100: alu_ctrl = ALU_XOR;  // XORI
                    3'b010: alu_ctrl = ALU_SLT;  // SLTI
                    3'b011: alu_ctrl = ALU_SLTU; // SLTIU
                    3'b001: alu_ctrl = ALU_SLL;  // SLLI
                    3'b101: alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                alu_ctrl   = ALU_ADD;
            end

            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            OP_BRANCH: begin
                branch  = 1'b1;
                alu_src = 1'b0;
                alu_ctrl = ALU_SUB;
            end

            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            OP_JALR: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
            end
        endcase
    end
endmodule

// ================================================================
// Immediate generator
// ================================================================
module imm_gen (
    input  wire [31:0] inst,
    output reg  [31:0] imm
);
    wire [6:0] opcode = inst[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, // I-type ALU
            7'b0000011, // LOAD
            7'b1100111: // JALR
                imm = {{20{inst[31]}}, inst[31:20]};

            7'b0100011: // STORE
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

            7'b1100011: // BRANCH
                imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

            7'b1101111: // JAL
                imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

            default:
                imm = 32'd0;
        endcase
    end
endmodule

// ================================================================
// ALU
// ================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR  = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_SLT = 4'd5;
    localparam ALU_SLTU= 4'd6;
    localparam ALU_SLL = 4'd7;
    localparam ALU_SRL = 4'd8;
    localparam ALU_SRA = 4'd9;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            default:  result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule

// ================================================================
// Branch and jump unit
// ================================================================
module branch_unit (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire        branch,
    input  wire        jump,
    input  wire [11:0] pc,
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    input  wire [31:0] imm,
    output reg         branch_taken,
    output reg  [11:0] branch_target
);
    wire branch_eq  = (rs1_value == rs2_value);
    wire branch_lt  = ($signed(rs1_value) < $signed(rs2_value));
    wire branch_ltu = (rs1_value < rs2_value);

    wire [31:0] branch_sum = (rs1_value + imm);
    always @(*) begin
        branch_taken  = 1'b0;
        branch_target = pc + imm[11:0];

        if (jump) begin
            branch_taken = 1'b1;
            if (opcode == 7'b1100111) begin
                branch_target = branch_sum[11:0] & 12'hFFE; // JALR
            end else begin
                branch_target = pc + imm[11:0]; // JAL
            end
        end else if (branch) begin
            case (funct3)
                3'b000: branch_taken = branch_eq;       // BEQ
                3'b001: branch_taken = ~branch_eq;      // BNE
                3'b100: branch_taken = branch_lt;       // BLT
                3'b101: branch_taken = ~branch_lt;      // BGE
                3'b110: branch_taken = branch_ltu;      // BLTU
                3'b111: branch_taken = ~branch_ltu;     // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end
endmodule

// ================================================================
// Load-use hazard detection
// ================================================================
module hazard_unit (
    input  wire       id_ex_mem_read,
    input  wire [4:0] id_ex_rd,
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    output reg        pc_write,
    output reg        if_id_write,
    output reg        id_ex_flush
);
    always @(*) begin
        pc_write    = 1'b1;
        if_id_write = 1'b1;
        id_ex_flush = 1'b0;

        if (id_ex_mem_read && (id_ex_rd != 5'd0) &&
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            pc_write    = 1'b0;
            if_id_write = 1'b0;
            id_ex_flush = 1'b1;
        end
    end
endmodule

// ================================================================
// Forwarding unit
// forward_a/forward_b:
// 00 = use ID/EX value
// 10 = use EX/MEM ALU result
// 01 = use MEM/WB writeback value
// ================================================================
module forwarding_unit (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    input  wire [4:0] ex_mem_rd,
    input  wire [4:0] mem_wb_rd,
    input  wire       ex_mem_reg_write,
    input  wire       mem_wb_reg_write,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a = 2'b01;
        end

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b = 2'b01;
        end
    end
endmodule

// ================================================================
// Store byte-enable generator
// ================================================================
module store_byte_enable (
    input  wire       mem_write,
    input  wire [2:0] funct3,
    input  wire [1:0] addr,
    output reg  [3:0] be
);
    always @(*) begin
        be = 4'b0000;
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    case (addr)
                        2'b00: be = 4'b0001;
                        2'b01: be = 4'b0010;
                        2'b10: be = 4'b0100;
                        2'b11: be = 4'b1000;
                    endcase
                end
                3'b001: begin // SH
                    be = addr[1] ? 4'b1100 : 4'b0011;
                end
                3'b010: begin // SW
                    be = 4'b1111;
                end
                default: be = 4'b0000;
            endcase
        end
    end
endmodule

// ================================================================
// Load data extender
// ================================================================
module load_extender (
    input  wire [31:0] data_in,
    input  wire [2:0]  funct3,
    input  wire [1:0]  addr,
    output reg  [31:0] data_out
);
    reg [7:0]  selected_byte;
    reg [15:0] selected_half;

    always @(*) begin
        case (addr)
            2'b00: selected_byte = data_in[7:0];
            2'b01: selected_byte = data_in[15:8];
            2'b10: selected_byte = data_in[23:16];
            2'b11: selected_byte = data_in[31:24];
        endcase

        selected_half = addr[1] ? data_in[31:16] : data_in[15:0];

        case (funct3)
            3'b000: data_out = {{24{selected_byte[7]}}, selected_byte}; // LB
            3'b001: data_out = {{16{selected_half[15]}}, selected_half}; // LH
            3'b010: data_out = data_in;                                  // LW
            3'b100: data_out = {24'd0, selected_byte};                   // LBU
            3'b101: data_out = {16'd0, selected_half};                   // LHU
            default: data_out = data_in;
        endcase
    end
endmodule
