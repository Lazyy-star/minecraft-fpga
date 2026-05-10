module sfx_player (
    input  wire        clk,
    input  wire        rst,
    input  wire        place_event,
    input  wire        dig_event,
    output reg         active,
    output reg         tone_enable,
    output reg  [31:0] half_period_cycles
);
    localparam [1:0] SFX_NONE  = 2'd0;
    localparam [1:0] SFX_PLACE = 2'd1;
    localparam [1:0] SFX_DIG   = 2'd2;

    localparam integer STEP_TICKS = 5_000_000;
    localparam [31:0] E5 = 32'd75_843;
    localparam [31:0] C5 = 32'd95_556;
    localparam [31:0] A4 = 32'd113_636;
    localparam [31:0] G3 = 32'd255_102;
    localparam [31:0] C3 = 32'd382_226;

    reg [1:0] effect;
    reg [2:0] step_index;
    reg [22:0] step_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            effect <= SFX_NONE;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (place_event) begin
            effect <= SFX_PLACE;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (dig_event) begin
            effect <= SFX_DIG;
            step_index <= 3'd0;
            step_count <= 23'd0;
        end else if (effect != SFX_NONE) begin
            if (step_count == STEP_TICKS - 1) begin
                step_count <= 23'd0;
                if (step_index == 3'd2) begin
                    effect <= SFX_NONE;
                    step_index <= 3'd0;
                end else begin
                    step_index <= step_index + 3'd1;
                end
            end else begin
                step_count <= step_count + 23'd1;
            end
        end
    end

    always @* begin
        active = effect != SFX_NONE;
        tone_enable = active;
        case (effect)
            SFX_PLACE: begin
                case (step_index)
                    3'd0: half_period_cycles = C5;
                    3'd1: half_period_cycles = E5;
                    default: half_period_cycles = A4;
                endcase
            end
            SFX_DIG: begin
                case (step_index)
                    3'd0: half_period_cycles = G3;
                    3'd1: half_period_cycles = C3;
                    default: half_period_cycles = G3;
                endcase
            end
            default: begin
                half_period_cycles = 32'd0;
                tone_enable = 1'b0;
            end
        endcase
    end
endmodule
