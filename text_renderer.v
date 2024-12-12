module text_renderer (
    input wire clk,               // Clock signal
    input wire [9:0] x,           // X coordinate within the character cell
    input wire [9:0] y,           // Y coordinate within the character cell
    input wire [7:0] char,        // ASCII character to render
    output reg [11:0] RGB         // Pixel color output (12-bit RGB)
);

    parameter FONT_WIDTH = 16;            // Width of each character in pixels
    parameter FONT_HEIGHT = 16;           // Height of each character in pixels
    parameter FOREGROUND_COLOR = 12'hFFF; // White text
    parameter BACKGROUND_COLOR = 12'h000; // Black background

    wire [3:0] row = y[3:0];              // Current row in the character cell (0-15)
    wire [15:0] pixels;                   // Pixel data for the current row (16 pixels wide)

    // Font ROM instantiation for 16x16 fonts
    font_rom font (
        .char(char),                      // ASCII character to fetch
        .row(row),                        // Row index (0-15)
        .pixels(pixels)                   // Output row of pixel data
    );

    // Render pixel color based on font data
    always @(*) begin
        if (x < FONT_WIDTH && y < FONT_HEIGHT) begin
            if (pixels[15 - x]) begin
                RGB = FOREGROUND_COLOR;   // Foreground color for text
            end else begin
                RGB = BACKGROUND_COLOR;   // Background color
            end
        end else begin
            RGB = BACKGROUND_COLOR;       // Background color for out-of-bounds pixels
        end
    end
endmodule
