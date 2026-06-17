//==============================================================================
// MIPS Top-Level Module 
//==============================================================================
`timescale 1ns / 1ps

module mips (
    input  wire        clk,
    input  wire        rst_n,
    
    // I/O Ports (Memory-Mapped)
    input  wire [7:0]  switches,    // Input port for Address 0x90 (Read-Only)
    output wire        pwm_out,     // Output port for Address 0x98 (Duty Cycle)
    
    // Debug Outputs
    output wire [31:0] pc_out,
    output wire [31:0] alu_result
);

    // --- Internal Wires ---
    wire [31:0] instr_D;
    wire        reg_write_D, mem_to_reg_D, mem_write_D, branch_D, alu_src_D, reg_dst_D, jump_D;
    wire [2:0]  alu_ctrl_D;
    
    wire [4:0]  rs_D, rt_D, rs_E, rt_E, write_reg_E, write_reg_M, write_reg_W;
    wire        reg_write_E, reg_write_M, reg_write_W;
    wire        mem_to_reg_E, mem_to_reg_M;
    
    wire [1:0]  forward_a_E, forward_b_E, forward_a_D, forward_b_D; 
    wire        stall_F, stall_D, flush_E; 

    wire        mem_write_M;   // MEM stage write enable signal line
    wire [31:0] alu_result_M;  // MEM stage memory address bus
    wire [31:0] write_data_M;  // MEM stage memory write data bus
    wire [31:0] read_data_M;   // Return bus for data read from memory

    // --- Control Unit ---
    control_unit u_control (
        .opcode(instr_D[31:26]),
        .funct(instr_D[5:0]),
        .mem_to_reg(mem_to_reg_D),
        .mem_write(mem_write_D),
        .branch(branch_D),
        .alu_src(alu_src_D),
        .reg_dst(reg_dst_D),
        .reg_write(reg_write_D),
        .jump(jump_D),
        .alu_ctrl(alu_ctrl_D)
    );

    // --- Hazard Unit ---
    hazard_unit u_hazard (
        .rs_E(rs_E), .rt_E(rt_E),
        .write_reg_E(write_reg_E), .reg_write_E(reg_write_E), .mem_to_reg_E(mem_to_reg_E),
        .write_reg_M(write_reg_M), .reg_write_M(reg_write_M), .mem_to_reg_M(mem_to_reg_M),
        .write_reg_W(write_reg_W), .reg_write_W(reg_write_W),
        .rs_D(rs_D), .rt_D(rt_D),
        .branch_D(branch_D),
        .forward_a_E(forward_a_E), .forward_b_E(forward_b_E),
        .forward_a_D(forward_a_D), .forward_b_D(forward_b_D),
        .stall_F(stall_F), .stall_D(stall_D), .flush_E(flush_E)
    );

    // --- Datapath ---
    datapath u_datapath (
        .clk(clk), .rst_n(rst_n),
        .reg_write_D(reg_write_D), .mem_to_reg_D(mem_to_reg_D), .mem_write_D(mem_write_D),
        .alu_ctrl_D(alu_ctrl_D), .alu_src_D(alu_src_D), .reg_dst_D(reg_dst_D), 
        .branch_D(branch_D), .jump_D(jump_D),
        .forward_a_E(forward_a_E), .forward_b_E(forward_b_E),
        .forward_a_D(forward_a_D), .forward_b_D(forward_b_D),
        .stall_F(stall_F), .stall_D(stall_D), .flush_E(flush_E),
        .rs_D(rs_D), .rt_D(rt_D), .rs_E(rs_E), .rt_E(rt_E), 
        .write_reg_E(write_reg_E), .reg_write_E(reg_write_E), .mem_to_reg_E(mem_to_reg_E),
        .write_reg_M(write_reg_M), .reg_write_M(reg_write_M), .mem_to_reg_M(mem_to_reg_M),
        
        // Connect memory transaction lines processed in datapath to top-level wires
        .mem_write_M(mem_write_M),
        .alu_result_M(alu_result_M),
        .write_data_M(write_data_M),
        .read_data_M(read_data_M),
        
        .write_reg_W(write_reg_W), .reg_write_W(reg_write_W),
        .instr_D(instr_D), .pc_out(pc_out), .alu_result_out(alu_result)
    );

    // --- Data Memory ---
    data_memory u_data_mem (
        .clk(clk),
        .rst_n(rst_n),
        .mem_write_en(mem_write_M), 
        .addr(alu_result_M),            
        .write_data(write_data_M),   
        .switches(switches),            
        .pwm_out(pwm_out),           
        .read_data(read_data_M)      
    );

endmodule