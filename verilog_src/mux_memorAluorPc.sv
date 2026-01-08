/*
    <计算结果多选器>
    输入信号: 
        Jalr:选择信号，1-写回pc，0-写回ALU或存储器数据
        MemtoReg:选择信号，0-ALU结果，1-数据存储器读出
        pc:当前程序计数器值
        alu_result:ALU计算结果
        mem_read_data:数据存储器读出数据
    输出信号: 
        wb_data:写回寄存器堆的数据
*/
module mux_memorAluorPc(
  input logic        Jump,
  input logic        MemtoReg,
  input logic        CSRRead, // 新增 CSR 读选择信号
  input logic [31:0] alu_result,
  input logic [31:0] pc,
  input logic [31:0] mem_read_data,
  input logic [31:0] csr_rdata, // 新增 CSR 数据输入
  output logic [31:0] wb_data
);

  always_comb begin
    if (Jump) begin
      wb_data = pc + 4;
    end else if (MemtoReg) begin
      wb_data = mem_read_data;
    end else if (CSRRead) begin // 如果是 CSR 指令，写回 CSR 的旧值
      wb_data = csr_rdata;
    end else begin
      wb_data = alu_result;
    end
  end
endmodule