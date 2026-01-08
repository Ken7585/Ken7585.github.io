/*
    <CSR 寄存器模块>
    输入信号:
        clk         : 时钟信号
        rst         : 复位信号
        csr_addr    : CSR 寄存器地址 (12-bit)
        csr_wdata   : 写入数据 (32-bit)
        csr_write   : 写使能信号
    输出信号:
        csr_rdata   : 读取数据 (32-bit)
*/
module csr_file(
    input  logic        clk,
    input  logic        rst,
    input  logic [11:0] csr_addr,
    input  logic [31:0] csr_wdata,
    input  logic        csr_write,
    input  logic [31:0] pc,
    input  logic        is_ecall,
    input  logic        is_mret,
    output logic [31:0] csr_rdata,
    output logic [31:0] mtvec_out,
    output logic [31:0] mepc_out
);

    // 定义 CSR 寄存器地址
    localparam MSTATUS_ADDR   = 12'h300;
    localparam MTVEC_ADDR     = 12'h305;
    localparam MEPC_ADDR      = 12'h341;
    localparam MCAUSE_ADDR    = 12'h342;
    localparam MCYCLE_ADDR    = 12'hB00;
    localparam MCYCLEH_ADDR   = 12'hB80;
    localparam MVENDORID_ADDR = 12'hF11;
    localparam MARCHID_ADDR   = 12'hF12;

    // 定义 CSR 寄存器
    logic [63:0] mcycle;
    logic [31:0] mstatus;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mcause;

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // 读操作 (组合逻辑)
    always_comb begin
        case (csr_addr)
            MSTATUS_ADDR:   csr_rdata = mstatus;
            MTVEC_ADDR:     csr_rdata = mtvec;
            MEPC_ADDR:      csr_rdata = mepc;
            MCAUSE_ADDR:    csr_rdata = mcause;
            MCYCLE_ADDR:    csr_rdata = mcycle[31:0];
            MCYCLEH_ADDR:   csr_rdata = mcycle[63:32];
            MVENDORID_ADDR: csr_rdata = 32'h79737978; // "ysyx"
            MARCHID_ADDR:   csr_rdata = 32'h26964ECE; // 202514131158 (lower 32 bits)
            default:        csr_rdata = 32'b0;
        endcase
    end

    // 写操作 (时序逻辑)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mcycle  <= 64'b0;
            mstatus <= 32'h1800; // Initial value (MPP=11)
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
        end else begin
            // mcycle 自动递增
            mcycle <= mcycle + 1;

            if (is_ecall) begin
                mepc   <= pc;
                mcause <= 32'd11; // Environment call from M-mode
            end else if (csr_write) begin
                case (csr_addr)
                    MSTATUS_ADDR: mstatus <= csr_wdata;
                    MTVEC_ADDR:   mtvec   <= csr_wdata;
                    MEPC_ADDR:    mepc    <= csr_wdata;
                    MCAUSE_ADDR:  mcause  <= csr_wdata;
                    MCYCLE_ADDR:  mcycle[31:0]  <= csr_wdata;
                    MCYCLEH_ADDR: mcycle[63:32] <= csr_wdata;
                endcase
            end
        end
    end

endmodule
