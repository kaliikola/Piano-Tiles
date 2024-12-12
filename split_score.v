`timescale 1ns / 1ps

module split_score(
    input [11:0] score,  // 12-bit score input
    output reg [3:0] ones,     // Ones digit
    output reg [3:0] tens,     // Tens digit
    output reg [3:0] hundreds, // Hundreds digit
    output reg [3:0] thousands // Thousands digit
);
    
    always @ (score) begin
        ones     = score % 10;             // Extract ones place
        tens     = (score / 10) % 10;      // Extract tens place
        hundreds = (score / 100) % 10;    // Extract hundreds place
        thousands = (score / 1000) % 10;  // Extract thousands place
    end

endmodule