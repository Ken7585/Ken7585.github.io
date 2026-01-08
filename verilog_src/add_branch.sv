/*
    <分支目标计算模块>
    输入信号:
        pc: 当前指令地址
        imm: 立即数偏移量
    输出信号:
        pc_new: 计算后的新地址 (pc + (imm << 1))
*/
module add_branch(
    input  logic [31:0] pc,
    input  logic [31:0] imm,
    output logic [31:0] branch_target
);

    // imm 由 ImmGen 输出为带符号扩展且已左移的字节偏移
    // 这里只需直接相加
    assign branch_target = pc + imm;
endmodule