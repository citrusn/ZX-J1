module tv (
    input clk10, //10 MHz
    output vout, 
	 output sync_
);


reg [9:0] xpos;
reg [8:0] ypos;

always @(posedge clk10) begin
    if (xpos == 639) begin
        xpos <= 0;
        if (ypos == 311)
            ypos <= 0;
        else
            ypos <= ypos + 1;
    end else
        xpos <= xpos + 1;
end
//
wire active = xpos < 478 && ypos < 256;
//wire active = xpos < 300 && ypos < 200;
wire hsync = 528 <= xpos && xpos < 575;
wire vsync = 276 <= ypos && ypos < 279;

assign vout = active && (xpos == 30 || xpos == 476 ||
 ypos == 5 || ypos == 255);
assign sync_ = active ||
 !(hsync ^ vsync);

endmodule