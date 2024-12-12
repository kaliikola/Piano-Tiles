module menu (
    input wire clk,               // Clock signal
    input wire reset,             // Reset signal
    input wire up_btn,            // Debounced UP button (active-low)
    input wire down_btn,          // Debounced DOWN button (active-low)
    input wire select_btn,        // Debounced SELECT button (active-low)
    output reg [1:0] speed,       // Selected speed: 00 = SLOW, 01 = NORMAL, 10 = FAST
    output reg start_game,        // Signal to start the game
    output wire [3:0] R,          // VGA Red
    output wire [3:0] G,          // VGA Green
    output wire [3:0] B,          // VGA Blue
    output wire hsync,            // VGA H-Sync
    output wire vsync             // VGA V-Sync
);

    // VGA Parameters
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam FONT_WIDTH = 16;
    localparam FONT_HEIGHT = 16;
    localparam ROW_SPACING = 16;  // Extra spacing between rows

    // State Definitions
    localparam STATE_OPENING = 0;
    localparam STATE_SELECTION = 1;

    reg [1:0] state;              // Current state
    reg [1:0] menu_option;        // Tracks the selected menu option (0 = SLOW, 1 = NORMAL, 2 = FAST)

    // Blinking Logic
    reg [23:0] blink_counter;     // Counter for blinking
    wire blink_toggle;            // Toggles every ~0.5 seconds

    // Button Edge Detection
    reg up_btn_last, down_btn_last, select_btn_last;
    wire up_released, down_released, select_released;

    // Initialization Delay
    reg [20:0] init_counter;
    reg init_done;

    // VGA Sync Signals
    wire [9:0] counter_x, counter_y;
    wire active_area; // Active display region

    // VGA Sync Module
    vga_sync vga_inst (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .active_area(active_area),
        .counter_x(counter_x),
        .counter_y(counter_y)
    );

    // Text Rendering Signals
    reg [7:0] current_char;
    wire [11:0] text_RGB;
    reg within_text_area;

    // Text Renderer Module
    text_renderer text_inst (
        .clk(clk),
        .x(counter_x % FONT_WIDTH),
        .y(counter_y % FONT_HEIGHT),
        .char(current_char),
        .RGB(text_RGB)
    );

    // Text Definitions
    reg [7:0] TEXT [0:5][0:31];   // Array for up to 32 characters per line
    reg [5:0] TEXT_LENGTH [0:3];  // Length of each text string (supports up to 32)

    initial begin
        // Opening Screen Title: "PIANO TILE GAME"
        TEXT[0][0] = "P"; TEXT[0][1] = "I"; TEXT[0][2] = "A"; TEXT[0][3] = "N"; TEXT[0][4] = "O";
        TEXT[0][5] = " "; TEXT[0][6] = "T"; TEXT[0][7] = "I"; TEXT[0][8] = "L"; TEXT[0][9] = "E";
        TEXT[0][10] = " "; TEXT[0][11] = "G"; TEXT[0][12] = "A"; TEXT[0][13] = "M"; TEXT[0][14] = "E"; TEXT[0][15] = "!"; 
        TEXT_LENGTH[0] = 16;  // Length: 15 characters

        // Instruction Text: "PRESS ANY BUTTON"
        TEXT[1][0] = "P"; TEXT[1][1] = "R"; TEXT[1][2] = "E"; TEXT[1][3] = "S"; TEXT[1][4] = "S";
        TEXT[1][5] = " "; TEXT[1][6] = "A"; TEXT[1][7] = "N"; TEXT[1][8] = "Y"; TEXT[1][9] = " ";
        TEXT[1][10] = "B"; TEXT[1][11] = "U"; TEXT[1][12] = "T"; TEXT[1][13] = "T"; TEXT[1][14] = "O"; TEXT[1][15] = "N";
        TEXT_LENGTH[1] = 16;  // Length: 16 characters

        // Speed Selection Texts
        TEXT[2][0] = "S"; TEXT[2][1] = "L"; TEXT[2][2] = "O"; TEXT[2][3] = "W";
        TEXT_LENGTH[2] = 4;  // Length: 4 characters

        TEXT[3][0] = "N"; TEXT[3][1] = "O"; TEXT[3][2] = "R"; TEXT[3][3] = "M"; TEXT[3][4] = "A"; TEXT[3][5] = "L";
        TEXT_LENGTH[3] = 6;  // Length: 6 characters

        TEXT[4][0] = "F"; TEXT[4][1] = "A"; TEXT[4][2] = "S"; TEXT[4][3] = "T";
        TEXT_LENGTH[4] = 4;  // Length: 4 characters
    end

    // Centering Logic
    function [9:0] calc_center_x;
        input [5:0] length; // Adjusted to handle longer lengths (up to 32)
        begin
            calc_center_x = (SCREEN_WIDTH / 2) - ((length * FONT_WIDTH) / 2);
        end
    endfunction

    // Rendering Logic for a Single Line of Text
    task render_line;
        input [9:0] line_y;         // Vertical position of the line
        input [3:0] text_idx;       // Index of the TEXT array to render
        input flashing;             // Whether the text is flashing
        reg [9:0] start_x;          // Cached horizontal starting position
        integer char_idx;           // Index within the current string
        begin
            start_x = calc_center_x(TEXT_LENGTH[text_idx]);
            if (counter_y >= line_y && counter_y < line_y + FONT_HEIGHT && (!flashing || blink_toggle)) begin
                for (char_idx = 0; char_idx < TEXT_LENGTH[text_idx]; char_idx = char_idx + 1) begin
                    if (counter_x >= start_x + char_idx * FONT_WIDTH &&
                        counter_x < start_x + (char_idx + 1) * FONT_WIDTH) begin
                        current_char = TEXT[text_idx][char_idx];
                        within_text_area = 1;
                    end
                end
            end
        end
    endtask

    // Rendering Logic
    always @(*) begin
        within_text_area = 0;        // Default: Not within a text area
        current_char = 8'h00;        // Default: Blank character

        if (active_area) begin
            if (state == STATE_OPENING) begin
                render_line(192, 0, 0);  // Display "PIANO TILE GAME" (centered near the top)
                render_line(400, 1, 0);  // Move "PRESS ANY BUTTON" closer to the bottom (y = 400)
            end else if (state == STATE_SELECTION) begin
                render_line(192, 2, menu_option == 0);          // Line 1: "SLOW" (flashes if selected)
                render_line(192 + FONT_HEIGHT + ROW_SPACING, 3, menu_option == 1);  // Line 2: "NORMAL"
                render_line(192 + 2 * (FONT_HEIGHT + ROW_SPACING), 4, menu_option == 2); // Line 3: "FAST"
            end
        end
    end

    // Blinking Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            blink_counter <= 0;
        end else begin
            blink_counter <= blink_counter + 1;
        end
    end
    assign blink_toggle = blink_counter[23]; // Toggles every ~0.5 seconds at 50 MHz

    // Initialization Delay Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            init_counter <= 0;
            init_done <= 0;
        end else if (init_counter == 21'h1FFFFF) begin
            init_done <= 1;
        end else begin
            init_counter <= init_counter + 1;
        end
    end

    // Button State Tracking and Edge Detection
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            up_btn_last <= 1;      // Buttons start unpressed (active-low)
            down_btn_last <= 1;
            select_btn_last <= 1;
        end else if (init_done) begin
            up_btn_last <= up_btn;
            down_btn_last <= down_btn;
            select_btn_last <= select_btn;
        end
    end

    assign up_released = (up_btn_last == 0 && up_btn == 1);
    assign down_released = (down_btn_last == 0 && down_btn == 1);
    assign select_released = (select_btn_last == 0 && select_btn == 1);

    // State Management Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_OPENING;
            menu_option <= 0;  // Default to "SLOW"
            start_game <= 0;
        end else if (init_done) begin
            case (state)
                STATE_OPENING: begin
                    if (up_released || down_released || select_released) begin
                        state <= STATE_SELECTION;
                    end
                end
                STATE_SELECTION: begin
                    if (up_released && menu_option > 0) menu_option <= menu_option - 1;
                    if (down_released && menu_option < 2) menu_option <= menu_option + 1;
                    if (select_released) begin
                        start_game <= 1;
                        speed <= menu_option;
                    end
                end
            endcase
        end
    end

    assign {R, G, B} = within_text_area ? text_RGB : 12'h000;

endmodule
