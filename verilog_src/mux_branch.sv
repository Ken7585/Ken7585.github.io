/*
    <分支多选器>
    输入信号:
        Branch          :分支控制信号
        zero            :零标志信号
        pc              :当前程序计数器值
        branch_target   :分支目标地址
    输出信号:
        pc_next         :下一个程序计数器值
*/
module mux_branch(
    input  logic        Branch,
    input  logic        zero,
    input  logic        less,
    input  logic        less_unsigned,
    input  logic [2:0]  funct3,
    input  logic        Jump,           // jal/jalr 标志
    input  logic        Jalr,           // 专门标识 jalr
    input  logic        IsEcall,        // ECALL 标志
    input  logic        IsMret,         // MRET 标志
    input  logic [31:0] pc,
    input  logic [31:0] branch_target, // 用于 BEQ/BNE 或 JAL 的目标 (pc + imm)
    input  logic [31:0] jalr_target,   // 来自 ALU: rs1 + imm（用于 JALR）
    input  logic [31:0] mtvec,         // 异常入口地址
    input  logic [31:0] mepc,          // 异常返回地址
    output logic [31:0] pc_next
);

    logic branch_taken;

    always_comb begin
        case (funct3)
            3'b000: branch_taken = zero;          // BEQ
            3'b001: branch_taken = !zero;         // BNE
            3'b100: branch_taken = less;          // BLT
            3'b101: branch_taken = !less;         // BGE
            3'b110: branch_taken = less_unsigned; // BLTU
            3'b111: branch_taken = !less_unsigned;// BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    always_comb begin
        if (IsEcall) begin
            pc_next = mtvec;
        end else if (IsMret) begin
            pc_next = mepc;
        end else if (Jump && Jalr) begin             // JALR
            pc_next = {jalr_target[31:1], 1'b0};
        end else if (Jump && !Jalr) begin   // JAL
            pc_next = branch_target;
        end else if (Branch && branch_taken) begin
            pc_next = branch_target;
        end else begin
            pc_next = pc + 4;
        end
    end

endmodule