module fmcpga_rgb444_to_rgb323 (
    input  wire        active,
    input  wire [11:0] rgb444,
    output wire [2:0]  tft_r,
    output wire [1:0]  tft_g,
    output wire [2:0]  tft_b
);
    assign tft_r = active ? rgb444[11:9] : 3'b000;
    assign tft_g = active ? rgb444[7:6]  : 2'b00;
    assign tft_b = active ? rgb444[3:1]  : 3'b000;
endmodule
