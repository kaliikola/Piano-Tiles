module button_handler (
    input wire clk,               // System clock
    input wire reset,             // Reset signal
    input wire [6:0] noisy_btns,  // Noisy button inputs (active low, 7 total buttons)
    output wire [6:0] clean_btns  // Debounced button outputs (active low)
);
    // Reset stabilization delay
    reg [20:0] reset_counter;      // Counter for reset delay
    reg inputs_stable;             // Signal indicating inputs are stable

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reset_counter <= 0;
            inputs_stable <= 0;
        end else if (reset_counter == 21'h1FFFFF) begin // ~42ms delay at 50 MHz
            inputs_stable <= 1;
        end else begin
            reset_counter <= reset_counter + 1;
        end
    end

    // Instantiate debounce modules for each button
    wire [6:0] debounced_outputs;

    debounce db0 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[0]), .clean_btn(debounced_outputs[0]));
    debounce db1 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[1]), .clean_btn(debounced_outputs[1]));
    debounce db2 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[2]), .clean_btn(debounced_outputs[2]));
    debounce db3 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[3]), .clean_btn(debounced_outputs[3]));
    debounce db4 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[4]), .clean_btn(debounced_outputs[4]));
    debounce db5 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[5]), .clean_btn(debounced_outputs[5]));
    debounce db6 (.clk(clk), .reset(reset), .noisy_btn(noisy_btns[6]), .clean_btn(debounced_outputs[6]));

    // Ensure outputs are inactive during reset or if inputs are not yet stable
    assign clean_btns = (inputs_stable) ? debounced_outputs : 7'b1111111;

endmodule
