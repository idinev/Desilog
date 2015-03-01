
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module dlog_video(

	//////////// CLOCK //////////
	OSC_50_B3B,
	OSC_50_B4A,
	OSC_50_B5B,
	OSC_50_B8A,

	//////////// Si5338 //////////
	SI5338_SCL,
	SI5338_SDA,

	//////////// Temperature //////////
	TEMP_CS_n,
	TEMP_DIN,
	TEMP_DOUT,
	TEMP_SCLK,

	//////////// VGA //////////
	VGA_B,
	VGA_BLANK_n,
	VGA_CLK,
	VGA_G,
	VGA_HS,
	VGA_R,
	VGA_SYNC_n,
	VGA_VS 
);

//=======================================================
//  PARAMETER declarations
//=======================================================


//=======================================================
//  PORT declarations
//=======================================================

//////////// CLOCK //////////
input 		          		OSC_50_B3B;
input 		          		OSC_50_B4A;
input 		          		OSC_50_B5B;
input 		          		OSC_50_B8A;

//////////// Si5338 //////////
output		          		SI5338_SCL;
inout 		          		SI5338_SDA;

//////////// Temperature //////////
output		          		TEMP_CS_n;
output		          		TEMP_DIN;
input 		          		TEMP_DOUT;
output		          		TEMP_SCLK;

//////////// VGA //////////
output		     [7:0]		VGA_B;
output		          		VGA_BLANK_n;
output		          		VGA_CLK;
output		     [7:0]		VGA_G;
output		          		VGA_HS;
output		     [7:0]		VGA_R;
output		          		VGA_SYNC_n;
output		          		VGA_VS;


//=======================================================
//  REG/WIRE declarations
//=======================================================

assign SI5338_SCL = 0;
assign TEMP_CS_n = 1;
assign TEMP_DIN = 0;
assign TEMP_SCLK = 0;
assign SI5338_SDA = 1'bz;

//=======================================================
//  Structural coding
//=======================================================

reg [7:0] ResetCnt = 0;
reg ResetN = 0;

always@(posedge OSC_50_B3B)
    begin
		if(ResetCnt != 8'd10) begin
			ResetN <= 0;
			ResetCnt <= ResetCnt + 8'd1;
		end else
			ResetN <= 1;
		
    end


dv_main u0 (
	OSC_50_B3B, ResetN,
	VGA_CLK, VGA_HS, VGA_VS, VGA_SYNC_n, VGA_BLANK_n,
	VGA_R, VGA_G, VGA_B
);


endmodule