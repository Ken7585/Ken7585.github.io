/*
    <rv32e 单周期cpu>
    支持指令:
        算术指令: sub, auipc
		逻辑指令: and, andi, or, ori, xor, xori
		比较指令: slt, slti, sltu, sltiu
		移位指令: sll, slli, srl, srli, sra, srai
		分支指令: beq, bne, blt, bge, bltu, bgeu
		Load/Store: lh, lhu, sh
*/
module top(
    input  wire clk,
    input  wire rst,
    output wire [31:0] pc,
    output wire [31:0] instr
);
    // 模块间信号定义
    wire [31:0] t_pc, t_pc_next;
    wire [31:0] t_instr;
    wire        t_Branch, t_MemRead, t_MemtoReg, t_MemWrite, t_ALUSrc, t_RegWrite, t_Jump, t_Jalr, t_Unsigned;
    wire        t_CSRRead, t_CSRWrite; // CSR 控制信号
    wire        t_zero, t_less, t_less_unsigned;
    wire [1:0]  t_ALUOp, t_NByteOp;
    wire [3:0]  t_ALU_control;
    wire [6:0]  t_opcode;
    wire [4:0]  t_rd, t_rs1, t_rs2;
    wire [2:0]  t_funct3;
    wire [6:0]  t_funct7;
    wire [31:0] t_rs1_rdata, t_rs2_rdata, t_imm_data;
    wire [31:0] t_ALU_input2, t_ALU_result;
    wire [31:0] t_mem_read_data;
    wire [31:0] t_write_back_data;
    wire [31:0] t_branch_target;
    wire [31:0] t_csr_rdata; // CSR 读取数据
    wire [31:0] t_csr_wdata; // CSR 写入数据
    wire [11:0] t_csr_addr;  // CSR 地址

    wire        t_IsEcall, t_IsMret;
    wire [31:0] t_mtvec, t_mepc;
    reg  [31:0] t_csr_wdata_comb;

    assign pc =  t_pc;
    assign instr = t_instr;
    assign t_csr_addr = t_imm_data[11:0]; // CSR 地址来自 I-type 立即数
    assign t_csr_wdata = t_csr_wdata_comb;

    pc pc_inst(// 时序
        .clk        (clk),
        .rst        (rst),
        .next_pc    (t_pc_next),
        .pc         (t_pc)
    );

    inst_mem inst_mem_inst(// 组合
        .addr       (t_pc),
        .instr      (t_instr)
    );

    inst_decoder inst_decoder_inst(// 组合
        .instr      (t_instr),
        .opcode     (t_opcode),
        .rd         (t_rd),
        .rs1        (t_rs1),
        .rs2        (t_rs2),
        .funct3     (t_funct3),
        .funct7     (t_funct7)
    );

    control control_inst(// 组合
        .opcode     (t_opcode),
        .funct3     (t_funct3),
        .funct7     (t_funct7),
        .rs2        (t_rs2),
        .Branch     (t_Branch),
        .MemRead    (t_MemRead),
        .MemtoReg   (t_MemtoReg),
        .ALUOp      (t_ALUOp),
        .MemWrite   (t_MemWrite),
        .ALUSrc     (t_ALUSrc),
        .RegWrite   (t_RegWrite),
        .Jump       (t_Jump),
        .Jalr       (t_Jalr),
        .NByteOp    (t_NByteOp),
        .Unsigned   (t_Unsigned),
        .CSRRead    (t_CSRRead),
        .CSRWrite   (t_CSRWrite),
        .IsEcall    (t_IsEcall),
        .IsMret     (t_IsMret)
    );

    register_file register_file_inst(// （时序）
        .clk        (clk),
        .RegWrite   (t_RegWrite),
        .rs1_addr   (t_rs1),
        .rs2_addr   (t_rs2),
        .rd_addr    (t_rd),
        .rd_wdata   (t_write_back_data),
        .rs1_rdata  (t_rs1_rdata),
        .rs2_rdata  (t_rs2_rdata)
    );

    csr_file csr_file_inst(// （时序/组合）
        .clk        (clk),
        .rst        (rst),
        .csr_addr   (t_csr_addr),
        .csr_wdata  (t_csr_wdata),
        .csr_write  (t_CSRWrite && (
            (t_funct3 == 3'b001) || // CSRRW
            (t_funct3 == 3'b101) || // CSRRWI
            ((t_funct3 == 3'b010 || t_funct3 == 3'b011) && t_rs1 != 5'b0) || // CSRRS/CSRRC
            ((t_funct3 == 3'b110 || t_funct3 == 3'b111) && t_rs1 != 5'b0)    // CSRRSI/CSRRCI
        )),
        .pc         (t_pc),
        .is_ecall   (t_IsEcall),
        .is_mret    (t_IsMret),
        .csr_rdata  (t_csr_rdata),
        .mtvec_out  (t_mtvec),
        .mepc_out   (t_mepc)
    );

    // CSR Write Data Logic
    always_comb begin
        case (t_funct3)
            3'b001: t_csr_wdata_comb = t_rs1_rdata; // CSRRW
            3'b010: t_csr_wdata_comb = t_csr_rdata | t_rs1_rdata; // CSRRS
            3'b011: t_csr_wdata_comb = t_csr_rdata & ~t_rs1_rdata; // CSRRC
            3'b101: t_csr_wdata_comb = {27'b0, t_rs1}; // CSRRWI
            3'b110: t_csr_wdata_comb = t_csr_rdata | {27'b0, t_rs1}; // CSRRSI
            3'b111: t_csr_wdata_comb = t_csr_rdata & ~{27'b0, t_rs1}; // CSRRCI
            default: t_csr_wdata_comb = 32'b0;
        endcase
    end

    immGen immGen_inst(// 组合
        .instr     (t_instr),
        .pc        (t_pc),
        .imm_out   (t_imm_data)
    );

    control_ALU control_ALU_inst(// 组合
        .ALUOp      (t_ALUOp),
        .opcode     (t_opcode),
        .funct3     (t_funct3),
        .funct7     (t_funct7),
        .ALU_ctl    (t_ALU_control)
    );

    mux_rs2orImm mux_rs2orImm_inst(// 组合
        .ALUSrc     (t_ALUSrc),
        .rs2_data   (t_rs2_rdata),
        .imm_data   (t_imm_data),
        .mux_out    (t_ALU_input2)
    );

    alu alu_inst(// 组合
        .alu_ctrl   (t_ALU_control),
        .data1      (t_rs1_rdata),
        .data2      (t_ALU_input2),
        .ALU_out    (t_ALU_result),
        .zero       (t_zero),
        .less       (t_less),
        .less_unsigned(t_less_unsigned)
    );

    memory memory_inst(// （时序）
        .clk         (clk),
        .MemRead     (t_MemRead),
        .MemWrite    (t_MemWrite),
        .NByteOp     (t_NByteOp),
        .Unsigned    (t_Unsigned),
        .addr        (t_ALU_result),
        .write_data  (t_rs2_rdata),
        .read_data   (t_mem_read_data)
    );

    mux_memorAluorPc mux_memorAluorPc_inst(// 组合
        .Jump         (t_Jump),
        .MemtoReg     (t_MemtoReg),
        .CSRRead      (t_CSRRead),
        .alu_result   (t_ALU_result),
        .pc           (t_pc),
        .mem_read_data(t_mem_read_data),
        .csr_rdata    (t_csr_rdata),
        .wb_data      (t_write_back_data)
    );

    add_branch add_branch_inst(// 组合
        .pc           (t_pc),
        .imm          (t_imm_data),
        .branch_target(t_branch_target)
    );

    mux_branch mux_branch_inst(// 组合
        .Branch       (t_Branch),
        .zero         (t_zero),
        .less         (t_less),
        .less_unsigned(t_less_unsigned),
        .funct3       (t_funct3),
        .Jump         (t_Jump),
        .Jalr         (t_Jalr),
        .IsEcall      (t_IsEcall),
        .IsMret       (t_IsMret),
        .pc           (t_pc),
        .branch_target(t_branch_target),
        .jalr_target  (t_ALU_result),
        .mtvec        (t_mtvec),
        .mepc         (t_mepc),
        .pc_next      (t_pc_next)
    );

endmodule
