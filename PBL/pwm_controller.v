`timescale 1ns / 1ps
module pwm_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [7:0]  duty_cycle,    // 0-255 = 0-100%
    output reg         pwm_out
);
    // Simulation-Optimized PWM: 8-bit counter
    // At 50MHz (20ns), period = 1024 * 20ns = 20.48 microseconds.
    // This makes it VERY fast to simulate while keeping 8-bit resolution.
    reg [9:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 10'b0;
        end else if (enable) begin
            counter <= counter + 1; // Wraps at 1024
        end else begin
            counter <= 10'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 0;
        else if (enable)
            pwm_out <= (counter[9:2] < duty_cycle);
        else
            pwm_out <= 0;
    end
endmodule