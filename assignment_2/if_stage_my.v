
`timescale 1ns / 1ps
module if_stage_my (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] instr,        // fetched instruction
    output wire [31:0] current_pc    // current PC value
);
    wire [31:0] pc;
    wire [31:0] pc_next;
    
    pc_my u_pc ( 
        .clk(clk),
        .rst_n(rst_n),
        .pc_next(pc_next),
        .pc(pc)
    );
    
    assign pc_next = pc + 32'd4;    
    
    instruction_memory_my u_imem ( 
        .addr(pc),
        .rd(instr)
    );
    
    assign current_pc = pc;          // debug output
endmodule