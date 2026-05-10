module tft_clock_gen (
    input  wire clk_100m,
    input  wire rst,
    output wire clk_tft,
    output wire locked
);

    wire pll_clk;
    wire pll_fb;

    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(12),
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(10.0),
        .CLKOUT0_DIVIDE(36),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.01),
        .STARTUP_WAIT("FALSE")
    ) pll_inst (
        .CLKFBIN(pll_fb),
        .CLKFBOUT(pll_fb),
        .CLKIN1(clk_100m),
        .CLKOUT0(pll_clk),
        .CLKOUT1(),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(rst)
    );

    BUFG clk_bufg (
        .I(pll_clk),
        .O(clk_tft)
    );

endmodule
