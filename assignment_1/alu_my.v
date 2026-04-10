// goal : Homework: Finish the ALU by using +, -, %, *, AND, OR  by yourself 

`timescale 1ns /1ps
module alu_my (
    input wire [31:0] A,  //input A
    input wire [31:0] B, //input B
    input wire [2:0] alu_oper, //operater select
    output reg [31:0] result, //result
    output wire zero  //zero flag
);
    always @(*) begin
        case (alu_oper)
            3'b000: result = A + B; //add
            3'b001: result = A - B; //sub
            3'b010: result = A / B; //divide
            3'b011: result = A * B; //Multiplier
            3'b100: result = A & B; //AND
            3'b110: result = A | B; //OR
            default: result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0);
endmodule
