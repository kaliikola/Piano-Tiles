module debounce (
    input wire clk,        // System clock
    input wire reset,      // Reset signal
    input wire noisy_btn,  // Noisy button input (active low)
    output reg clean_btn   // Debounced button output (active low)
);
    reg [19:0] counter;    // Counter for debounce timing
    reg btn_state;         // Current stable state of the button

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            btn_state <= 1; // Default state for active low (not pressed)
            clean_btn <= 1;
        end else begin
            if (noisy_btn == btn_state) begin
                // Reset counter if state is stable
                counter <= 0;
            end else begin
                // Increment counter if state changes
                counter <= counter + 1;
                if (counter == 20'hFFFFF) begin
                    // Update button state after debounce period
                    btn_state <= noisy_btn;
                    clean_btn <= noisy_btn;
                    counter <= 0;
                end
            end
        end
    end
endmodule

