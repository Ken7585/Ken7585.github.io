# include <stdint.h>
# include <stdio.h>
# include <stdlib.h>
#include <assert.h>
#include <chrono>  // 用于时钟功能
#include <unistd.h> // 用于 sleep 函数
# include "verilated.h"
# include "Vtop.h"
#include "Vtop___024root.h"
#include <string.h>
#include <stdbool.h>
#include "svdpi.h"
#include "Vtop__Dpi.h"

Vtop* top = new Vtop;
// 指令文件路径
# define INSTR_BIN_PATH "/home/kennn/ysyx-workbench/am-kernels/tests/cpu-tests/build/sum-minirv-npc.bin"

extern "C" void ebreak();                               // EBREAK 处理函数

//------------------------- Memory 操作 -------------------------
// 物理内存基址及大小定义、时钟地址
# define PHYS_MEM_BASE 0x80000000
# define PHYS_MEM_SIZE 0x10000000
# define RTC_ADDR 0xa0000048
# define SERIAL_PORT 0xa00003f8

int read_able = 0;
int read_failed = 0;
uint8_t physical_memory[PHYS_MEM_SIZE];

extern "C" uint32_t dpi_mem_read(uint32_t addr);                // 读
extern "C" void dpi_mem_write(uint32_t addr, uint32_t data, uint32_t len);   // 写
extern "C" uint32_t dpi_read_reg(uint32_t addr);
int load_instructions(const char* bin_file_path);           // 加载指令
//----------------------- Memory 操作 end -----------------------

//------------------------- itrace 操作 -------------------------
static const int ITRACE_SIZE = 32;
static uint32_t itrace_pc[ITRACE_SIZE];// pc 缓冲区
static uint32_t itrace_instr[ITRACE_SIZE]; // 指令缓冲区
static int itrace_pos = 0; // 下一个写入位置
static int instr_count = 0; // 已记录指令数
static int itrace_enable = 1;
void print_itrace_buffer();
void record_itrace(int itrace_enable,Vtop* itop);
//----------------------- itrace 操作 end -----------------------

void print_itrace_buffer() {
    int n = instr_count < 32 ? instr_count : 32;
    if (itrace_enable) {
        fprintf(stderr, "\n  === itrace ===\n");
        // itrace_pos 指向下一个将要写入的位置
        // 我们需要打印最近n条，从最早的一条开始顺序输出到最新的一条。
        int start = (itrace_pos - n + ITRACE_SIZE) % ITRACE_SIZE;
        for (int j = 0; j < n; j++) {
            int idx = (start + j - 1) % ITRACE_SIZE;
            fprintf(stderr, "  [%3d] pc=0x%08x instr=0x%08x\n", idx, itrace_pc[idx], itrace_instr[idx]);
        }
    }
}
void record_itrace(int itrace_enable,Vtop* itop){
    if (itrace_enable && itop && itop->rootp) {
        itrace_pc[itrace_pos] = itop->pc;
        itrace_instr[itrace_pos] = itop->instr;
        itrace_pos = (itrace_pos + 1) % ITRACE_SIZE;
    }
}

// 读取物理内存函数
extern "C" uint32_t dpi_mem_read(uint32_t addr) {
    if (addr == RTC_ADDR) {
        auto now = std::chrono::high_resolution_clock::now();
        auto duration = now.time_since_epoch();
        long long micros = std::chrono::duration_cast<std::chrono::microseconds>(duration).count();
        return (uint32_t)micros;
    } else if (addr < PHYS_MEM_BASE || addr + 4 > PHYS_MEM_BASE + PHYS_MEM_SIZE) {
        if(read_able){
            // 对越界访问，将错误信息输出到标准错误流
            fprintf(stderr, "Physical memory read  out of bounds: 0x%08x\n", addr);
            read_failed = 1;
            return 0;
        } else {
            return 0;
        }
    }

    uint32_t offset = addr - PHYS_MEM_BASE; // 计算偏移地址
    uint32_t data = 0;
    for (size_t i = 0; i < 4; i++) {
        uint8_t byte = physical_memory[offset + i];
        data |= ((uint32_t)byte) << (i * 8); // 小端序组装数据
    }
    return data;

}

// 写入物理内存函数
extern "C" void dpi_mem_write(uint32_t addr, uint32_t data, uint32_t len) {
    if (addr == SERIAL_PORT) {
        putchar(data & 0xFF);
        return;
    }
    if (addr < PHYS_MEM_BASE || addr + len > PHYS_MEM_BASE + PHYS_MEM_SIZE) {
        // 对越界访问，将错误信息输出到标准错误流
        fprintf(stderr, "Physical memory write out of bounds: 0x%08x\n", addr);
        return;
    }
    uint32_t offset = addr - PHYS_MEM_BASE; // 计算偏移地址
    for (size_t i = 0; i < len; i++) {
        physical_memory[offset + i] = (data >> (i * 8)) & 0xFF; // 小端序存储数据
    }
}

int load_instructions(const char* bin_file_path) {
    // 以二进制读模式打开文件（"rb"避免文本模式转换换行符）
    FILE* file = fopen(bin_file_path, "rb");
    if (file == NULL) {
        fprintf(stderr, "Failed to open binary file: %s\n", bin_file_path);
        exit(1);
    }

    uint32_t current_inst_addr = PHYS_MEM_BASE;
    uint32_t one_instruction;

    // 循环从file读取指令：每次读4字节写入到内存，直到文件结束
    // fread返回值=成功读取的“字节数”，返回0表示文件结束
    while (fread(&one_instruction, sizeof(one_instruction), 1, file) == 1) {
        dpi_mem_write(current_inst_addr, one_instruction, 4);
        current_inst_addr += 4;

        // 检查内存是否写满，避免越界
        if (current_inst_addr + 4 > PHYS_MEM_BASE + PHYS_MEM_SIZE) {
            fprintf(stderr, "Physical memory full: cannot load more instructions\n");
            break;
        }
    }

    // 检查是否因“读取不完整”退出（文件大小不是4的倍数）
    if (!feof(file)) {
        fprintf(stderr, "Warning: Incomplete instruction read from file\n");
    }

    // 关闭文件
    fclose(file);
    printf("Successfully loaded instructions to memory. Start addr: 0x%08x, End addr: 0x%08x\n",PHYS_MEM_BASE, current_inst_addr - 4);
    return 0;
}

extern "C" void ebreak() {
    svScope scope = svGetScopeFromName("TOP.top.register_file_inst");
    if (!scope) {
        fprintf(stderr, "Error: Register file scope not found. Make sure the module name is correct.\n");
        exit(1);
    }
    svSetScope(scope);
    uint32_t a0 = dpi_read_reg(10);
    
    printf("EBREAK instruction encountered at pc=0x%x\n", top->pc);
    if(a0 == 0) {
        printf("HIT GOOD TRAP\n");
        exit(0);
    } else {
        printf("HIT BAD TRAP\n");
        exit(1);
    }
}

static void single_cycle(void) 
{
    if(!Verilated::gotFinish())
    { 
        top->clk = 0; top->eval(); //推动仿真时间
        top->clk = 1; top->eval(); //推动仿真时间
    }
}

int main(int argc, char *argv[])
{
    const char *bin_path = NULL;
    if (argc > 1 && argv[1] && argv[1][0] != '\0') {
        bin_path = argv[1];
    } else {
        const char *env_img = getenv("IMG");
        if (env_img && env_img[0] != '\0') bin_path = env_img;
        else bin_path = INSTR_BIN_PATH;
    }

    load_instructions(bin_path);
    Verilated::commandArgs(argc, argv);
    top->rst = 0;
    single_cycle();
    top->rst = 1;
    single_cycle();
    top->rst = 0;
    read_able = 1;
    printf("After reset: pc=0x%08x instr=0x%08x\n",top->pc,top->instr);
    while(1)
    {
        record_itrace(itrace_enable,top);
        single_cycle();
        instr_count++;
        if (read_failed) {
            record_itrace(itrace_enable,top);
            print_itrace_buffer();
            exit(1);
        }
        
    }
    delete top;
    return 0;
}