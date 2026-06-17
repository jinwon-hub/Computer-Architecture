//==============================================================================
// MIPS Processor Testbench
//==============================================================================
`timescale 1ns / 1ps

module mips_tb;
    reg         clk;
    reg         rst_n;
    reg  [7:0]  switches;       // Switch input declaration to be controlled by the testbench
    
    // IO Ports
    wire        pwm_out;
    
    // Debug Monitoring
    wire [31:0] pc_out;
    wire [31:0] alu_result;
    
    // Unit Under Test (UUT)
    mips uut (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),    // Port mapping for connection wires
        .pwm_out(pwm_out),
        .pc_out(pc_out),
        .alu_result(alu_result)
    );
    
    // Clock Generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Trace Generation
    initial begin
        $dumpfile("mips.vcd");
        $dumpvars(0, mips_tb);
    end
    
    // Simulation Control
    initial begin
        // Reset Logic
        rst_n = 0;
        switches = 8'h00;       // Initialize switches to request 0% duty cycle
        #15;
        rst_n = 1;
        
        $display("===========================================");
        $display("   MIPS Option B: Switch Controlled PWM    ");
        $display("===========================================");
        
        // [Test Case 1] Set switches to 25% duty ratio (8'h40 = 64)
        #100;
        switches = 8'h40; 
        $display("TEST STIMULUS: Switches changed to 8'h40 (Duty ~25%%)");

        // [Test Case 2] Set switches to 50% duty ratio (8'h80 = 128)
        #80000;
        switches = 8'h80;
        $display("TEST STIMULUS: Switches changed to 8'h80 (Duty ~50%%)");

        // [Test Case 3] Set switches to 75% duty ratio (8'hC0 = 192)
        #80000;
        switches = 8'hC0;
        $display("TEST STIMULUS: Switches changed to 8'hC0 (Duty ~75%%)");
        
        // Provide sufficient delay to observe output transitions
        #130000;
        
        $display("===========================================");
        $display("   Simulation Complete                     ");
        $display("===========================================");
        $finish;
    end

endmodule