/* 
    <rv32e 指令存储器>
    输入信号:
        32-bit addr 地址
    输出信号:
        32-bit instr 指令
*/
module inst_mem(
    input  logic [31:0] addr,
    output logic [31:0] instr
);

    import "DPI-C" context function int unsigned dpi_mem_read(input int unsigned addr);

    always_comb begin
        instr = dpi_mem_read(addr);
    end
endmodule