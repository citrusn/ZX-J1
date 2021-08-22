// ================================================
// 32-bit 1-MHz system clock
module timer #(MHz=25)
(
	input		wire		clk,
	
	output	wire [31:0] cnt
);

  reg  [5:0]   clockus;
  wire [5:0]  _clockus = (clockus == MHz) ? 6'd0 : (clockus + 1'd1);
  reg  [31:0]  clock;
  wire [31:0] _clock = (clockus == MHz) ? (clock + 1'd1) : (clock);

  always @(posedge clk)
  begin
    clockus <= _clockus;
    clock   <= _clock;
  end
  
  assign cnt = clockus;
  
 endmodule