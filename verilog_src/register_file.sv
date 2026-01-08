/*
    <rv32e 寄存器堆>
    输入信号:
        clk           : 时钟信号
        RegWrite      : 写使能信号
        rs1_addr      : 源寄存器1 地址 (5-bit)
        rs2_addr      : 源寄存器2 地址 (5-bit)
        rd_addr       : 目标寄存器 地址 (5-bit)
        rd_wdata      : 目标寄存器 写入数据 (32-bit)
    输出信号:
        rs1_rdata     : 源寄存器1 读取数据 (32-bit)
        rs2_rdata     : 源寄存器2 读取数据 (32-bit)

    注意:
        2^5 个通用寄存器，每个 32-bit
        两个读取端口（rs1, rs2）异步读取
        一个写入端口（rd）在上升沿时写入
*/

module register_file #(ADDR_WIDTH = 5, DATA_WIDTH = 32) (
    input  logic        clk,
    input  logic        RegWrite,
    input  logic [ADDR_WIDTH-1:0]  rs1_addr,
    input  logic [ADDR_WIDTH-1:0]  rs2_addr,
    input  logic [ADDR_WIDTH-1:0]  rd_addr,
    input  logic [DATA_WIDTH-1:0] rd_wdata,
    output logic [DATA_WIDTH-1:0] rs1_rdata,
    output logic [DATA_WIDTH-1:0] rs2_rdata
);

    // 寄存器数组: 使用 logic 更贴近 SystemVerilog 风格
    logic [DATA_WIDTH-1:0] regs [0:2**ADDR_WIDTH-1];

    // DPI-C function to read register value
    export "DPI-C" function dpi_read_reg;
    function int unsigned dpi_read_reg(input int unsigned addr);
        return regs[addr];
    endfunction

    // 写操作：在时钟上升沿同步写入，x0 (addr==0) 保持为0
    always_ff @(posedge clk) begin
        if (RegWrite && (rd_addr != {ADDR_WIDTH{1'b0}})) begin
            regs[rd_addr] <= rd_wdata;
        end
    end

    // 读寄存器 (对0地址始终读出0)，保持异步读取（组合逻辑）
    assign rs1_rdata = (rs1_addr == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} : regs[rs1_addr];
    assign rs2_rdata = (rs2_addr == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} : regs[rs2_addr];

endmodule
