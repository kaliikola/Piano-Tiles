`timescale 1ns / 1ps

module BCD7seg (
    input [3:0] bcd,
    output reg [7:0] seg
);
    always @(*) begin
        case (bcd)
            4'b0000: seg = 8'b00000011; // 0
            4'b0001: seg = 8'b10011111; // 1
            4'b0010: seg = 8'b00100101; // 2
            4'b0011: seg = 8'b00001101; // 3
            4'b0100: seg = 8'b10011001; // 4
            4'b0101: seg = 8'b01001001; // 5
            4'b0110: seg = 8'b01000001; // 6
            4'b0111: seg = 8'b00011111; // 7
            4'b1000: seg = 8'b00000001; // 8
            4'b1001: seg = 8'b00001001; // 9
            default: seg = 8'b11111111; // Off
        endcase
    end
endmodule
