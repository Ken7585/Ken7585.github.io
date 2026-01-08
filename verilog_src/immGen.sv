/*
    <rv32e 立即数生成器>
    输入信号:
        instr       : 32-bit 指令输入
        pc          : 32-bit 程序计数器输入
    输出信号:
        imm_out     : 生成的立即数输出 (32-bit)
*/
module immGen(
    input  logic [31:0] instr,       // 32-bit 指令输入
    input  logic [31:0] pc,          // 32-bit 程序计数器输入
    output logic [31:0] imm_out      // 生成的立即数输出
);

    // Opcodes for different instruction types
    localparam OP_LUI   = 7'b0110111; // U-type
    localparam OP_AUIPC = 7'b0010111; // U-type
    localparam OP_JAL   = 7'b1101111; // J-type
    localparam OP_JALR  = 7'b1100111; // I-type
    localparam OP_BRANCH= 7'b1100011; // B-type
    localparam OP_LOAD  = 7'b0000011; // I-type
    localparam OP_STORE = 7'b0100011; // S-type
    localparam OP_IMM   = 7'b0010011; // I-type
    localparam OP_SYSTEM= 7'b1110011; // System (CSR)

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        unique case (opcode)
            OP_IMM,     // I-type (addi, etc.)
            OP_JALR,    // I-type (jalr)
            OP_LOAD,    // I-type (lw, lb, etc.)
            OP_SYSTEM:  // System (CSR)
                imm_out = {{20{instr[31]}}, instr[31:20]};

            OP_STORE:   // S-type (sw, sb, etc.)
                imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            OP_LUI:     // U-type (lui)
                imm_out = {instr[31:12], 12'b0};
            OP_AUIPC:   // U-type (auipc)
                imm_out = {instr[31:12], 12'b0} + pc;

            OP_BRANCH:  // B-type (beq, bne, etc.)
                imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            OP_JAL:     // J-type (jal)
                imm_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default:
                imm_out = 32'b0; // 默认输出0
        endcase
    end

endmodule