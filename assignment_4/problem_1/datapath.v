//==============================================================================
// Week 7: Pipelined Datapath with Early Branch Resolution
// Distinction: Branch targets/decisions are handled in ID stage, not MEM stage.
// Penalty: Reduced from 3 cycles to 1 cycle.
//==============================================================================
`timescale 1ns / 1ps

module datapath (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals from Control Unit (decoded in ID stage)
    // These signals must be "pipelined" to reach the correct stage at the right time
    input  wire        reg_write_D,    // Propagates D -> E -> M -> W
    input  wire        mem_to_reg_D,   // Propagates D -> E -> M -> W
    input  wire        mem_write_D,    // Propagates D -> E -> M
    input  wire [2:0]  alu_ctrl_D,     // Propagates D -> E (Consumed in EX)
    input  wire        alu_src_D,      // Propagates D -> E (Consumed in EX)
    input  wire        reg_dst_D,      // Propagates D -> E (Consumed in EX)
    input  wire        branch_D,       // Consumed in ID (Early Resolution)
    
    // Outputs
    output wire [31:0] instr_D,         // Feedback to Control Unit for decoding
    output wire [31:0] pc_out,          // Current PC for debugging
    output wire [31:0] alu_result_out   // Write-back result for debugging
);

    //==========================================================================
    // Stage 1: FETCH (F)
    // Instructions are fetched from memory based on the Program Counter (PC)
    //==========================================================================
    wire [31:0] pc_F, pc_next_F, pc_plus4_F;
    wire [31:0] instr_F;
    wire        pc_src_D;           // Branch decision (Calculated in ID stage)
    wire [31:0] pc_branch_D;        // Branch target address (Calculated in ID stage)

    // PC Register: Updates the fetch address every clock cycle
    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .pc_next(pc_next_F),
        .pc(pc_F)
    );

    // Instruction Memory: Async read based on PC
    instruction_memory u_imem (
        .addr(pc_F),
        .rd(instr_F)
    );

    // PC Logic: Choose between sequential (PC+4) or branch target
    assign pc_plus4_F = pc_F + 32'd4;
    assign pc_next_F  = (pc_src_D) ? pc_branch_D : pc_plus4_F;
    assign pc_out = pc_F;

    //==========================================================================
    // Pipeline Register: IF/ID (Fetch to Decode)
    // Synchronizes the fetched instruction with the Decode stage
    //==========================================================================
    reg [31:0] instr_D_reg, pc_plus4_D;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_D_reg <= 32'b0;
            pc_plus4_D  <= 32'b0;
        end else begin
            if (pc_src_D) begin
                // 분기가 성공(Taken)했으므로 잘못 들고 온 다음 명령어는 NOP(0)로 지워버림 (Flush)
                instr_D_reg <= 32'b0; 
                pc_plus4_D  <= 32'b0;
            end else begin
                instr_D_reg <= instr_F;
                pc_plus4_D  <= pc_plus4_F;
            end
        end
    end
    assign instr_D = instr_D_reg;

    //==========================================================================
    // Stage 2: DECODE (D)
    // Instruction is decoded; registers are read; immediate is extended
    //==========================================================================
    wire [31:0] rd1_D, rd2_D;
    wire [31:0] sign_imm_D;

    // Signals returning from the Write-back (W) stage
    wire [31:0] result_W;
    wire [4:0]  write_reg_W;
    wire        reg_write_W;

    // Register File: Dual-read (rs/rt), Single-write (from WB stage)
    reg_file u_reg_file (
        .clk(clk),
        .we3(reg_write_W),          // Synchronized write enable from WB
        .ra1(instr_D[25:21]),       // rs
        .ra2(instr_D[20:16]),       // rt
        .wa3(write_reg_W),          // Synchronized destination reg from WB
        .wd3(result_W),             // Data calculated in previous cycles
        .rd1(rd1_D),
        .rd2(rd2_D)
    );

    // Sign Extension for I-type instructions
    assign sign_imm_D = {{16{instr_D[15]}}, instr_D[15:0]};

    // Early Branch Resolution: Target calculation & Comparison
    assign pc_branch_D = pc_plus4_D + (sign_imm_D << 2);
    wire bne_D = (instr_D[31:26] == 6'b000101); // bne의 Opcode 감지
    assign pc_src_D = branch_D & (bne_D ? ~(rd1_D == rd2_D) : (rd1_D == rd2_D));

    //==========================================================================
    // Pipeline Register: ID/EX (Decode to Execute)
    // Propagates signals needed for EX, MEM, and WB stages
    //==========================================================================
    reg        reg_write_E, mem_to_reg_E, mem_write_E;
    reg        alu_src_E, reg_dst_E;
    reg [2:0]  alu_ctrl_E;
    reg [31:0] rd1_E, rd2_E, sign_imm_E;
    reg [4:0]  rs_E, rt_E, rd_E;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_E, mem_to_reg_E, mem_write_E, alu_src_E, reg_dst_E} <= 5'b0;
            alu_ctrl_E <= 3'b0;
            {rd1_E, rd2_E, sign_imm_E} <= 96'b0;
            {rs_E, rt_E, rd_E} <= 15'b0;
        end else begin
            // 1. Control Signals: Moving with the instruction
            reg_write_E  <= reg_write_D;
            mem_to_reg_E <= mem_to_reg_D;
            mem_write_E  <= mem_write_D;
            alu_ctrl_E   <= alu_ctrl_D;
            alu_src_E    <= alu_src_D;
            reg_dst_E    <= reg_dst_D;
            
            // 2. Data Signals: Moving with the instruction
            rd1_E        <= rd1_D;
            rd2_E        <= rd2_D;
            sign_imm_E   <= sign_imm_D;
            
            // 3. Register info: Needed for hazards (Week 8)
            rs_E         <= instr_D[25:21];
            rt_E         <= instr_D[20:16];
            rd_E         <= instr_D[15:11];
        end
    end

    //==========================================================================
    // Stage 3: EXECUTE (E)
    // ALU operations and ALU-related multiplexing
    //==========================================================================
    wire [31:0] src_b_E;
    wire [31:0] alu_result_E;
    wire [4:0]  write_reg_E;
    wire        zero_E; // Not used for branching anymore

    // ALU Source MUX: Selects between register data (rt) and immediate
    // [CONSUMED HERE]: alu_src_E
    assign src_b_E = (alu_src_E) ? sign_imm_E : rd2_E;

    // Write Register MUX: Selects destination rt (I-type) or rd (R-type)
    // [CONSUMED HERE]: reg_dst_E
    assign write_reg_E = (reg_dst_E) ? rd_E : rt_E;

    // ALU Core: Performs arithmetic/logic operations
    // [CONSUMED HERE]: alu_ctrl_E
    alu u_alu (
        .src_a(rd1_E),
        .src_b(src_b_E),
        .alu_ctrl(alu_ctrl_E),
        .result(alu_result_E),
        .zero(zero_E)
    );

    //==========================================================================
    // Pipeline Register: EX/MEM (Execute to Memory)
    // Propagates signals needed for MEM and WB stages
    //==========================================================================
    reg        reg_write_M, mem_to_reg_M, mem_write_M;
    reg [31:0] alu_result_M, write_data_M;
    reg [4:0]  write_reg_M;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {reg_write_M, mem_to_reg_M, mem_write_M} <= 3'b0;
            {alu_result_M, write_data_M} <= 64'b0;
            write_reg_M <= 5'b0;
        end else begin
            // Propagating control signals for Memory and Write-back
            reg_write_M     <= reg_write_E;
            mem_to_reg_M    <= mem_to_reg_E;
            mem_write_M     <= mem_write_E;
            
            // Propagating results and data
            alu_result_M    <= alu_result_E;
            write_data_M    <= rd2_E;
            write_reg_M     <= write_reg_E;
        end
    end

    //==========================================================================
    // Stage 4: MEMORY (M)
    // Data memory access
    //==========================================================================
    wire [31:0] read_data_M;

    // Data Memory: Read/Write access
    // [CONSUMED HERE]: mem_write_M
    data_memory u_data_mem (
        .clk(clk),
        .mem_write_en(mem_write_M),
        .addr(alu_result_M),
        .write_data(write_data_M),
        .read_data(read_data_M)
    );

    //==========================================================================
    // Pipeline Register: MEM/WB (Memory to Write-Back)
    // Final propagation to ensure data reaches the Register File synchronized
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
            // Final signals for the Write-back stage
            reg_write_W_reg <= reg_write_M;
            mem_to_reg_W    <= mem_to_reg_M;
            
            // Carrying results to the end
            read_data_W     <= read_data_M;
            alu_result_W    <= alu_result_M;
            write_reg_W_reg <= write_reg_M;
        end
    end

    //==========================================================================
    // Stage 5: WRITE-BACK (W)
    // Selection of final result and writing back to Register File
    //==========================================================================
    
    // Write-back MUX: Selects ALU out or Data Memory out
    // [CONSUMED HERE]: mem_to_reg_W
    assign result_W    = (mem_to_reg_W) ? read_data_W : alu_result_W;
    
    // Outputs for the synchronzed write to RegFile (back in ID stage)
    assign reg_write_W = reg_write_W_reg;
    assign write_reg_W = write_reg_W_reg;

    // Final result output for debugging purposes
    // Final result output for debugging purposes
    // [수정] 실제로 레지스터 파일에 값을 쓸 때(reg_write_W가 1일 때)만 값을 보여주고, 아니면 0으로 클리어!
    assign alu_result_out = (reg_write_W) ? result_W : 32'b0;
endmodule
