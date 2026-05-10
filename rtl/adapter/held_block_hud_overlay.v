module held_block_hud_overlay (
    input  wire        video_active,
    input  wire        frame_active,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [4:0]  selected_block,
    input  wire [11:0] rgb_in,
    output wire [11:0] rgb_out
);
    localparam [9:0] HUD_X0 = 10'd704;
    localparam [9:0] HUD_Y0 = 10'd384;
    localparam [9:0] HUD_SIZE = 10'd56;
    localparam [9:0] HUD_X1 = HUD_X0 + HUD_SIZE;
    localparam [9:0] HUD_Y1 = HUD_Y0 + HUD_SIZE;

    wire in_hud = video_active && pix_x >= HUD_X0 && pix_x < HUD_X1 && pix_y >= HUD_Y0 && pix_y < HUD_Y1;
    wire border = in_hud && (
        pix_x < HUD_X0 + 10'd4 ||
        pix_x >= HUD_X1 - 10'd4 ||
        pix_y < HUD_Y0 + 10'd4 ||
        pix_y >= HUD_Y1 - 10'd4
    );
    wire highlight = in_hud && !border && (pix_x < HUD_X0 + 10'd10 || pix_y < HUD_Y0 + 10'd10);

    reg [11:0] block_color;

    always @* begin
        case (selected_block)
            5'd0:  block_color = 12'h000;
            5'd1:  block_color = 12'h6a4;
            5'd2:  block_color = 12'h573;
            5'd3:  block_color = 12'h875;
            5'd4:  block_color = 12'h888;
            5'd5:  block_color = 12'hb74;
            5'd6:  block_color = 12'h3b3;
            5'd7:  block_color = 12'h222;
            5'd8:  block_color = 12'h39f;
            5'd9:  block_color = 12'h26c;
            5'd10: block_color = 12'hf53;
            5'd11: block_color = 12'hfa0;
            5'd12: block_color = 12'hdc8;
            5'd13: block_color = 12'h8a8;
            5'd14: block_color = 12'hecc;
            5'd15: block_color = 12'hddd;
            5'd16: block_color = 12'h111;
            5'd17: block_color = 12'h963;
            5'd18: block_color = 12'h4a4;
            5'd19: block_color = 12'hcc9;
            5'd20: block_color = 12'h9df;
            5'd21: block_color = 12'h36a;
            5'd22: block_color = 12'h25d;
            5'd23: block_color = 12'hd33;
            default: block_color = 12'hf0f;
        endcase
    end

    assign rgb_out =
        border ? 12'h111 :
        highlight ? 12'hfff :
        in_hud ? block_color :
        frame_active ? rgb_in :
        12'h000;
endmodule
