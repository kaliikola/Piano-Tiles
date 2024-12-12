module vga_sync (
    input wire clk,
    input wire reset,
    output wire hsync,
    output wire vsync,
    output wire active_area,     // High during the active display area
    output reg [9:0] counter_x,
    output reg [9:0] counter_y
);

    // VGA 640x480 Timing Parameters
    localparam H_DISPLAY = 640;   // Horizontal active pixels
    localparam H_FRONT = 16;      // Horizontal front porch
    localparam H_SYNC = 96;       // Horizontal sync pulse
    localparam H_BACK = 48;       // Horizontal back porch
    localparam H_TOTAL = 800;     // Total horizontal pixels

    localparam V_DISPLAY = 480;   // Vertical active lines
    localparam V_FRONT = 10;      // Vertical front porch
    localparam V_SYNC = 2;        // Vertical sync pulse
    localparam V_BACK = 33;       // Vertical back porch
    localparam V_TOTAL = 525;     // Total vertical lines

    // Horizontal and Vertical Counters
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
    assign hsync = ~(counter_x >= (H_DISPLAY + H_FRONT) && counter_x < (H_DISPLAY + H_FRONT + H_SYNC));
    assign vsync = ~(counter_y >= (V_DISPLAY + V_FRONT) && counter_y < (V_DISPLAY + V_FRONT + V_SYNC));

    // Active Display Area
    assign active_area = (counter_x < H_DISPLAY) && (counter_y < V_DISPLAY);

endmodule
