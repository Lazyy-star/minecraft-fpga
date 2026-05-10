module divider_gen (
    input  wire        s_axis_divisor_tvalid,
    input  wire [23:0] s_axis_divisor_tdata,
    input  wire        s_axis_dividend_tvalid,
    input  wire [23:0] s_axis_dividend_tdata,
    output wire        m_axis_dout_tvalid,
    output wire [0:0]  m_axis_dout_tuser,
    output wire [47:0] m_axis_dout_tdata
);
    wire signed [23:0] divisor = s_axis_divisor_tdata;
    wire signed [23:0] dividend = s_axis_dividend_tdata;
    wire valid = s_axis_divisor_tvalid && s_axis_dividend_tvalid;
    wire div_zero = divisor == 24'sd0;
    wire signed [23:0] quotient = (valid && !div_zero) ? (dividend / divisor) : 24'sd0;
    wire signed [23:0] remainder = (valid && !div_zero) ? (dividend % divisor) : 24'sd0;

    assign m_axis_dout_tvalid = valid;
    assign m_axis_dout_tuser = div_zero;
    assign m_axis_dout_tdata = {quotient, remainder};
endmodule
