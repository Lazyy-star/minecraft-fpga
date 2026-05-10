module music_player (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    output reg         tone_enable,
    output reg  [31:0] half_period_cycles
);
    localparam integer NOTE_TICKS = 25_000_000;
    localparam [31:0] REST = 32'd0;
    localparam [31:0] C4   = 32'd191_113;
    localparam [31:0] D4   = 32'd170_262;
    localparam [31:0] E4   = 32'd151_686;
    localparam [31:0] G4   = 32'd127_552;
    localparam [31:0] A4   = 32'd113_636;
    localparam [31:0] C5   = 32'd95_556;

    reg [24:0] tick_count;
    reg [4:0]  note_index;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_count <= 25'd0;
            note_index <= 5'd0;
        end else if (!enable) begin
            tick_count <= 25'd0;
            note_index <= note_index;
        end else if (tick_count == NOTE_TICKS - 1) begin
            tick_count <= 25'd0;
            note_index <= (note_index == 5'd23) ? 5'd0 : note_index + 5'd1;
        end else begin
            tick_count <= tick_count + 25'd1;
        end
    end

    always @* begin
        case (note_index)
            5'd0:  half_period_cycles = E4;
            5'd1:  half_period_cycles = REST;
            5'd2:  half_period_cycles = G4;
            5'd3:  half_period_cycles = REST;
            5'd4:  half_period_cycles = A4;
            5'd5:  half_period_cycles = REST;
            5'd6:  half_period_cycles = G4;
            5'd7:  half_period_cycles = REST;
            5'd8:  half_period_cycles = E4;
            5'd9:  half_period_cycles = REST;
            5'd10: half_period_cycles = D4;
            5'd11: half_period_cycles = REST;
            5'd12: half_period_cycles = C4;
            5'd13: half_period_cycles = REST;
            5'd14: half_period_cycles = D4;
            5'd15: half_period_cycles = REST;
            5'd16: half_period_cycles = E4;
            5'd17: half_period_cycles = G4;
            5'd18: half_period_cycles = C5;
            5'd19: half_period_cycles = REST;
            5'd20: half_period_cycles = A4;
            5'd21: half_period_cycles = REST;
            5'd22: half_period_cycles = G4;
            default: half_period_cycles = REST;
        endcase
        tone_enable = enable && half_period_cycles != REST;
    end
endmodule
