module buzzer_tone_gen (
    input  wire        clk,
    input  wire        rst,
    input  wire        tone_enable,
    input  wire [31:0] half_period_cycles,
    output reg         buzzer
);
    reg [31:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 32'd0;
            buzzer <= 1'b0;
        end else if (!tone_enable || half_period_cycles == 32'd0) begin
            counter <= 32'd0;
            buzzer <= 1'b0;
        end else if (counter >= half_period_cycles) begin
            counter <= 32'd0;
            buzzer <= ~buzzer;
        end else begin
            counter <= counter + 32'd1;
        end
    end
endmodule
