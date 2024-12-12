`timescale 1ns / 1ps

module piano_tiles (
    input wire clk,
    input wire reset,
    input wire [3:0] btn,       // Active-low buttons
    input wire [1:0] speed,     // Speed input (00 = slow, 01 = medium, 10 = fast)
    output wire [3:0] R,        // VGA Red
    output wire [3:0] G,        // VGA Green
    output wire [3:0] B,        // VGA Blue
    output wire hsync,          // VGA H-Sync
    output wire vsync,          // VGA V-Sync
    output wire [3:0] ones,     // BCD ones digit of the score
    output wire [3:0] tens,     // BCD tens digit of the score
    output wire [3:0] hundreds, // BCD hundreds digit of the score
    output wire [3:0] thousands // BCD thousands digit of the score
);

    // VGA Parameters
    localparam TILE_WIDTH = 160;
    localparam TILE_HEIGHT = 120;
    localparam TARGET_LINE = 360;         // Center of the target line
    localparam TILE_DROP_SPEED_BASE = 32'h70000; // Base drop speed for tiles (slower speed)

    // Score Tracking
    reg [11:0] score; // 12-bit score
    wire [3:0] ones, tens, hundreds, thousands;

    // Instantiate split_score for BCD conversion
    split_score score_splitter (
        .score(score),
        .ones(ones),
        .tens(tens),
        .hundreds(hundreds),
        .thousands(thousands)
    );

 

    // VGA Timing Signals
    reg [9:0] counter_x, counter_y; // Pixel counters
    reg active_area;                // Active display area
    reg hsync_r, vsync_r;

    // VGA Timing Parameters for 640x480 @ 60Hz
    localparam H_DISPLAY = 640;    // Horizontal visible area
    localparam H_FRONT = 16;       // Horizontal front porch
    localparam H_SYNC = 96;        // Horizontal sync pulse
    localparam H_BACK = 48;        // Horizontal back porch
    localparam H_TOTAL = 800;      // Total horizontal pixels

    localparam V_DISPLAY = 480;    // Vertical visible area
    localparam V_FRONT = 10;       // Vertical front porch
    localparam V_SYNC = 2;         // Vertical sync pulse
    localparam V_BACK = 33;        // Vertical back porch
    localparam V_TOTAL = 525;      // Total vertical lines

    // VGA Counters and Active Area Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_x <= 0;
            counter_y <= 0;
        end else if (counter_x == H_TOTAL - 1) begin
            counter_x <= 0;
            if (counter_y == V_TOTAL - 1) begin
                counter_y <= 0;
            end else begin
                counter_y <= counter_y + 1;
            end
        end else begin
            counter_x <= counter_x + 1;
        end
    end

    // Generate H-Sync and V-Sync Signals
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hsync_r <= 1;
            vsync_r <= 1;
            active_area <= 0;
        end else begin
            hsync_r <= ~(counter_x >= (H_DISPLAY + H_FRONT) && counter_x < (H_DISPLAY + H_FRONT + H_SYNC));
            vsync_r <= ~(counter_y >= (V_DISPLAY + V_FRONT) && counter_y < (V_DISPLAY + V_FRONT + V_SYNC));
            active_area <= (counter_x < H_DISPLAY) && (counter_y < V_DISPLAY);
        end
    end

    assign hsync = hsync_r;
    assign vsync = vsync_r;

    // Game Logic Signals
    reg [9:0] tile_y_0, tile_y_1, tile_y_2, tile_y_3; // Y positions of tiles
    reg tile_active_0, tile_active_1, tile_active_2, tile_active_3; // Active flags
    reg [3:0] button_lit; // Tracks whether a button was pressed for a tile
    reg [31:0] tile_timer; // Timer for controlling tile drop speed
    reg [31:0] adjusted_speed; // Adjusted speed based on the speed input
    reg scored_0, scored_1, scored_2, scored_3; // Scored flags for each lane

    // Linear Feedback Shift Register (LFSR) for Randomness
    reg [15:0] lfsr;
    wire lfsr_feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    // Pattern History
    reg [3:0] previous_pattern;  // Keeps track of the last pattern of active tiles
    reg [3:0] new_pattern;       // Temporary register to store the new pattern

    // LFSR for Randomness
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr <= 16'hACE1; // Initial seed
        end else begin
            lfsr <= {lfsr[14:0], lfsr_feedback}; // Shift with feedback
        end
    end

    // Adjust the tile drop speed based on the speed input
    always @(*) begin
        case (speed)
            2'b00: adjusted_speed = TILE_DROP_SPEED_BASE;       // Slow
            2'b01: adjusted_speed = TILE_DROP_SPEED_BASE >> 1;  // Medium
            2'b10: adjusted_speed = TILE_DROP_SPEED_BASE >> 2;  // Fast
            default: adjusted_speed = TILE_DROP_SPEED_BASE;     // Default to Slow
        endcase
    end

    // Movement and Activation Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tile_active_0 <= 0; tile_y_0 <= 0; scored_0 <= 0;
            tile_active_1 <= 0; tile_y_1 <= 0; scored_1 <= 0;
            tile_active_2 <= 0; tile_y_2 <= 0; scored_2 <= 0;
            tile_active_3 <= 0; tile_y_3 <= 0; scored_3 <= 0;
            button_lit <= 4'b0000; // Reset button lit flags
            tile_timer <= 0;
            previous_pattern <= 4'b0000; // Clear pattern history
            score <= 0; // Reset score
        end else begin
            // Increment tile timer
            tile_timer <= tile_timer + 1;

            // Check if it's time to update tile positions
            if (tile_timer >= adjusted_speed) begin
                tile_timer <= 0; // Reset the timer

                // Move active tiles
                if (tile_active_0 && tile_y_0 < 479) tile_y_0 <= tile_y_0 + 1;
                else begin
                    tile_active_0 <= 0;
                    button_lit[0] <= 0; // Clear button lit for lane 0
                    scored_0 <= 0;      // Clear scored flag for lane 0
                end

                if (tile_active_1 && tile_y_1 < 479) tile_y_1 <= tile_y_1 + 1;
                else begin
                    tile_active_1 <= 0;
                    button_lit[1] <= 0; // Clear button lit for lane 1
                    scored_1 <= 0;      // Clear scored flag for lane 1
                end

                if (tile_active_2 && tile_y_2 < 479) tile_y_2 <= tile_y_2 + 1;
                else begin
                    tile_active_2 <= 0;
                    button_lit[2] <= 0; // Clear button lit for lane 2
                    scored_2 <= 0;      // Clear scored flag for lane 2
                end

                if (tile_active_3 && tile_y_3 < 479) tile_y_3 <= tile_y_3 + 1;
                else begin
                    tile_active_3 <= 0;
                    button_lit[3] <= 0; // Clear button lit for lane 3
                    scored_3 <= 0;      // Clear scored flag for lane 3
                end

                // Generate new tiles when no tiles are active
                if (!tile_active_0 && !tile_active_1 && !tile_active_2 && !tile_active_3) begin
                    tile_y_0 <= 0; tile_y_1 <= 0; tile_y_2 <= 0; tile_y_3 <= 0;

                    // Generate a new random pattern with controlled probabilities
                    new_pattern = 4'b0000;
                    case (lfsr[3:0])
                        4'b0000, 4'b0001, 4'b0010, 4'b0011: begin
                            // Generate 1 tile (80% probability)
                            new_pattern = 4'b0001 << lfsr[1:0];
                        end
                        4'b0100, 4'b0101: begin
                            // Generate 2 tiles (15% probability)
                            new_pattern = 4'b0001 << lfsr[1:0];
                            new_pattern = new_pattern | (4'b0001 << (lfsr[3:2] % 4));
                        end
                        4'b0110: begin
                            // Generate 3 tiles (4% probability)
                            new_pattern = 4'b0001 << lfsr[1:0];
                            new_pattern = new_pattern | (4'b0001 << (lfsr[3:2] % 4));
                            new_pattern = new_pattern | (4'b0001 << (lfsr[5:4] % 4));
                        end
                        4'b0111: begin
                            // Generate 4 tiles (1% probability)
                            new_pattern = 4'b1111;
                        end
                    endcase

                    // Update the active states based on the new pattern
                    tile_active_0 <= new_pattern[0];
                    tile_active_1 <= new_pattern[1];
                    tile_active_2 <= new_pattern[2];
                    tile_active_3 <= new_pattern[3];
                end
            end

            // Check button presses for lighting (Halfway through target line)
            if (tile_active_0 && (tile_y_0 + TILE_HEIGHT >= TARGET_LINE + (TILE_HEIGHT / 2)) && !btn[0] && !scored_0) begin
                button_lit[0] <= 1;
                score <= score + 5; // Increment score
                scored_0 <= 1;      // Mark as scored
            end
            if (tile_active_1 && (tile_y_1 + TILE_HEIGHT >= TARGET_LINE + (TILE_HEIGHT / 2)) && !btn[1] && !scored_1) begin
                button_lit[1] <= 1;
                score <= score + 5; // Increment score
                scored_1 <= 1;      // Mark as scored
            end
            if (tile_active_2 && (tile_y_2 + TILE_HEIGHT >= TARGET_LINE + (TILE_HEIGHT / 2)) && !btn[2] && !scored_2) begin
                button_lit[2] <= 1;
                score <= score + 5; // Increment score
                scored_2 <= 1;      // Mark as scored
            end
            if (tile_active_3 && (tile_y_3 + TILE_HEIGHT >= TARGET_LINE + (TILE_HEIGHT / 2)) && !btn[3] && !scored_3) begin
                button_lit[3] <= 1;
                score <= score + 5; // Increment score
                scored_3 <= 1;      // Mark as scored
            end
        end
    end

    // VGA Display Logic
    reg [3:0] red_out, green_out, blue_out;
    always @(*) begin
        // Default to black
        red_out = 4'h0;
        green_out = 4'h0;
        blue_out = 4'h0;

        if (active_area) begin
            // Render the target line
            if (counter_y == TARGET_LINE) begin
                red_out = 4'hF; green_out = 4'h0; blue_out = 4'h0; // Red line
            end

            // Lane 0
            if (tile_active_0 &&
                counter_x >= 0 && counter_x < TILE_WIDTH &&
                counter_y >= tile_y_0 && counter_y < tile_y_0 + TILE_HEIGHT) begin
                if (button_lit[0]) begin
                    red_out = 4'hF; green_out = 4'hF; blue_out = 4'h0; // Yellow
                end else begin
                    red_out = 4'hF; green_out = 4'hF; blue_out = 4'hF; // White
                end
            end

            // Lane 1
            if (tile_active_1 &&
                counter_x >= TILE_WIDTH && counter_x < 2 * TILE_WIDTH &&
                counter_y >= tile_y_1 && counter_y < tile_y_1 + TILE_HEIGHT) begin
                if (button_lit[1]) begin
                    red_out = 4'h0; green_out = 4'h0; blue_out = 4'hF; // Blue
                end else begin
                    red_out = 4'hF; green_out = 4'hF; blue_out = 4'hF; // White
                end
            end

            // Lane 2
            if (tile_active_2 &&
                counter_x >= 2 * TILE_WIDTH && counter_x < 3 * TILE_WIDTH &&
                counter_y >= tile_y_2 && counter_y < tile_y_2 + TILE_HEIGHT) begin
                if (button_lit[2]) begin
                    red_out = 4'h0; green_out = 4'hF; blue_out = 4'h0; // Green
                end else begin
                    red_out = 4'hF; green_out = 4'hF; blue_out = 4'hF; // White
                end
            end

            // Lane 3
            if (tile_active_3 &&
                counter_x >= 3 * TILE_WIDTH && counter_x < 4 * TILE_WIDTH &&
                counter_y >= tile_y_3 && counter_y < tile_y_3 + TILE_HEIGHT) begin
                if (button_lit[3]) begin
                    red_out = 4'hF; green_out = 4'h0; blue_out = 4'h0; // Red
                end else begin
                    red_out = 4'hF; green_out = 4'hF; blue_out = 4'hF; // White
                end
            end
        end
    end

    assign R = red_out;
    assign G = green_out;
    assign B = blue_out;

endmodule
