/*  
    <rv32e ALU控制器>
    输入信号:
        来自控制器的ALUOp (2-bit)
        指令的 opcode (7-bit) 
        指令的 funct3 (3-bit)
        指令的 funct7 (7-bit)
    输出信号: 
        控制信号：
                alu_ctrl (4-bit)

    注意:
        完全是组合逻辑
        alu_ctrl 期望ALU行为如下：
            0000： AND
            0001： OR
            0010： ADD
            0110： SUB
*/
module control_ALU(
    input  logic [1:0] ALUOp,
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [3:0] ALU_ctl
);
    logic funct30;
    assign funct30 = funct7[5]; // 提取 funct30

    // ALU 控制信号定义
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_SUB  = 4'b0110;
    localparam ALU_AND  = 4'b0000;
    localparam ALU_OR   = 4'b0111;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b1010; // SLT (Signed)
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_LUI  = 4'b1111; // LUI/AUIPC
    localparam ALU_COPY_B = 4'b1000; // 用于 LUI/AUIPC

    always_comb begin
        unique case (ALUOp)
            2'b00: ALU_ctl = ALU_ADD;  // Load/Store/Jalr 地址计算
            2'b01: ALU_ctl = ALU_SUB;  // Branch 比较
            2'b11: ALU_ctl = ALU_COPY_B; // LUI/AUIPC
            2'b10: begin // R-type 和 I-type
                unique case (funct3)
                    3'b000: ALU_ctl = (funct7[5] && opcode == 7'b0110011) ? ALU_SUB : ALU_ADD; // add, addi, sub
                    3'b001: ALU_ctl = ALU_SLL;  // sll, slli
                    3'b010: ALU_ctl = ALU_SLT;  // slt, slti
                    3'b011: ALU_ctl = ALU_SLTU; // sltu, sltiu
                    3'b100: ALU_ctl = ALU_XOR;  // xor, xori
                    3'b101: ALU_ctl = (funct7[5]) ? ALU_SRA : ALU_SRL; // srl, srli, sra, srai
                    3'b110: ALU_ctl = ALU_OR;   // or, ori
                    3'b111: ALU_ctl = ALU_AND;  // and, andi
                    default: ALU_ctl = 4'bxxxx;
                endcase
            end
            default: ALU_ctl = 4'bxxxx;
        endcase
    end

endmodule
