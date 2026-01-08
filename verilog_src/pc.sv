/*
    <程序计数器>
    输入信号:
        clk         :时钟信号
        reset       :复位信号
        next_pc     :下一个PC地址
    输出信号:
        pc          :当前PC地址
*/
module pc(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] next_pc,
    output logic [31:0] pc
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'h80000000; // 复位时设置初始 PC 地址
        end else begin
            pc <= next_pc; // 否则更新为下一个 PC 地址
        end
    end
endmodule  