/*  
    <rv32e 指令解码器>
    输入信号:
		32-bit 指令
    输出信号: 
        各字段
			opcode, rd, rs1, rs2, funct3, funct7

    注意:
		完全是组合逻辑
		logic仅能被赋值一次，所以这里只做简单字段提取，复杂的立即数生成等留给ImmGen模块处理
*/

module inst_decoder(
	input  logic [31:0] instr,      // 32-bit 指令输入

	// 原始字段直接输出
	output logic [6:0]  opcode,
	output logic [4:0]  rd,
	output logic [4:0]  rs1,
	output logic [4:0]  rs2,
	output logic [2:0]  funct3,
	output logic [6:0]  funct7

);
	import "DPI-C" context function void ebreak();
	always_comb begin
		if (instr[31:0] == 32'b00000000000100000000000001110011) begin
			ebreak();
		end
	end
	// 提取通用字段
	assign opcode = instr[6:0];
	assign rd     = instr[11:7];
	assign funct3 = instr[14:12];
	assign rs1    = instr[19:15];
	assign rs2    = instr[24:20];
	assign funct7 = instr[31:25];

endmodule

