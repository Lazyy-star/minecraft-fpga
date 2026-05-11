module buzzer_audio (
    input  wire        clk,
    input  wire        rst,
    input  wire        music_enable,
    input  wire        action_event,
    input  wire        dig_mode,
    input  wire [4:0]  selected_block,
    output reg         buzzer
);
    localparam [31:0] MUSIC_TICKS = 32'd40000000;
    localparam [31:0] SFX_TICKS   = 32'd12000000;
    localparam [31:0] SFX_HALF    = 32'd6000000;

    localparam [18:0] REST = 19'd0;
    localparam [18:0] C4   = 19'd191113;
    localparam [18:0] D4   = 19'd170262;
    localparam [18:0] E4   = 19'd151686;
    localparam [18:0] G4   = 19'd127551;
    localparam [18:0] A4   = 19'd113636;
    localparam [18:0] C5   = 19'd95557;
    localparam [18:0] D5   = 19'd85131;
    localparam [18:0] E5   = 19'd75843;
    localparam [18:0] G5   = 19'd63776;

    reg [31:0] music_cnt;
    reg [5:0]  music_step;
    reg [31:0] sfx_cnt;
    reg        sfx_active;
    reg        sfx_dig;
    reg [18:0] tone_cnt;
    reg        tone_level;
    reg        action_d;

    reg [18:0] music_divider;
    reg [18:0] sfx_divider;
    reg [18:0] tone_divider;

    always @* begin
        case (music_step)
            6'd0:  music_divider = E4;
            6'd1:  music_divider = REST;
            6'd2:  music_divider = G4;
            6'd3:  music_divider = REST;
            6'd4:  music_divider = A4;
            6'd5:  music_divider = REST;
            6'd6:  music_divider = G4;
            6'd7:  music_divider = REST;
            6'd8:  music_divider = C5;
            6'd9:  music_divider = REST;
            6'd10: music_divider = D5;
            6'd11: music_divider = REST;
            6'd12: music_divider = E5;
            6'd13: music_divider = REST;
            6'd14: music_divider = D5;
            6'd15: music_divider = REST;
            6'd16: music_divider = A4;
            6'd17: music_divider = REST;
            6'd18: music_divider = G4;
            6'd19: music_divider = REST;
            6'd20: music_divider = E4;
            6'd21: music_divider = REST;
            6'd22: music_divider = D4;
            6'd23: music_divider = REST;
            default: music_divider = REST;
        endcase
    end

    always @* begin
        if (sfx_dig) begin
            sfx_divider = (sfx_cnt < SFX_HALF) ? C4 : D4;
        end else begin
            case (selected_block[1:0])
                2'd0: sfx_divider = (sfx_cnt < SFX_HALF) ? C5 : E5;
                2'd1: sfx_divider = (sfx_cnt < SFX_HALF) ? D5 : G5;
                2'd2: sfx_divider = (sfx_cnt < SFX_HALF) ? A4 : D5;
                default: sfx_divider = (sfx_cnt < SFX_HALF) ? G4 : C5;
            endcase
        end
    end

    always @* begin
        if (sfx_active) begin
            tone_divider = sfx_divider;
        end else if (music_enable) begin
            tone_divider = music_divider;
        end else begin
            tone_divider = REST;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            music_cnt <= 32'd0;
            music_step <= 6'd0;
            sfx_cnt <= 32'd0;
            sfx_active <= 1'b0;
            sfx_dig <= 1'b0;
            tone_cnt <= 19'd0;
            tone_level <= 1'b0;
            action_d <= 1'b0;
            buzzer <= 1'b0;
        end else begin
            action_d <= action_event;

            if (music_cnt == MUSIC_TICKS - 1) begin
                music_cnt <= 32'd0;
                music_step <= (music_step == 6'd31) ? 6'd0 : music_step + 6'd1;
            end else begin
                music_cnt <= music_cnt + 32'd1;
            end

            if (action_event && !action_d) begin
                sfx_active <= 1'b1;
                sfx_cnt <= 32'd0;
                sfx_dig <= dig_mode;
            end else if (sfx_active) begin
                if (sfx_cnt == SFX_TICKS - 1) begin
                    sfx_active <= 1'b0;
                    sfx_cnt <= 32'd0;
                end else begin
                    sfx_cnt <= sfx_cnt + 32'd1;
                end
            end

            if (tone_divider == REST) begin
                tone_cnt <= 19'd0;
                tone_level <= 1'b0;
                buzzer <= 1'b0;
            end else if (tone_cnt >= tone_divider) begin
                tone_cnt <= 19'd0;
                tone_level <= ~tone_level;
                buzzer <= ~tone_level;
            end else begin
                tone_cnt <= tone_cnt + 19'd1;
                buzzer <= tone_level;
            end
        end
    end
endmodule
