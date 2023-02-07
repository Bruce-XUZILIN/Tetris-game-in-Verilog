module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,
							 
							 
							 colorInd,
							 blockAddr,
							 write_clk,
							 blockWriteEnable,
							 scoreIn,
							 scoreEnable);
input iRST_n;
input iVGA_CLK;
input blockWriteEnable;
input [7:0] colorInd;
input [18:0] blockAddr;
input write_clk;
input [31:0] scoreIn;
input scoreEnable;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [7:0] b_data;//define as B-G-R, not RGB!
output [7:0] g_data;  
output [7:0] r_data;                        
////////////////////
reg [7:0] block_index;
reg [202:0] block_data;                
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;
wire qout;
wire VGA_CLK_n;
////
assign rst = ~iRST_n;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));
////
////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR=19'd0;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR=19'd0;
  else if (cBLANK_n==1'b1) begin
     ADDR=ADDR+19'd1;
  end
end
always@(posedge VGA_CLK_n) begin
  block_data[block_index] = qout;
  if (block_index == 8'd202)
	  block_index = 8'd0;
  else
     block_index = block_index + 8'd1;
end
//////////////////////////

assign VGA_CLK_n = ~iVGA_CLK;

reg [10:0] x, y;
wire [10:0] currX, currY;
reg [18:0] square_address;
reg [7:0] index_modified;
wire [18:0] counter;

wire [7:0] block_addr;
wire [7:0] number1_ind, number2_ind, number3_ind;//three numbers on the right side
wire [31:0] number1, number2, number3;
wire [31:0] number1_addr, number2_addr, number3_addr;


wire [31:0] score;
scoreLatch scoreLatch_inst(
	.d(scoreIn), 
	.q(score),
	.reset(iRST_n), 
	.wren(scoreEnable), 
	.clk(write_clk)
);


addr2xy(.address(ADDR), .x(currX), .y(currY));
xy2addr(.x(currX), .y(currY), .address(block_addr));
getnumber1(score, number1);
getnumber2(score, number2);
getnumber3(score, number3);
getNumberAddr1(currX, currY, number1_addr);
getNumberAddr2(currX, currY, number2_addr);
getNumberAddr3(currX, currY, number3_addr);

vga_block block_inst(
	.data (colorInd[7:0]),
	.rdaddress (block_addr),
	.rdclock (VGA_CLK_n),
	.wraddress (blockAddr[7:0]),
	.wrclock (write_clk),
	.wren (blockWriteEnable),
	.q (index)
);

number number_inst1(
	.address(number1 * 16 + number1_addr),
	.clock(VGA_CLK_n),
	.q(number1_ind));
	
number number_inst2(
	.address(number2 * 16 + number2_addr),
	.clock(VGA_CLK_n),
	.q(number2_ind));
	
number number_inst3(
	.address(number3 * 16 + number3_addr),
	.clock(VGA_CLK_n),
	.q(number3_ind));


always@(*)begin
	
	if (currX >= 120 && currX < 320 && currY >= 40 && currY < 440)//the white gaming area, original 220/420
		index_modified <= index;
	else if (currX >= 390 && currX < 450 && currY >= 200 && currY < 300)//the position of each number(1)
		index_modified <= number1_ind + 10;
	else if (currX >= 470 && currX < 530 && currY >= 200 && currY < 300)
		index_modified <= number2_ind + 10;
	else if (currX >= 550 && currX < 610 && currY >= 200 && currY < 300)
		index_modified <= number3_ind + 10;
	else begin
		index_modified <= 5'd10;
	end
		
end

//////Color table output
img_index	img_index_inst (
	.address ( index_modified ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
////////
//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) 
	bgr_data <= bgr_data_raw;
assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0]; 
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end

endmodule
 	



module xy2addr(x, y, address);
// turns vga xy coord to block address
	input [10:0] x, y;
	output [18:0] address;
	
	assign address = (x < 120 || x >= 320 || y < 40 || y >= 440)? 18'b0 : (x - 120) / 20 + ((y - 40) / 20) * 10;//220,420,220
endmodule

module addr2xy(address, x, y);
// turn vga address to vga xy coord
	input [18:0] address;
	output [10:0] x, y;
	
	assign x = address % 640;
	assign y = address / 640;
endmodule

module getnumber3(score, number3);
	input [31:0] score;
	output [31:0] number3;
	assign number3 = score % 10;
endmodule

module getnumber2(score, number2);
	input [31:0] score;
	output [31:0] number2;
	assign number2 = (score / 10) % 10;
endmodule

module getnumber1(score, number1);
	input [31:0] score;
	output [31:0] number1;
	assign number1 = score / 100;
endmodule

module getNumberAddr1(x, y, addr);
	input [10:0] x, y;
	output [18:0] addr;
	assign addr = (x - 390) / 20 + ((y - 200) / 20) * 3;//the position of each number(),original 100
endmodule

module getNumberAddr2(x, y, addr);
	input [10:0] x, y;
	output [18:0] addr;
	assign addr = (x - 470) / 20 + ((y - 200) / 20) * 3;
endmodule

module getNumberAddr3(x, y, addr);
	input [10:0] x, y;
	output [18:0] addr;
	assign addr = (x - 550) / 20 + ((y - 200) / 20) * 3;
endmodule

module scoreLatch(d, q, reset, wren, clk);

	output reg [31:0] q;
	input [31:0] d;
	input reset, clk, wren;

	initial begin
		q <= 31'd0;
	end

	always @(posedge clk) begin
		if (~reset) begin
			q <= 31'd0;
		end else if (wren) begin
			q <= d;
		end
	end

endmodule











