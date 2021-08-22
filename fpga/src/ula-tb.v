/* J1 CPU Testbench */
`timescale 1ns/1ns
module ula_tb;

parameter tck = 142; ///< clock tick 7МГц

reg clk, rst;
reg [15:0] io_din; // data input
wire int_req;
wire vsync;
wire HS;
wire VS;
wire [3:0] VGA_R;
wire [3:0] VGA_G;
wire [3:0] VGA_B;
wire [15:0] io_dout;
wire [15:0] cpu_addr;
reg [2:0] border;
wire [12:0] vaddr;
reg [ 7:0] vdata;
    
ula ula(
  clk,
  // Выходные данные
  VGA_R,
  VGA_G,
  VGA_B,
  HS,
  VS,
  // Данные для вывода
  vaddr,
  vdata,
  border,
  int_req
);

always #(tck/2) clk <= ~clk; // clocking device

initial begin
  $dumpfile("ula.vcd");
  $dumpvars(-1, ula);
end

initial begin
  clk = 1; rst = 0; border = 3'b0; vdata= 8'b0; 
  #(tck*355000);
  $finish;
end

endmodule
