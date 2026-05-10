module audio_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire        music_enable,
    input  wire        place_event,
    input  wire        dig_event,
    input  wire [4:0]  selected_block,
    output wire        buzzer
);
    wire        music_tone_enable;
    wire [31:0] music_half_period;
    wire        sfx_active;
    wire        sfx_tone_enable;
    wire [31:0] sfx_half_period;
    wire        mixed_enable;
    wire [31:0] mixed_half_period;

    music_player u_music (
        .clk(clk),
        .rst(rst),
        .enable(music_enable),
        .tone_enable(music_tone_enable),
        .half_period_cycles(music_half_period)
    );

    sfx_player u_sfx (
        .clk(clk),
        .rst(rst),
        .place_event(place_event),
        .dig_event(dig_event),
        .active(sfx_active),
        .tone_enable(sfx_tone_enable),
        .half_period_cycles(sfx_half_period)
    );

    assign mixed_enable = sfx_active ? sfx_tone_enable : music_tone_enable;
    assign mixed_half_period = sfx_active ? sfx_half_period : music_half_period;

    buzzer_tone_gen u_tone (
        .clk(clk),
        .rst(rst),
        .tone_enable(mixed_enable),
        .half_period_cycles(mixed_half_period),
        .buzzer(buzzer)
    );

    wire selected_block_used = |selected_block;
endmodule
