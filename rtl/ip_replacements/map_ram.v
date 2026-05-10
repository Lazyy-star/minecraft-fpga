module map_ram (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [16:0] addra,
    input  wire [4:0]  dina,
    output reg  [4:0]  douta,
    input  wire        clkb,
    input  wire        enb,
    input  wire [0:0]  web,
    input  wire [16:0] addrb,
    input  wire [4:0]  dinb,
    output reg  [4:0]  doutb
);
    (* ram_style = "block" *) reg [4:0] mem [0:131071];

    initial begin
        $readmemh("D:/codes/mc/minecraft-fpga/mem/map_test.mem", mem);
    end

    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) begin
                mem[addra] <= dina;
            end
            douta <= mem[addra];
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            if (web[0]) begin
                mem[addrb] <= dinb;
            end
            doutb <= mem[addrb];
        end
    end
endmodule
