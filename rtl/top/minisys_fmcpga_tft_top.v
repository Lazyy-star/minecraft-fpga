module minisys_fmcpga_tft_top (
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
    wire video_on_raw;
    wire hs_raw;
    wire vs_raw;
    wire src_active;
    reg  src_active_d;
    reg  video_on_d;
    reg  hs_d;
    reg  vs_d;
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire [16:0] fb_addr;
    wire [11:0] fb_rgb444;
    wire [3:0] fps_hundreds;
    wire [3:0] fps_tens;
    wire [3:0] fps_ones;
    wire [3:0] current_item_ones;

    tft_clock_gen u_clk (
        .clk_100m(clk_100m),
        .rst(btn_reset),
        .clk_tft(clk_tft),
        .locked(locked)
    );

    tft_timing u_timing (
        .clk(clk_tft),
        .rst(rst),
        .hsync(hs_raw),
        .vsync(vs_raw),
        .video_on(video_on_raw),
        .pix_x(pix_x),
        .pix_y(pix_y)
    );

    fmcpga_tft_read_mapper u_map (
        .clk(clk_tft),
        .rst(rst),
        .video_on(video_on_raw),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .src_active(src_active),
        .src_addr(fb_addr)
    );

    always @(posedge clk_tft or posedge rst) begin
        if (rst) begin
            src_active_d <= 1'b0;
            video_on_d <= 1'b0;
            hs_d <= 1'b1;
            vs_d <= 1'b1;
        end else begin
            src_active_d <= src_active;
            video_on_d <= video_on_raw;
            hs_d <= hs_raw;
            vs_d <= vs_raw;
        end
    end

    fmcpga_core_flat u_core (
        .clk_sys(clk_100m),
        .rst(rst),
        .btn_front_in(btn_left),
        .btn_back_in(btn_right),
        .btn_left_in(btn_down),
        .btn_right_in(btn_up),
        .btn_up_in(1'b0),
        .btn_down_in(1'b0),
        .place_in(btn_action),
        .dig_in(sw[5]),
        .selected_block_in(sw[4:0]),
        .disp_read_clk(clk_tft),
        .disp_read_en(src_active),
        .disp_read_addr(fb_addr),
        .disp_read_data(fb_rgb444),
        .fps_hundreds(fps_hundreds),
        .fps_tens(fps_tens),
        .fps_ones(fps_ones),
        .current_item_ones(current_item_ones)
    );

    fmcpga_rgb444_to_rgb323 u_rgb (
        .active(src_active_d),
        .rgb444(fb_rgb444),
        .tft_r(TFT_R_O),
        .tft_g(TFT_G_O),
        .tft_b(TFT_B_O)
    );

    assign TFT_CLK_O = ~clk_tft;
    assign TFT_DE_O = video_on_d;
    assign TFT_HSYNC_O = hs_d;
    assign TFT_VSYNC_O = vs_d;
    assign TFT_ADJ_O = 1'b1;
    assign TFT_MODE_O = 1'b1;

    assign led_r = {fps_hundreds, fps_tens};
    assign led_g = {fps_ones, current_item_ones};
    assign led_y = {sw[5], btn_action, sw[4:0], src_active};
    assign seg_an = 8'hff;
    assign seg_seg = 8'hff;
endmodule
