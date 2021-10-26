module top(
	// Inputs
	input clka,
	
	// VGA out
	output [2:0] vga_red,
	output [2:0] vga_green,
	output [2:0] vga_blue,
	output       vga_hsync_n,
	output 	     vga_vsync_n,
	
	// UART
	input 	     RS232_RX,
	output 	     RS232_TXD

   //  TV out
   //, output 		tvsync 
   //, tvrd, tvgrn, tvbl
);

wire vga_clk;
wire tv_clk;

// ======================================
//   RESET signal
reg [3:0] reset_count = 4'd15;
wire sys_rst_i = |reset_count;

always @(posedge vga_clk) begin
	if (sys_rst_i) begin
		reset_count <= reset_count - 1'd1; 	
	end
end 


pll pll_inst (
	//.areset ( areset_sig ),
	.inclk0 ( clka ), // 50 MHz
	.c0 ( vga_clk ),  // 33.33 MHz
	.c1( tv_clk )     // 7 MHz
);

// ========================================
//  TEST TV out
/*tv tv(
	.clk10( tv_clk ), // 10 МГц
	.vout( tvgrn ), 
	.sync_( tvsync )
);*/
  
// ========================================
//  SYNCHRO for TV output 
/*display_timings_tv256p #(.CORDW(11)) sync_video (
	.clk_pix(tv_clk), // 7МГц
	.rst(sys_rst_i),  // wait for pixel clock lock,
	.hsync(vga_hsync_n), // hsync
	.vsync(vga_vsync_n), // vsync
	.sync(tvsync),    	// csync
	//.vout(tvgrn),		// test video
	.de(de),
	.screen(scr),
	.sx(x),
	.sy(y)
);*/

// ========================================
//  SYNCHRO for VGA output 640*480
wire [10:0] x; 
wire [10:0] y;
wire [10:0] yline;
wire de;
wire scr;

display_timings_480p #(.CORDW(11)) sync_video (
	.clk_pix(vga_clk),
	.rst(sys_rst_i),     // wait for pixel clock lock,
	.hsync(vga_hsync_n), // horizontal sync
	.vsync(vga_vsync_n), // vertical sync
	.de(de),
	.screen(scr),
	.sx(x),	             // текущее положение 
	.sy(y),
	.yline(yline)
);

 
// ========================================
//  ZX Video ULA
reg [2:0] border = 0;

zx_video video (
	.clk(vga_clk),
	.x(x),
	.y(y),
	.de(de), // display enable
	.screen(scr), // область экрана
	// Выходные данные
	.VGA_R(vga_red),
	.VGA_G(vga_green),
	.VGA_B(vga_blue),	 
	// Данные для вывода
	.border(border)
);

// ================================================
// timer counter for uS 
wire [31:0] clockuS;

timer _timer(
	.clk(vga_clk),
	.cnt(clockuS)
);

// ================================================
// output data from CPU to port IO
always @(negedge vga_clk)
begin
	if (j1_io_wr) begin
		case (j1_io_addr)
			16'hf002: border = j1_io_dout[2:0];
			
		endcase
	end
end

// ================================================
// чтение из портов ВВ
always @* // 
begin
	j1_io_din = 0;
	case (j1_io_addr)
		16'hf000: j1_io_din = uart_data;
		16'hf001: j1_io_din = {14'd0, uart_busy, uart_valid};				
		16'hf003: j1_io_din = clockuS[15:0];
		16'hf004: j1_io_din = clockuS[31:16];
		16'hf005: j1_io_din = {5'd0, yline};
	default:
		j1_io_din = 16'h0945;
	endcase
end

// ================================================
// UART	
wire j1_uart_wr = j1_io_wr & (j1_io_addr == 16'hf000) ; // TXD
wire j1_uart_rd = j1_io_rd & ((j1_io_addr == 16'hf000)  // RXD
			     ||(j1_io_addr == 16'hf001)) ;  // Status
wire [7:0] 	uart_data;
wire 		uart_valid;
wire 		uart_busy;
	
uart #(.FREQ(25_200_000), .SPEED(115_200)) 
  uart_inst (
        // Outputs
	.uart_busy_o(uart_busy), //High means UART is transmitting
	.uart_tx    (RS232_TXD),
	.uart_dat_o (uart_data), // 8-bit from uart
	.valid_o    (uart_valid),// has data = 1	
	// Inputs
	.sys_clk_i  (vga_clk),
	.sys_rst_i  (sys_rst_i),
	.uart_wr_i  (j1_uart_wr), // write strobe
	.uart_dat_i (j1_io_dout), // 8-bit to uart
	.uart_rx    (RS232_RX),   // UART recv wire
	.uart_rd_i  (j1_uart_rd)  // read strobe		
);
  

//=============================================
// J1 CPU 
wire j1_io_rd;
wire j1_io_wr;
wire [15:0] j1_io_addr;
reg  [15:0] j1_io_din;
wire [15:0] j1_io_dout;
 
j1 j1(
	// Inputs
	.sys_clk_i( vga_clk ),
	.sys_rst_i( sys_rst_i ),

	.io_din	( j1_io_din ),
	.int_req( 0 ), 
	.io_rd	( j1_io_rd ),
	.io_wr	( j1_io_wr ),
	.io_addr( j1_io_addr ),
	
	.io_dout( j1_io_dout )	
); 
  
endmodule