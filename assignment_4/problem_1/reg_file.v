`timescale 1ns / 1ps
module reg_file (
    input  wire        clk,        // clock
    input  wire        we3,        // write enable
    input  wire [4:0]  wa3,        // write address
    input  wire [31:0] wd3,        // write data
    input  wire [4:0]  ra1,        // read address 1
    input  wire [4:0]  ra2,        // read address 2
    output wire [31:0] rd1,        // read data 1
    output wire [31:0] rd2         // read data 2
);
    reg [31:0] rf [31:0];          // 32 registers x 32 bits
    
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (we3 && (wa3 != 5'd0))  // write if enabled, skip $0
            rf[wa3] <= wd3;        // write to register
    end
    
    // If we are reading and writing to the same register in the same cycle,
    // return the NEW data (wd3) instead of the OLD data (rf[ra]).
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : 
                 ((ra1 == wa3) && we3) ? wd3 : rf[ra1];
    
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : 
                 ((ra2 == wa3) && we3) ? wd3 : rf[ra2];
endmodule