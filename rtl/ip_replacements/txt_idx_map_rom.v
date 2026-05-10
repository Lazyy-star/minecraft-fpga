module txt_idx_map_rom (
    input  wire       clka,
    input  wire       ena,
    input  wire [7:0] addra,
    output reg  [4:0] douta
);
    (* rom_style = "block" *) reg [4:0] mem [0:255];

    initial begin
        $readmemh("C:/Users/32915/Desktop/shudiankeshe/mem/txt_idx_map.mem", mem);
    end

    always @(posedge clka) begin
        if (ena) begin
            douta <= mem[addra];
        end
    end
endmodule
