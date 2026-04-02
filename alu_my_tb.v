`timescale 1ns / 1ps
module alu_my_tb;
    reg  [31:0] src_a, src_b;     // test inputs
    reg  [2:0]  alu_ctrl;         // operation select
    wire [31:0] result;           // ALU output
    wire        zero;             // zero flag
    
    alu_my uut (                     // unit under test
        .A(src_a),
        .B(src_b),
        .alu_oper(alu_ctrl),
        .result(result),
        .zero(zero)
    );
    
    initial begin
        $dumpfile("alu_my.vcd");     // waveform file
        $dumpvars(0, alu_my_tb);
    end
    
    initial begin
        $display("=== ALU Testbench ===");
        
        // Test ADD
        src_a = 30; src_b = 30; alu_ctrl = 3'b000;
        #10;
        if (result !== 60) $error("ADD Failed");
        else $display("ADD: %d + %d = %d [PASS]", src_a, src_b, result);
        
        // Test SUB with zero flag
        src_a = 10; src_b = 5; alu_ctrl = 3'b001;
        #10;
        if (result !== 5 || zero !== 0) $error("SUB/Zero Failed");
        else $display("SUB: %d - %d = %d, Zero=%b [PASS]", src_a, src_b, result, zero);
        
        // Test multiplier
        src_a = 10; src_b = 3; alu_ctrl = 3'b011;
        #10;
        if (result !== 30) $error("Multiple Failed");
        else $display("Multi: %d * %d = %d [PASS]", src_a, src_b, result);

        // Test divide
        src_a = 10; src_b = 2; alu_ctrl = 3'b010;
        #10;
        if (result !== 5) $error("Divide Failed");
        else $display("Divide: %d / %d = %d [PASS]", src_a, src_b, result);

        // Test AND
        src_a = 32'hFF00; src_b = 32'h0FF0; alu_ctrl = 3'b100;
        #10;
        if (result !== 32'h0F00) $error("AND Failed");
        else $display("AND: 0x%h & 0x%h = 0x%h [PASS]", src_a, src_b, result);
        
        // Test OR
        src_a = 32'hFF00; src_b = 32'h00FF; alu_ctrl = 3'b110;
        #10;
        if (result !== 32'hFFFF) $error("OR Failed");
        else $display("OR: 0x%h | 0x%h = 0x%h [PASS]", src_a, src_b, result);
               
        $display("=== All Tests Passed ===");
        $finish;
    end
endmodule