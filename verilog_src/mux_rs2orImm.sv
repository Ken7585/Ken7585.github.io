/*  
    <rv32e 立即数选择器>
    输入信号:
        1-bit ALUSrc (选择信号)
        32-bit rs2_data (寄存器2数据)
        32-bit imm_data (立即数数据)
    输出信号:
        32-bit mux_out (多路选择器输出)

    注意:
*/
module mux_rs2orImm(
    input  logic        ALUSrc,    // 选择信号：0 -> rs2, 1 -> immediate
    input  logic [31:0] rs2_data,
    input  logic [31:0] imm_data,
    output logic [31:0] mux_out   // 多路选择器输出
);

    always_comb begin
        if (ALUSrc) begin
            mux_out = imm_data; // 选择立即数
        end else begin
            mux_out = rs2_data; // 选择寄存器数据
        end
    end
endmodule