/*  
    <rv32e 控制器>
    输入信号:
        7-bit opcode
    输出信号: 
        控制信号：
            Branch, MemRead, MemtoReg, ALUOp, MemWrite, ALUSrc, RegWrite, Jump, Jalr, NByteOp
	功能描述:
		根据指令的 opcode 和 funct3 字段生成相应的控制信号。

    注意:
        完全是组合逻辑
        ALUOp 采用 2-bit 编码：
            00 -> load/store (地址计算，使用 ADD)
            01 -> branch (使用 SUB 比较)
            10 -> R-type / I-type ALU 指令（具体由 ALU_control 根据 funct 字段决定）
            11 -> LUI (特殊处理，ALU_control 可选择直接输出 LUI 动作)
*/
module control(
	input  logic [6:0] opcode,
	input  logic [2:0] funct3,
	input  logic [6:0] funct7,
	input  logic [4:0] rs2,

	output logic       Branch,
	output logic       MemRead,
	output logic       MemtoReg,
	output logic [1:0] ALUOp,
	output logic       MemWrite,
	output logic       ALUSrc,
	output logic       RegWrite,
	output logic       Jump,    // 跳转指令标志（jal/jalr）
	output logic       Jalr,     // jalr标志
	output logic [1:0] NByteOp,  // 用于 load/store 指令的字节操作控制
	output logic       Unsigned,
	output logic       CSRRead,  // CSR 读使能
	output logic       CSRWrite, // CSR 写使能
	output logic       IsEcall,
	output logic       IsMret
);

	// 默认值
	always_comb begin
		Branch   = 1'b0;
		MemRead  = 1'b0;
		MemtoReg = 1'b0;
		ALUOp    = 2'b00;
		MemWrite = 1'b0;
		ALUSrc   = 1'b0;
		RegWrite = 1'b0;
		Jump     = 1'b0;
		Jalr     = 1'b0;
		NByteOp  = 2'b00; // 00: word, 01: byte, 10: half-word
		Unsigned = 1'b0;
		CSRRead  = 1'b0;
		CSRWrite = 1'b0;
		IsEcall  = 1'b0;
		IsMret   = 1'b0;

		// 根据 opcode 设置控制信号
		unique case (opcode)
			7'b1110011: begin // SYSTEM (CSR instructions)
				if (funct3 == 3'b000) begin
					if (funct7 == 7'b0000000 && rs2 == 5'b00000) IsEcall = 1'b1;
					if (funct7 == 7'b0011000 && rs2 == 5'b00010) IsMret  = 1'b1;
				end else begin // CSRRW, CSRRS, CSRRC, etc.
					RegWrite = 1'b1; // CSR 指令通常会写回 rd
					CSRRead  = 1'b1; // 需要读 CSR
					CSRWrite = 1'b1; // 标记为 CSR 写指令，具体是否写由 top 模块判断
				end
			end

			7'b0110011: begin // R-type (add, sub, and, or, xor, slt, sltu, sll, srl, sra)
				RegWrite = 1'b1;
				ALUSrc   = 1'b0;
				ALUOp    = 2'b10;
			end

			7'b0010011: begin // I-type ALU (addi, andi, ori, xori, slti, sltiu, slli, srli, srai)
				RegWrite = 1'b1;
				ALUSrc   = 1'b1;
				ALUOp    = 2'b10;
			end

			7'b0110111: begin // LUI
				RegWrite = 1'b1;
				ALUSrc   = 1'b1;
				ALUOp    = 2'b11;
			end
            
			7'b0010111: begin // AUIPC
				RegWrite = 1'b1;
				ALUSrc   = 1'b1;
				ALUOp    = 2'b11;
			end

			7'b0000011: begin // Load (lb, lh, lw, lbu, lhu)
				RegWrite = 1'b1;
				MemRead  = 1'b1;
				MemtoReg = 1'b1;
				ALUSrc   = 1'b1;
				ALUOp    = 2'b00;
				case (funct3)
					3'b000: NByteOp = 2'b01; // lb
					3'b001: NByteOp = 2'b10; // lh
					3'b010: NByteOp = 2'b00; // lw
					3'b100: begin
						NByteOp = 2'b01; // lbu
						Unsigned = 1'b1;
					end
					3'b101: begin
						NByteOp = 2'b10; // lhu
						Unsigned = 1'b1;
					end
					default: NByteOp = 2'b11;
				endcase
			end

			7'b0100011: begin // Store (sb, sh, sw)
				RegWrite = 1'b0;
				MemWrite = 1'b1;
				ALUSrc   = 1'b1;
				ALUOp    = 2'b00;
				case (funct3)
					3'b000: NByteOp = 2'b01; // sb
					3'b001: NByteOp = 2'b10; // sh
					3'b010: NByteOp = 2'b00; // sw
					default: NByteOp = 2'bxx;
				endcase
			end

			7'b1100011: begin // Branch (beq, bne, blt, bge, bltu, bgeu)
				Branch   = 1'b1;
				ALUSrc   = 1'b0;
				ALUOp    = 2'b01;
			end

			7'b1100111: begin // JALR (I-type)
				Jump     = 1'b1;  // 属于跳转
				Jalr     = 1'b1;  // 指明是 jalr
				RegWrite = 1'b1;  // 写回 rd = pc+4
				ALUSrc   = 1'b1;  // 计算目标地址 rs1 + imm
				ALUOp    = 2'b00; // 地址计算使用 ADD
			end

			7'b1101111: begin // JAL (J-type)
				Jump     = 1'b1;  // 属于跳转
				Jalr     = 1'b0;
				RegWrite = 1'b1;  // 写回 rd = pc+4
				ALUOp    = 2'b00; // 不用于 ALU 指令（保留）
			end

			default: begin
				// 保持默认信号
			end
		endcase
	end

endmodule

