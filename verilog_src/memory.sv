/*
    <内存模块>
    输入信号:
        clk        : 时钟信号
        MemRead    : 读使能信号
        MemWrite   : 写使能信号 
        addr       : 访问地址 (32-bit)
        write_data : 写入数据 (32-bit)
    输出信号:
        read_data  : 读取数据 (32-bit)

    注意:
        该模块通过 DPI-C 调用两个 C 接口：`dpi_mem_read` 和 `dpi_mem_write`。
        写操作在时钟上升沿当 `MemWrite` 有效时触发（同步写）；
        读操作为组合逻辑，当 `MemRead` 有效时通过 DPI 调用读取数据（异步读）。
        地址为字节地址。当前实现把读/写都当作 32-bit 单元（word）操作。
        always_ff 仅用于时序逻辑。因此always_ff 用于同步写，always_comb 用于组合读。
        NByteOp 控制读写的字节数：
          00 -> word (32-bit)
          01 -> byte (8-bit)
          10 -> half-word (16-bit)
*/

module memory(
  input  logic        clk,
  input  logic        MemRead,
  input  logic        MemWrite,
  input  logic [1:0]  NByteOp,    // 字节操作控制
  input  logic        Unsigned,
  input  logic [31:0] addr,
  input  logic [31:0] write_data,
  output logic [31:0] read_data
);

  // DPI-C
  import "DPI-C" context function int unsigned dpi_mem_read(input int unsigned addr);
  import "DPI-C" context function void dpi_mem_write(input int unsigned addr, input int unsigned data, input int unsigned len);

  // 写操作：在时钟上升沿同步写入内存
  always_ff @(posedge clk) begin
    if (MemWrite) begin
      if (NByteOp == 2'b01) begin // sb
          dpi_mem_write(addr, write_data & 32'h000000FF, 1);
      end else if (NByteOp == 2'b10) begin // sh
          dpi_mem_write(addr, write_data & 32'h0000FFFF, 2);
      end else if (NByteOp == 2'b00) begin // sw
          dpi_mem_write(addr, write_data, 4);
      end
    end
  end

  // DPI 调用可能包含仿真开销！
  // 读操作为组合逻辑，必要时调用 DPI 读取（注意 DPI 调用会有仿真开销）
  logic [31:0] mem_data;
  always_comb begin
    if (MemRead) begin
      mem_data = dpi_mem_read(addr); // 先读取一次，避免多次调用
      unique case ({NByteOp, Unsigned})
        {2'b01, 1'b1}: // lbu
          read_data = mem_data & 32'h000000FF;
        {2'b01, 1'b0}: // lb
          read_data = {{24{mem_data[7]}}, mem_data[7:0]};
        {2'b10, 1'b1}: // lhu
          read_data = mem_data & 32'h0000FFFF;
        {2'b10, 1'b0}: // lh
          read_data = {{16{mem_data[15]}}, mem_data[15:0]};
        {2'b00, 1'b0}, // lw
        {2'b00, 1'b1}:
          read_data = mem_data;
        default:
          read_data = 32'hdeadbeef; // Use a distinct value for unexpected cases
      endcase
    end else begin
      mem_data = 32'b0; // 默认值
      read_data = 32'b0; // 未使能读时输出0
    end
  end

endmodule
