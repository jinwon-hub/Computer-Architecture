//==============================================================================
// 5-Stage MIPS Pipelined Datapath
//==============================================================================
`timescale 1ns / 1ps

module datapath (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals passed from Decode stage
    input  wire        reg_write_D, mem_to_reg_D, mem_write_D,
    input  wire [2:0]  alu_ctrl_D,
    input  wire        alu_src_D, reg_dst_D, branch_D, jump_D,
    
    // Hazard control signals
    input  wire        stall_F, stall_D, flush_E,
    input  wire [1:0]  forward_a_E, forward_b_E,
    input  wire [1:0]  forward_a_D, forward_b_D,
    
    // Hazard Unit feedback inputs
    output wire [4:0]  rs_D, rt_D, rs_E, rt_E,      
    output wire [4:0]  write_reg_E,
    output wire        reg_write_E,
    output wire [4:0]  write_reg_M, write_reg_W,
    output wire        reg_write_M, reg_write_W,
    output wire        mem_to_reg_E, mem_to_reg_M,    

    // External memory communication bus ports exposed to mips.v top-level board
    output wire        mem_write_M,       // MEM stage write control enable signal
    output wire [31:0] alu_result_M,      // MEM stage memory address bus
    output wire [31:0] write_data_M,      // MEM stage memory write data bus
    input  wire [31:0] read_data_M,       // Input bus for data loaded from external memory

    // Debug and monitoring output pins
    output wire [31:0] instr_D,
    output wire [31:0] pc_out,
    output wire [31:0] alu_result_out
);

    // -------------------------------------------------------------------------
    // Feedback wire declared at the top to prevent forward references
    // -------------------------------------------------------------------------
    wire [31:0] alu_result_M_wire; 

    // --- STAGE 1: FETCH (IF) ---
    wire [31:0] pc_F, pc_next_F, pc_plus4_F, instr_F;
    wire [31:0] pc_branch_D;
    wire        pc_src_D;
    
    pc u_pc (.clk(clk), .rst_n(rst_n), .en(~stall_F), .pc_next(pc_next_F), .pc(pc_F));
    instruction_memory u_imem (.addr(pc_F), .rd(instr_F));
    assign pc_plus4_F = pc_F + 32'd4;
    
    assign pc_next_F  = (pc_src_D) ? pc_branch_D : 
                        (jump_D)   ? {pc_plus4_D[31:28], instr_D[25:0], 2'b00} : 
                        pc_plus4_F;
    assign pc_out = pc_F;

    // --- IF/ID Pipeline Registers ---
    reg [31:0] instr_D_reg, pc_plus4_D;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            instr_D_reg <= 0; pc_plus4_D <= 0; 
        end else if (!stall_D) begin
            instr_D_reg <= instr_F; 
            pc_plus4_D <= pc_plus4_F; 
        end
    end
    assign instr_D = instr_D_reg;

    // --- STAGE 2: DECODE (ID) ---
    wire [31:0] rd1_D, rd2_D, sign_imm_D, result_W;
    wire [4:0]  write_reg_W_wire;
    wire        reg_write_W_wire;
    
    reg_file u_reg_file (
        .clk(~clk), .we3(reg_write_W_wire), 
        .ra1(instr_D[25:21]), .ra2(instr_D[20:16]), 
        .wa3(write_reg_W_wire), .wd3(result_W), 
        .rd1(rd1_D), .rd2(rd2_D)
    );
    
    assign sign_imm_D = {{16{instr_D[15]}}, instr_D[15:0]};
    assign rs_D = instr_D[25:21];
    assign rt_D = instr_D[20:16];

    // Branch resolution logic (Supports BEQ and BNE)
    wire [31:0] src_a_D, src_b_D;
    wire        equal_D, bne_D;
    assign src_a_D = (forward_a_D == 2'b10) ? alu_result_M_wire : 
                     (forward_a_D == 2'b01) ? result_W : rd1_D;
    assign src_b_D = (forward_b_D == 2'b10) ? alu_result_M_wire : 
                     (forward_b_D == 2'b01) ? result_W : rd2_D;
    assign pc_branch_D = pc_plus4_D + (sign_imm_D << 2);
    assign equal_D = (src_a_D == src_b_D);
    assign bne_D = (instr_D[31:26] == 6'b000101); // BNE opcode detection
    assign pc_src_D = branch_D & (bne_D ? ~equal_D : equal_D);

    // --- ID/EX Pipeline Registers ---
    reg        reg_write_E_reg, mem_to_reg_E_reg, mem_write_E, alu_src_E, reg_dst_E;
    reg [2:0]  alu_ctrl_E;
    reg [31:0] rd1_E, rd2_E, sign_imm_E;
    reg [4:0]  rs_E_reg, rt_E_reg, rd_E;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_E) begin
            {reg_write_E_reg, mem_to_reg_E_reg, mem_write_E, alu_src_E, reg_dst_E} <= 0;
            alu_ctrl_E <= 0; {rd1_E, rd2_E, sign_imm_E} <= 0; {rs_E_reg, rt_E_reg, rd_E} <= 0;
        end else begin
            reg_write_E_reg <= reg_write_D; mem_to_reg_E_reg <= mem_to_reg_D; mem_write_E <= mem_write_D;
            alu_ctrl_E <= alu_ctrl_D; alu_src_E <= alu_src_D; reg_dst_E <= reg_dst_D;
            rd1_E <= rd1_D; rd2_E <= rd2_D; sign_imm_E <= sign_imm_D;
            rs_E_reg <= rs_D; rt_E_reg <= rt_D; rd_E <= instr_D[15:11];
        end
    end
    
    // --- STAGE 3: EXECUTE (EX) ---
    assign rs_E = rs_E_reg; assign rt_E = rt_E_reg;
    assign mem_to_reg_E = mem_to_reg_E_reg; assign reg_write_E = reg_write_E_reg;
    
    wire [31:0] src_a_E_final, src_b_E_temp, src_b_E_final, alu_result_E; 
    wire [4:0]  write_reg_E_wire;
    wire        zero_E;
    
    assign src_a_E_final = (forward_a_E == 2'b10) ? alu_result_M_wire :
                           (forward_a_E == 2'b01) ? result_W : rd1_E;
    assign src_b_E_temp  = (forward_b_E == 2'b10) ? alu_result_M_wire :
                           (forward_b_E == 2'b01) ? result_W : rd2_E;
    assign src_b_E_final = (alu_src_E) ? sign_imm_E : src_b_E_temp;
    assign write_reg_E_wire = (reg_dst_E) ? rd_E : rt_E;
    assign write_reg_E = write_reg_E_wire; 
    
    alu u_alu (.src_a(src_a_E_final), .src_b(src_b_E_final), .alu_ctrl(alu_ctrl_E), .result(alu_result_E), .zero(zero_E));

    // --- EX/MEM Pipeline Registers ---
    reg        reg_write_M_reg, mem_to_reg_M_reg, mem_write_M_reg;
    reg [31:0] alu_result_M_reg, write_data_M_reg;
    reg [4:0]  write_reg_M_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_M_reg, mem_to_reg_M_reg, mem_write_M_reg} <= 0;
            {alu_result_M_reg, write_data_M_reg} <= 0; write_reg_M_reg <= 0;
        end else begin
            reg_write_M_reg <= reg_write_E_reg; mem_to_reg_M_reg <= mem_to_reg_E_reg; mem_write_M_reg <= mem_write_E;
            alu_result_M_reg <= alu_result_E; write_data_M_reg <= src_b_E_temp; 
            write_reg_M_reg <= write_reg_E_wire; 
        end
    end
    
    // --- STAGE 4: MEMORY (MEM) ---
    assign alu_result_M_wire = alu_result_M_reg; 
    assign write_reg_M = write_reg_M_reg; assign reg_write_M = reg_write_M_reg;
    assign mem_to_reg_M = mem_to_reg_M_reg; 
    
    assign mem_write_M  = mem_write_M_reg;
    assign alu_result_M = alu_result_M_reg;
    assign write_data_M = write_data_M_reg;
    

    // --- MEM/WB Pipeline Registers ---
    reg        reg_write_W_reg, mem_to_reg_W;
    reg [31:0] read_data_W, alu_result_W;
    reg [4:0]  write_reg_W_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_W_reg, mem_to_reg_W} <= 0; {read_data_W, alu_result_W} <= 0; write_reg_W_reg <= 0;
        end else begin
            reg_write_W_reg <= reg_write_M_reg; mem_to_reg_W <= mem_to_reg_M_reg;
            read_data_W <= read_data_M; alu_result_W <= alu_result_M_reg; write_reg_W_reg <= write_reg_M_reg;
        end
    end
    
    // --- STAGE 5: WRITEBACK (WB) ---
    assign write_reg_W = write_reg_W_reg; assign reg_write_W = reg_write_W_reg;
    assign result_W = (mem_to_reg_W) ? read_data_W : alu_result_W;
    assign reg_write_W_wire = reg_write_W_reg;
    assign write_reg_W_wire = write_reg_W_reg;
    assign alu_result_out = result_W;
endmodule