/* J1 CPU Testbench */
`timescale 1ns/1ns
module j1_tb;

parameter tck = 20; ///< clock tick

reg clk, rst;
reg [15:0] io_din; // data input
reg int_req;
wire vsync;
wire io_rd;
wire io_wr;
wire [15:0] io_addr;
wire [15:0] io_dout;
wire [15:0] cpu_addr;

j1 cpu(
  clk, 
  rst,
  io_din,
  vsync, //int_req,

  io_rd,
  io_wr,
  io_addr, 
  io_dout
);

always #(tck/2) clk <= ~clk; // clocking device

reg [4:0] counter=0;
always @(negedge clk) begin  
  /*if (counter==8) 
    counter=0;
  else*/
   counter = counter+1;
end
assign vsync = 0; // (counter==8) ;//& clk ;

initial begin
  $dumpfile("j1.vcd");
  $dumpvars(-1, cpu, vsync, counter);
end

initial begin
  clk = 0; rst = 0; int_req=0;
  #(tck*2);
  rst = 1;
  #(tck*2);
  rst = 0;
  #(tck*11);
  int_req = 1;
  #(tck*1);
  int_req = 0;
  #(tck*55);
  $finish;
end

endmodule
