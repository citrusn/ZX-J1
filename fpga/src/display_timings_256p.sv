`default_nettype none
`timescale 1ns / 1ps

module display_timings_tv256p #(
    CORDW=11,   // signed coordinate width (bits)
	 
    H_RES=256,  // horizontal resolution (pixels)
    V_RES=192,  // vertical resolution (lines)	 
	
	 H_BRD=48,	 // Hor border
    H_SYNC=28,  // horizontal sync
    H_BP=68,    // horizontal back porch
	 
    V_BRD=56,    
    V_SYNC=8,   // vertical sync
    
	 
    H_POL=1,    // horizontal sync polarity (0:neg, 1:pos)
    V_POL=1     // vertical sync polarity (0:neg, 1:pos)
    ) (
    input  wire logic clk_pix,  // pixel clock 7MHz
    input  wire logic rst,      // reset    
    
	 output      logic sync,    // mix sync	 
	 output 		 logic vout, 	
	 output      logic hsync,    // hor sync
	 output      logic vsync,    // vertical sync
    output      logic de,       // data enable (low in blanking intervals)
	 output      logic screen,
    output      logic frame,    // high at start of frame
    output      logic line,     // high at start of active line
    output      logic signed [CORDW-1:0] sx,  // horizontal screen position
    output      logic signed [CORDW-1:0] sy   // vertical screen position
    );

    // horizontal timings
	     
	 localparam signed H_STA  = 11'd0;    // horizontal start
	 localparam signed H_LINE = H_RES-1;	 // screen end
	 localparam signed H_RB = H_LINE + H_BRD; // Right Border
	 
    localparam signed HS_STA = H_RB+H_SYNC;   // sync start
	 localparam signed HS_END = HS_STA + H_BP; // sync end	
    localparam signed HA_END = HS_END + H_BRD;// active end

    // vertical timings	 
	 
    localparam signed V_STA  = 11'd0;    // vertical start
    localparam signed V_HEIGHT = V_RES-1; // screen end 
	 localparam signed V_BB = V_HEIGHT + V_BRD; //bottom border
	 
	 localparam signed VS_STA = V_BB + V_SYNC; // sync start
    //localparam signed VS_END = VS_STA + V_FP-1; // sync end	 
    localparam signed VA_END = VS_STA + V_BRD;// active end

    logic signed [CORDW-1:0] x, y;  // screen position

    // generate horizontal and vertical syncs with correct polarity
	 
    always_ff @(negedge clk_pix) begin
        hsync <= H_POL ? (x > 10 && x < 43+1)
                      : !(x > 10 && x < 43+1);
        vsync <= V_POL ? (y > 7  && y < 12)
                      : !(y > 7  && y < 12);
    end
	 assign sync = !(hsync ^ vsync);
	 
    // control signals
    always_ff @(negedge clk_pix) begin
        //de    <= (y >= VA_STA && x >= HA_STA);
		  de    <= (x > 88 && y > 32);
        frame <= (y == V_STA && x == H_STA);
        line  <= (y >= V_STA && x == H_STA);
		  screen <= ( x >=134 && y >= 80  
		           && x < 390 && y < 272);
        if (rst) frame <= 0;  // don't assert frame in reset
    end

    // calculate horizontal and vertical screen position
    always_ff @(negedge clk_pix) begin
        if (x == 447) begin  // last pixel on line?
            x <= 0;
            y <= (y == 11'd311) ? 11'd0 : y + 1'd1;  // last line on screen?
        end else begin
            x <= x + 1'd1;
        end
        if (rst) begin
            x <= 0;
            y <= 0;
        end
    end

    // align screen position with sync and control signals
    always_ff @ (negedge clk_pix) begin
        sx <= x - 11'd140;
        sy <= y - 11'd64;
        if (rst) begin
            sx <= H_STA;
            sy <= V_STA;
        end
    end
	 
	// test video signal
	assign vout = screen 
						&& (sx == 0 || sx == 255 
						   || sy == 0 || sy == 191);
	
	 
endmodule