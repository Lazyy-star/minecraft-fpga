module tft_timing (
    input  wire       clk,
    input  wire       rst,
    output wire       hsync,
    output wire       vsync,
    output wire       video_on,
    output reg [9:0]  pix_x,
    output reg [9:0]  pix_y
);

    localparam H_VISIBLE = 800;
    localparam H_FRONT   = 40;
    localparam H_SYNC    = 48;
    localparam H_BACK    = 40;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 13;
    localparam V_SYNC    = 3;
    localparam V_BACK    = 29;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pix_x <= 10'd0;
            pix_y <= 10'd0;
        end else begin
            if (pix_x == H_TOTAL - 1) begin
                pix_x <= 10'd0;
                if (pix_y == V_TOTAL - 1) begin
                    pix_y <= 10'd0;
                end else begin
                    pix_y <= pix_y + 10'd1;
                end
            end else begin
                pix_x <= pix_x + 10'd1;
            end
        end
    end

    assign hsync = ~((pix_x >= H_VISIBLE + H_FRONT) &&
                     (pix_x <  H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((pix_y >= V_VISIBLE + V_FRONT) &&
                     (pix_y <  V_VISIBLE + V_FRONT + V_SYNC));
    assign video_on = (pix_x < H_VISIBLE) && (pix_y < V_VISIBLE);

endmodule
