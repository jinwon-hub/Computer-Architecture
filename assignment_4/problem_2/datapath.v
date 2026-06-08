//==============================================================================
// Week 7 & 8: Pipelined Datapath with Early Branch & Global Data Forwarding
//==============================================================================
`timescale 1ns / 1ps

module datapath (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals from Control Unit (decoded in ID stage)
    input  wire        reg_write_D,    // Propagates D -> E -> M -> W
    input  wire        mem_to_reg_D,   // Propagates D -> E -> M -> W
    input  wire        mem_write_D,    // Propagates D -> E -> M
    input  wire [2:0]  alu_ctrl_D,     // Propagates D -> E 
    input  wire        alu_src_D,      // Propagates D -> E 
    input  wire        reg_dst_D,      // Propagates D -> E 
    input  wire        branch_D,       // Consumed in ID (Early Resolution)
    
    // Outputs
    output wire [31:0] instr_D,         
    output wire [31:0] pc_out,          
    output wire [31:0] alu_result_out   
);

    
    //==========================================================================
    // Memory (M) Stage Registers
    reg        reg_write_M, mem_to_reg_M, mem_write_M;
    reg [31:0] alu_result_M, write_data_M;
    reg [4:0]  write_reg_M;

    // Execute (E) Stage Registers & Wires
    reg        reg_write_E;
    wire [31:0] alu_result_E;
    wire [4:0]  write_reg_E;

    //==========================================================================
    // Stage 1: FETCH (F)
    //==========================================================================
    wire [31:0] pc_F, pc_next_F, pc_plus4_F;
    wire [31:0] instr_F;
    wire        pc_src_D;           
    wire [31:0] pc_branch_D;        

    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_next(pc_next_F),
        .pc(pc_F)
    );

    instruction_memory u_imem (
        .addr(pc_F),
        .rd(instr_F)
    );

    assign pc_plus4_F = pc_F + 32'd4;
    assign pc_next_F  = (pc_src_D) ? pc_branch_D : pc_plus4_F;
    assign pc_out     = pc_F;

    //==========================================================================
    // Pipeline Register: IF/ID
    //==========================================================================
    reg [31:0] instr_D_reg, pc_plus4_D;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_D_reg <= 32'b0;
            pc_plus4_D  <= 32'b0;
        end else if (pc_src_D) begin 
            instr_D_reg <= 32'b0;    // Flush 
            pc_plus4_D  <= 32'b0;
        end else begin
            instr_D_reg <= instr_F;
            pc_plus4_D  <= pc_plus4_F;
        end
    end
    assign instr_D = instr_D_reg;

    //==========================================================================
    // Stage 2: DECODE (D)
    //==========================================================================
    wire [31:0] rd1_D, rd2_D;
    wire [31:0] sign_imm_D;
    wire [31:0] result_W;
    wire [4:0]  write_reg_W;
    wire        reg_write_W;

    reg_file u_reg_file (
        .clk(clk),
        .we3(reg_write_W),          
        .ra1(instr_D[25:21]),       // rs
        .ra2(instr_D[20:16]),       // rt
        .wa3(write_reg_W),          
        .wd3(result_W),             
        .rd1(rd1_D),
        .rd2(rd2_D)
    );

    assign sign_imm_D = {{16{instr_D[15]}}, instr_D[15:0]};

    wire [4:0] rs_D = instr_D[25:21]; // $8
    wire [4:0] rt_D = instr_D[20:16]; // $9
    

    wire [31:0] forward_rs_D = (reg_write_M && (write_reg_M != 0) && (write_reg_M == rs_D)) ? alu_result_M :
                               (reg_write_W && (write_reg_W != 0) && (write_reg_W == rs_D)) ? result_W     : rd1_D;

    wire [31:0] forward_rt_D = (reg_write_E && (write_reg_E != 0) && (write_reg_E == rt_D)) ? alu_result_E :
                               (reg_write_W && (write_reg_W != 0) && (write_reg_W == rt_D)) ? result_W     : rd2_D;

  
    assign pc_branch_D = $signed(pc_plus4_D) + $signed({sign_imm_D[29:0], 2'b00});

    wire bne_D = (instr_D[31:26] == 6'b000101); 
    assign pc_src_D = branch_D & (bne_D ? (forward_rs_D != forward_rt_D) : (forward_rs_D == forward_rt_D));

    //==========================================================================
    // Pipeline Register: ID/EX
    //==========================================================================
    reg        mem_to_reg_E, mem_write_E;
    reg        alu_src_E, reg_dst_E;
    reg [2:0]  alu_ctrl_E;
    reg [31:0] rd1_E, rd2_E, sign_imm_E;
    reg [4:0]  rs_E, rt_E, rd_E;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_E  <= 1'b0;
            {mem_to_reg_E, mem_write_E, alu_src_E, reg_dst_E} <= 4'b0;
            alu_ctrl_E <= 3'b0;
            {rd1_E, rd2_E, sign_imm_E} <= 96'b0;
            {rs_E, rt_E, rd_E} <= 15'b0;
        end else begin
            
            reg_write_E  <= (pc_src_D) ? 1'b0 : reg_write_D;
            mem_to_reg_E <= (pc_src_D) ? 1'b0 : mem_to_reg_D;
            mem_write_E  <= (pc_src_D) ? 1'b0 : mem_write_D;
            
            alu_ctrl_E   <= (pc_src_D) ? 3'b0 : alu_ctrl_D;
            alu_src_E    <= (pc_src_D) ? 1'b0 : alu_src_D;
            reg_dst_E    <= (pc_src_D) ? 1'b0 : reg_dst_D;
            
            rd1_E        <= rd1_D;
            rd2_E        <= rd2_D;
            sign_imm_E   <= sign_imm_D;
            
            rs_E         <= instr_D[25:21];
            rt_E         <= instr_D[20:16];
            rd_E         <= instr_D[15:11];
        end
    end

    //==========================================================================
    // Stage 3: EXECUTE (E)
    //==========================================================================
    wire [1:0]  forward_a_E, forward_b_E;
    wire [31:0] src_a_E, rd2_fwd_E;
    wire [31:0] src_b_E;
    wire        zero_E; 
    
    forwarding_unit u_fwd_unit (
        .rs_E(rs_E),
        .rt_E(rt_E),
        .write_reg_M(write_reg_M),
        .reg_write_M(reg_write_M),
        .write_reg_W(write_reg_W),
        .reg_write_W(reg_write_W),
        .forward_a_E(forward_a_E),
        .forward_b_E(forward_b_E)
    );

    // Operand A Selection
    assign src_a_E = (forward_a_E == 2'b10) ? alu_result_M :
                     (forward_a_E == 2'b01) ? result_W     : rd1_E;

    // Operand B Selection - Step 1
    assign rd2_fwd_E = (forward_b_E == 2'b10) ? alu_result_M :
                       (forward_b_E == 2'b01) ? result_W     : rd2_E;

    // Operand B Selection - Step 2 (ALUSrc MUX)
    assign src_b_E = (alu_src_E) ? sign_imm_E : rd2_fwd_E;

    assign write_reg_E = (reg_dst_E) ? rd_E : rt_E;

    
    wire [31:0] alu_result_w;
    alu u_alu (
        .src_a(src_a_E),
        .src_b(src_b_E),
        .alu_ctrl(alu_ctrl_E),
        .result(alu_result_w),
        .zero(zero_E)
    );
    assign alu_result_E = alu_result_w;

    //==========================================================================
    // Pipeline Register: EX/MEM
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_M, mem_to_reg_M, mem_write_M} <= 3'b0;
            {alu_result_M, write_data_M} <= 64'b0;
            write_reg_M <= 5'b0;
        end else begin
            reg_write_M     <= reg_write_E;
            mem_to_reg_M    <= mem_to_reg_E;
            mem_write_M     <= mem_write_E;
            
            alu_result_M    <= alu_result_E;
            write_data_M    <= rd2_fwd_E; 
            write_reg_M     <= write_reg_E;
        end
    end

    //==========================================================================
    // Stage 4: MEMORY (M)
    //==========================================================================
    wire [31:0] read_data_M;

    data_memory u_data_mem (
        .clk(clk),
        .mem_write_en(mem_write_M),
        .addr(alu_result_M),
        .write_data(write_data_M),
        .read_data(read_data_M)
    );

    //==========================================================================
    // Pipeline Register: MEM/WB
    //==========================================================================
    reg        reg_write_W_reg, mem_to_reg_W;
    reg [31:0] read_data_W, alu_result_W;
    reg [4:0]  write_reg_W_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_W_reg, mem_to_reg_W} <= 2'b0;
            {read_data_W, alu_result_W} <= 64'b0;
            write_reg_W_reg <= 5'b0;
        end else begin
            reg_write_W_reg <= reg_write_M;
            mem_to_reg_W    <= mem_to_reg_M;
            read_data_W     <= read_data_M;
            alu_result_W    <= alu_result_M;
            write_reg_W_reg <= write_reg_M;
        end
    end

    //==========================================================================
    // Stage 5: WRITE-BACK (W)
    //==========================================================================
    assign result_W       = (mem_to_reg_W) ? read_data_W : alu_result_W;
    assign reg_write_W    = reg_write_W_reg;
    assign write_reg_W    = write_reg_W_reg;
    assign alu_result_out = result_W;

endmodule