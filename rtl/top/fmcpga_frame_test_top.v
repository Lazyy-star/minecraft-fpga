module fmcpga_frame_test_top (
    input  wire        clk_100m,
    input  wire        btn_reset,
    input  wire        btn_up,
    input  wire        btn_down,
    input  wire        btn_left,
    input  wire        btn_right,
    input  wire        btn_action,
    input  wire [23:0] sw,
    output wire [7:0]  led_r,
    output wire [7:0]  led_g,
    output wire [7:0]  led_y,
    output wire [7:0]  seg_an,
    output wire [7:0]  seg_seg,
    output wire [2:0]  TFT_R_O,
    output wire [1:0]  TFT_G_O,
    output wire [2:0]  TFT_B_O,
    output wire        TFT_CLK_O,
    output wire        TFT_ADJ_O,
    output wire        TFT_DE_O,
    output wire        TFT_HSYNC_O,
    output wire        TFT_VSYNC_O,
    output wire        TFT_MODE_O
);
    wire clk_tft;
    wire locked;
    wire rst = btn_reset | ~locked;
    wire video_on;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire src_active;
    wire [16:0] src_addr;
    wire [11:0] rgb444;
    wire [23:0] control_mix;

    assign control_mix = sw ^ {19'd0, btn_action, btn_right, btn_left, btn_down, btn_up};

    tft_clock_gen u_clk (
        .clk_100m(clk_100m),
        .rst(btn_reset),
        .clk_tft(clk_tft),
        .locked(locked)
    );

    tft_timing u_timing (
        .clk(clk_tft),
        .rst(rst),
        .hsync(TFT_HSYNC_O),
        .vsync(TFT_VSYNC_O),
        .video_on(video_on),
        .pix_x(pix_x),
        .pix_y(pix_y)
    );

    fmcpga_tft_read_mapper u_map (
        .clk(clk_tft),
        .rst(rst),
        .video_on(video_on),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .src_active(src_active),
        .src_addr(src_addr)
    );

    assign rgb444 = sw[23] ? {control_mix[11:8], control_mix[7:4], control_mix[3:0]} :
                              {src_addr[8:5], src_addr[12:9], src_addr[4:1]};

    fmcpga_rgb444_to_rgb323 u_rgb (
        .active(src_active),
        .rgb444(rgb444),
        .tft_r(TFT_R_O),
        .tft_g(TFT_G_O),
        .tft_b(TFT_B_O)
    );

    assign TFT_CLK_O = clk_tft;
    assign TFT_DE_O = video_on;
    assign TFT_ADJ_O = 1'b1;
    assign TFT_MODE_O = 1'b1;
    assign led_r = src_addr[7:0];
    assign led_g = {7'd0, src_active};
    assign led_y = sw[7:0];
    assign seg_an = 8'hff;
    assign seg_seg = 8'hff;
endmodule
