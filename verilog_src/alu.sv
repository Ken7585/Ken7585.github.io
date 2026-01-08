/*
    <rv32e ALU>
    输入信号:
        4-bit alu_ctrl (控制信号)
        32-bit data1 (操作数1)
        32-bit data2 (操作数2)
    输出信号:
        32-bit ALUresult (ALU 结果)
        1-bit  zero (结果为零标志)

    注意:
        4'b0000 -> AND
        4'b0001 -> OR
        4'b0010 -> ADD
        4'b0110 -> SUB
        4'b1111 -> LUI (直接把 imm 输出，由上层保证 imm 已左移 12 位)
        default -> 直接输出 data2（可视为 NOP/Pass-through）
*/

module alu(
    input  logic [3:0]  alu_ctrl,
    input  logic [31:0] data1,
    input  logic [31:0] data2,
    output logic [31:0] ALU_out,
    output logic        zero,
    output logic        less,
    output logic        less_unsigned
);

    logic [4:0] shift_amount;
    assign shift_amount = data2[4:0]; // 移位量取 B 的低5位

    assign less = ($signed(data1) < $signed(data2));
    assign less_unsigned = (data1 < data2);

    always_comb begin
        unique case (alu_ctrl)
            4'b0010: ALU_out = data1 + data2; // ADD
            4'b0110: ALU_out = data1 - data2; // SUB
            4'b0000: ALU_out = data1 & data2; // AND
            4'b0111: ALU_out = data1 | data2; // OR
            4'b0100: ALU_out = data1 ^ data2; // XOR
            4'b1010: ALU_out = ($signed(data1) < $signed(data2)) ? 32'd1 : 32'd0; // SLT
            4'b0011: ALU_out = (data1 < data2) ? 32'd1 : 32'd0; // SLTU
            4'b0001: ALU_out = data1 << shift_amount; // SLL
            4'b0101: ALU_out = data1 >> shift_amount; // SRL
            4'b1101: ALU_out = $signed(data1) >>> shift_amount; // SRA
            4'b1000: ALU_out = data2; // LUI, AUIPC
            default: ALU_out = 32'hdeadbeef;
        endcase
    end

    assign zero = (ALU_out == 32'b0);

endmodule
