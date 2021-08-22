/* ULA ZX Spectrum video */
`timescale 1ns/1ns
module zx_video
(
    //  7.0  МГц TV  
    // 25.175 МГц VGA 640x480
    input   wire        clk,
	 input 	wire [10:0]	x,
	 input 	wire [10:0]	y,
	 input 	wire 			de,
	 input 	wire 			screen,

    // Выходные данные
    output  reg [2:0]  VGA_R,
    output  reg [2:0]  VGA_G,
    output  reg [2:0]  VGA_B,
    //output  reg        HS,
    //output  reg        VS,

    // Данные для вывода
    output  reg  [12:0] vaddr,
    //input   wire [ 7:0] vdata,
    input   wire [ 2:0] border,

    // Генерация сигнала для IRQ
    output  reg         irq
);
// Экранная область  256*192 пикселей + 32*24 атрибутов = 6912 байтов
//reg [7:0] vram[0:6911]; initial $readmemh("picture.hex", vram);
wire [7:0] qram;
videoram	vram (
	.address ( vaddr ),
	.clock ( clk ),
	.data ( 0 ),
	.rden ( 1),
	.wren ( 0 ),
	.q ( qram )
);


// частота моргания flash = 50 /32 =1.56. счетчик flash 5 разрядный
reg [5:0] flash = 5'b0;
reg prevY;
always @(negedge clk) begin // y=311->0
	if (y[7] && ~prevY )
		flash <= flash + 1'b1;
	prevY = y[7];
	irq = y[7];
end

// Чтобы правильно начинались данные, нужно их выровнять
wire [9:0] X  = x[9:1];
wire [9:0] Y  = y[9:1];

reg [7:0] current_char;
reg [7:0] current_attr;
reg [7:0] tmp_char;
reg [7:0] tmp_attr;
reg       Screen1; 

// Генератор на 7 Мгц
always @(posedge clk) begin
  // Обязательно надо тут использовать попиксельный выход, а то пиксели наполовину съезжают
  case (x[3:0])
                    // БанкY  СмещениеY ПолубанкY СмещениеX
    4'b000: vaddr <= { Y[7:6], Y[2:0],   Y[5:3],   X[7:3] };  // 2 + 3 + 3 + 5
      
    4'b010: begin     
          tmp_char <= qram  ;// vram[vaddr]
    end 

    4'b011: 
			// Запрос атрибута y=0..23  x=0..31, 
                  //  [110] [yyyyy] [xxxxx]
         vaddr <= { 3'b110, Y[7:3], X[7:3] }; // 3 + 5 + 5
	 4'b101: 
			tmp_attr <= qram  ; 

    4'b1111: begin
       current_attr <=  tmp_attr;
       current_char <=  tmp_char;
       Screen1 <= screen;
    end
	 default: begin
		//tmp_char <= tmp_char;
		//tmp_attr <= tmp_attr;
	 end    
  endcase
end

// Получаем текущий бит
wire dot = current_char[ 7^X[2:0] ];

// Атрибут в спектруме представляет собой битовую маску
//  7     6      5 4 3    2 1 0
// [Flash Bright BgColor  FrColor]
/* R - это бит 1, 4 */
/* G - это бит 2, 5 */
/* B - это бит 0, 3 */

wire [2:0] selector = { dot, flash[5], current_attr[7] };
always @(posedge clk ) begin
  if (de) begin
    if (Screen1) begin   
      case (selector)
        3'b000, 3'b010, 3'b011, 3'b101:
          {VGA_R, VGA_G, VGA_B} <= { current_attr[4], current_attr[4] && current_attr[6], 1'b0,
                                     current_attr[5], current_attr[5] && current_attr[6], 1'b0,
                                     current_attr[3], current_attr[3] && current_attr[6], 1'b0};
        3'b001, 3'b100, 3'b110, 3'b111: 
          {VGA_R, VGA_G, VGA_B} <= { current_attr[1], current_attr[1] && current_attr[6], 1'b0,
                                     current_attr[2], current_attr[2] && current_attr[6], 1'b0,
                                     current_attr[0], current_attr[0] && current_attr[6], 1'b0};
      endcase      
    end
    else begin // бордюр
      {VGA_R, VGA_G, VGA_B} <= { border[1], border[1], 1'b0,
										   border[2], border[2], 1'b0, 
										   border[0], border[0], 1'b0 };
    end
  end
  else begin // только черный
    {VGA_R, VGA_G, VGA_B} <= {3'b0, 3'b0, 3'b0};
  end
end

endmodule