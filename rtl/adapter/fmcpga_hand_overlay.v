module fmcpga_hand_overlay (
    input  wire        active,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [4:0]  selected_block,
    input  wire [11:0] rgb444_in,
    output reg  [11:0] rgb444_out
);
    wire in_hand = active && pix_x >= 10'd640 && pix_x < 10'd752 &&
                   pix_y >= 10'd356 && pix_y < 10'd464;
    wire border = pix_x == 10'd640 || pix_x == 10'd751 ||
                  pix_y == 10'd356 || pix_y == 10'd463;
    wire top_face = pix_y < 10'd388;
    wire left_face = pix_x < 10'd696;

    reg [11:0] block_color;

    always @* begin
        case (selected_block)
            5'd1:  block_color = 12'h6b4;
            5'd2:  block_color = 12'h754;
            5'd3:  block_color = 12'h888;
            5'd4:  block_color = 12'h643;
            5'd5:  block_color = 12'hb96;
            5'd6:  block_color = 12'h584;
            5'd7:  block_color = 12'h444;
            5'd8:  block_color = 12'h36c;
            5'd9:  block_color = 12'h24b;
            5'd10: block_color = 12'he62;
            5'd11: block_color = 12'hf82;
            5'd12: block_color = 12'hed9;
            5'd13: block_color = 12'h777;
            5'd14: block_color = 12'hec4;
            5'd15: block_color = 12'hc97;
            5'd16: block_color = 12'h333;
            5'd17: block_color = 12'h742;
            5'd18: block_color = 12'h383;
            5'd19: block_color = 12'hee4;
            5'd20: block_color = 12'hade;
            5'd21: block_color = 12'h45b;
            5'd22: block_color = 12'hd44;
            5'd23: block_color = 12'h83a;
            default: block_color = 12'haaa;
        endcase

        if (!in_hand) begin
            rgb444_out = rgb444_in;
        end else if (border) begin
            rgb444_out = 12'h111;
        end else if (top_face) begin
            rgb444_out = {block_color[11:8] | 4'h3,
                          block_color[7:4]  | 4'h3,
                          block_color[3:0]  | 4'h3};
        end else if (left_face) begin
            rgb444_out = {1'b0, block_color[11:9],
                          1'b0, block_color[7:5],
                          1'b0, block_color[3:1]};
        end else begin
            rgb444_out = block_color;
        end
    end
endmodule
