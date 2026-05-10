module texture_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [12:0] addra,
    output reg  [31:0] douta
);
    (* rom_style = "block" *) reg [31:0] mem [0:8191];

    initial begin
        $readmemh("D:/codes/mc/minecraft-fpga/mem/textures.mem", mem);
    end

    always @(posedge clka) begin
        if (ena) begin
            douta <= mem[addra];
        end
    end
endmodule
