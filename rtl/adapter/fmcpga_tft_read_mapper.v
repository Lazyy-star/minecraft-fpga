module fmcpga_tft_read_mapper (
    input  wire        clk,
    input  wire        rst,
    input  wire        video_on,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    output reg         src_active,
    output reg [16:0]  src_addr
);
    localparam integer TFT_W = 800;
    localparam integer SRC_W = 320;
    localparam integer SRC_H = 240;
    localparam integer X_PAD = (TFT_W - SRC_W * 2) / 2;

    wire in_x = (pix_x >= X_PAD[9:0]) && (pix_x < (X_PAD + SRC_W * 2));
    wire in_y = pix_y < (SRC_H * 2);
    wire [8:0] src_x = (pix_x - X_PAD[9:0]) >> 1;
    wire [7:0] src_y = (SRC_H - 1) - pix_y[8:1];
    wire [16:0] row_base = {src_y, 8'b0} + {src_y, 6'b0};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            src_active <= 1'b0;
            src_addr <= 17'd0;
        end else begin
            src_active <= video_on && in_x && in_y;
            src_addr <= row_base + src_x;
        end
    end
endmodule
