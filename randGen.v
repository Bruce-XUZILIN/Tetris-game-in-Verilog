module randGen(
  input clk,
  output reg [31:0] data
);

reg [31:0] next;
reg [31:0] curr;

initial begin
	curr <= 32'd123;
end

always @(posedge clk) begin
  next <= (curr * 75 + 74) % 32'd65537; //2^16 bits random
  curr <= next;
  data <= curr % 32'd7;
end

endmodule