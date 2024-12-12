`timescale 1ns / 1ps

module multiplexer(
    input clk,                  // Input clock
    input [3:0] ones,           // Ones digit (from score_splitter)
    input [3:0] tens,           // Tens digit (from score_splitter)
    input [3:0] hundreds,       // Hundreds digit (from score_splitter)
    input [3:0] thousands,      // Thousands digit (from score_splitter)
    output reg [7:0] seg,       // 7-segment display output (a-g + dp)
    output reg [7:0] an         // Anode control for 4 displays
);

    reg [1:0] current_digit;    // 2-bit counter for 4 digits
    reg [24:0] counter;         // Counter for timing
    reg [3:0] selected_digit;   // Current digit to be displayed
    wire [7:0] seg_decoder;     // Wire for the segment output from decoder

    // Instantiate the BCD to 7-segment decoder
    BCD7seg bcd_decoder (
        .bcd(selected_digit), 
        .seg(seg_decoder)
    );

    // Timing and multiplexing control
    always @(posedge clk) begin
        counter <= counter + 1;
        
        // Generate a clock for multiplexing (5kHz for a smooth display update)
        if (counter == 24_999) begin // Count to 25 million (100 MHz / 5 kHz - 1)
            current_digit <= current_digit + 1;
            if (current_digit == 2'b11) begin
                current_digit <= 2'b00; // Reset after 4 counts
            end
            counter <= 0; // Reset counter
        end
    end

    // Assign the appropriate digit to the current multiplexed display
    always @(*) begin
        case (current_digit)
            2'b00: begin
                selected_digit = ones;  // Ones place
                an = 4'b1110;            // Enable first display
            end
            2'b01: begin
                selected_digit = tens;  // Tens place
                an = 4'b1101;            // Enable second display
            end
            2'b10: begin
                selected_digit = hundreds; // Hundreds place
                an = 4'b1011;            // Enable third display
            end
            2'b11: begin
                selected_digit = thousands; // Thousands place
                an = 4'b0111;             // Enable fourth display
            end
            default: begin
                selected_digit = 4'b0000; // Default case (should not occur)
                an = 4'b1111;             // Disable all
            end
        endcase
        an[7:4] = 4'b1111;
    end

    // Assign the output to the 7-segment display decoder
    always @(*) begin
        seg = seg_decoder; // Output the correct 7-segment display value
    end
endmodule
