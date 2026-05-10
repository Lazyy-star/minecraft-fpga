module display_ram (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [16:0] addra,
    input  wire [11:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [16:0] addrb,
    output reg  [11:0] doutb
);
    (* ram_style = "block" *) reg [11:0] mem [0:76799];

    always @(posedge clka) begin
        if (ena && wea[0] && addra < 17'd76800) begin
            mem[addra] <= dina;
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            if (addrb < 17'd76800) begin
                doutb <= mem[addrb];
            end else begin
                doutb <= 12'h000;
            end
        end
    end
endmodule
