`timescale 1ns / 1ps

module top (
    input wire clk,               // Clock signal
    input wire reset,             // Reset signal
    input wire [6:0] noisy_btns,  // Raw noisy button inputs (active low)
    output wire [3:0] R,          // VGA Red
    output wire [3:0] G,          // VGA Green
    output wire [3:0] B,          // VGA Blue
    output wire hsync,            // VGA H-Sync
    output wire vsync,            // VGA V-Sync
    output wire [7:0] seg,        // 7-segment display segments
    output wire [7:0] an,          // 7-segment display anodes 
    output reg [2:0] rgb_led   // RGB LED output

);


    reg [24:0] flash_counter = 0;
    wire flash_toggle = flash_counter[24];
    reg [1:0] button_index = 0;
    reg [2:0] num_buttons_pressed;
    // Debounced button signals
    wire [6:0] clean_btns;
    wire [3:0] clean_game_btns = clean_btns[3:0]; // Debounced buttons for `piano_tiles`
    wire clean_up_btn = clean_btns[4];            // Debounced UP button for `menu`
    wire clean_down_btn = clean_btns[5];          // Debounced DOWN button for `menu`
    wire clean_select_btn = clean_btns[6];        // Debounced SELECT button for `menu`

    // Signals from the menu module
    wire [1:0] speed;            // Selected speed from the menu: 00 = SLOW, 01 = NORMAL, 10 = FAST
    wire start_game;             // Signal to start the piano tiles game

    // Signals for VGA outputs from menu and game modules
    wire [3:0] menu_R, menu_G, menu_B;
    wire [3:0] game_R, game_G, game_B;
    wire menu_hsync, menu_vsync;
    wire game_hsync, game_vsync;

    // 7-segment display BCD outputs from piano_tiles
    wire [3:0] ones, tens, hundreds, thousands;

    // Instantiate the button handler for debouncing
    button_handler btn_handler (
        .clk(clk),
        .reset(reset),
        .noisy_btns(noisy_btns),  // Pass all noisy button inputs
        .clean_btns(clean_btns)   // Get all debounced button outputs
    );

    // Instantiate the menu module
    menu menu_inst (
        .clk(clk),
        .reset(reset),
        .up_btn(clean_up_btn),         // Pass debounced UP button
        .down_btn(clean_down_btn),     // Pass debounced DOWN button
        .select_btn(clean_select_btn), // Pass debounced SELECT button
        .speed(speed),
        .start_game(start_game),
        .R(menu_R),
        .G(menu_G),
        .B(menu_B),
        .hsync(menu_hsync),
        .vsync(menu_vsync)
    );

    // Instantiate the piano tiles game module
    piano_tiles game_inst (
        .clk(clk),
        .reset(reset),
        .btn(clean_game_btns),   // Pass debounced game buttons
        .speed(speed),           // Pass the selected speed from the menu
        .R(game_R),
        .G(game_G),
        .B(game_B),
        .hsync(game_hsync),
        .vsync(game_vsync),
        .ones(ones),             // BCD ones digit of the score
        .tens(tens),             // BCD tens digit of the score
        .hundreds(hundreds),     // BCD hundreds digit of the score
        .thousands(thousands)    // BCD thousands digit of the score
    );

    // Instantiate the 7-segment display multiplexer
    multiplexer display_mux (
        .clk(clk),
        .ones(ones),             // BCD ones digit
        .tens(tens),             // BCD tens digit
        .hundreds(hundreds),     // BCD hundreds digit
        .thousands(thousands),   // BCD thousands digit
        .seg(seg),               // 7-segment display segments
        .an(an)                  // 7-segment display anodes
    ); 
    
    
    always @(*) begin
                num_buttons_pressed = (!clean_btns[0]) + (!clean_btns[1]) + (!clean_btns[2]) + (!clean_btns[3]);
            end
        
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    rgb_led <= 3'b000;
                    flash_counter <= 0;
                    button_index <= 0;
                end else begin
                    flash_counter <= flash_counter + 1;
        
                    if (num_buttons_pressed == 1) begin
                        case (clean_btns)
                            4'b1110: rgb_led <= 3'b011;  
                            4'b1101: rgb_led <= 3'b100;  
                            4'b1011: rgb_led <= 3'b010;  
                            4'b0111: rgb_led <= 3'b001;   
                            default: rgb_led <= 3'b000;
                        endcase
                    end else if (num_buttons_pressed > 1) begin
                        if (flash_toggle) begin
                            button_index <= button_index + 1;
                        end
                        case (button_index)
                            2'b00: rgb_led <= (!clean_btns[0]) ? 3'b011 : 3'b000;
                            2'b01: rgb_led <= (!clean_btns[1]) ? 3'b100 : 3'b000;
                            2'b10: rgb_led <= (!clean_btns[2]) ? 3'b010 : 3'b000;
                            2'b11: rgb_led <= (!clean_btns[3]) ? 3'b001 : 3'b000;
                            default: rgb_led <= 3'b000;
                        endcase
                    end else begin
                        rgb_led <= 3'b000;
                    end
                end
            end




    // Select VGA outputs based on the `start_game` signal
    assign R = start_game ? game_R : menu_R;
    assign G = start_game ? game_G : menu_G;
    assign B = start_game ? game_B : menu_B;
    assign hsync = start_game ? game_hsync : menu_hsync;
    assign vsync = start_game ? game_vsync : menu_vsync;

endmodule
