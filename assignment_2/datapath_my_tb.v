`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Datapath Testbench
// 
// This testbench manually provides control signals to verify the datapath
// behavior. In a complete CPU, these signals would come from the control unit.
//
// Test Program (memfile.dat):
//   20080005 - addi $t0, $zero, 5    → $t0 = 5
//   2009000A - addi $t1, $zero, 10   → $t1 = 10
//   01095020 - add  $t2, $t0, $t1    → $t2 = 5 + 10 = 15
//   AC0A0004 - sw   $t2, 4($zero)    → Mem[4] = $t2
//-----------------------------------------------------------------------------

module datapath_my_tb;

    //-------------------------------------------------------------------------
    // Signal Declarations
    //-------------------------------------------------------------------------
    
    // Clock and Reset
    reg clk;                    // System clock
    reg rst_n;                  // Active-low reset
    
    // Control Signals (manually provided in this testbench)
    reg reg_write_en;           // Enable write to register file
    reg reg_dst;                // Destination register select: 0=rt, 1=rd
    reg alu_src;                // ALU source B select: 0=register, 1=immediate
    reg [2:0] alu_ctrl;         // ALU operation: 010=ADD, 110=SUB, etc.
    reg mem_write_en;           // Enable write to data memory
    reg mem_to_reg;             // Write-back source: 0=ALU result, 1=memory data
    
    // Output Signals
    wire [31:0] pc_out;         // Current program counter value
    wire [31:0] alu_result;     // ALU computation result

    //-------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    //-------------------------------------------------------------------------
    datapath_my uut (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write_en(reg_write_en),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .alu_ctrl(alu_ctrl),
        .mem_write_en(mem_write_en),
        .mem_to_reg(mem_to_reg),
        .pc_out(pc_out),
        .alu_result(alu_result)
    );

    //-------------------------------------------------------------------------
    // Clock Generation: 10ns period (100MHz)
    //-------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Toggle every 5ns → 10ns period
    end

    //-------------------------------------------------------------------------
    // Waveform Dump for GTKWave
    //-------------------------------------------------------------------------
    initial begin
        $dumpfile("datapath_my.vcd");
        $dumpvars(0, datapath_my_tb);
    end

    //-------------------------------------------------------------------------
    // Test Sequence
    //-------------------------------------------------------------------------
    initial begin
        //---------------------------------------------------------------------
        // Initialize: Reset all signals
        //---------------------------------------------------------------------
        rst_n = 0;                          // Assert reset (active-low)
        reg_write_en = 0; 
        reg_dst = 0; 
        alu_src = 0; 
        alu_ctrl = 0; 
        mem_write_en = 0; 
        mem_to_reg = 0;
        #10;                                // Wait 10ns
        rst_n = 1;                          // Release reset
        $display("--- Start Simulation ---");

        //---------------------------------------------------------------------
        // Instruction 1: addi (I-Type)
        // Instruction: addi $t0, $zero, 7   →  $t0 = 7
        // Control: reg_write=1, alu_src=1(immediate), alu_ctrl=ADD, reg_dst=0(rt)
        // Expected: $t0 = 0 + 7 = 7
        //---------------------------------------------------------------------
        reg_write_en = 1;                   // Enable register write
        alu_src = 1;                        // ALU source B = sign-extended immediate
        alu_ctrl = 3'b000;                  // ALU operation = ADD
        reg_dst = 0;                        // Destination = rt (I-Type)
        mem_write_en = 0;                   // No memory write
        #2; 
        $display("PC: %h | Result: %d (Expected 7)", pc_out, alu_result);
        @(posedge clk);                     // Wait for clock edge
        
        //---------------------------------------------------------------------
        // Instruction 2: addi (I-Type)  
        // Instruction: addi $t1, $zero, 3   →  $t1 = 3
        // Expected: $t1 = 0 + 3 = 3
        //---------------------------------------------------------------------
        #1; 
        reg_write_en = 1;
        alu_src = 1;
        alu_ctrl = 3'b000;
        reg_dst = 0;
        mem_write_en = 0;
        #2;
        $display("PC: %h | Result: %d (Expected 3)", pc_out, alu_result);
        @(posedge clk);
        
        //---------------------------------------------------------------------
        // Instruction 3: sub (R-Type)
        // Instruction: sub  $t2, $t0, $t1   →  $t2 = 7 - 3 = 4
        // Control: reg_write=1, alu_src=0(register), alu_ctrl=sub, reg_dst=1(rd)
        // Expected: $t2 = $t0 + $t1 = 7 - 3 = 4
        //---------------------------------------------------------------------
        #1;
        reg_write_en = 1;
        alu_src = 0;                        // ALU source B = register (rd2)
        alu_ctrl = 3'b001;                  // ALU operation = sub
        reg_dst = 1;                        // Destination = rd (R-Type)
        mem_write_en = 0;
        #2;
        $display("PC: %h | Result: %d (Expected 4)", pc_out, alu_result);
        @(posedge clk);
        
        
        //---------------------------------------------------------------------
        // End Simulation
        //---------------------------------------------------------------------
        #20;
        $finish;
    end

endmodule