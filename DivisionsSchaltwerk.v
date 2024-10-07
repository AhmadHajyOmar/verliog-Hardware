module Division(
	input         clock,
	input         start,
	input  [31:0] a,
	input  [31:0] b,
	output [31:0] q,
	output [31:0] r
);

	reg[31:0] R, AQ, B;
	reg[5:0] counter;
	

	always @(posedge start)
	begin
		R <= 32'd0;
		AQ <= a;
		B <= b;
		counter <= 6'd32;
	end
	
	always @(posedge clock)
	begin

		if(counter > 32'd0)
		begin
			R = (R << 1) + AQ[counter-1'b1]; //!!!! <=
			if(R < B)
			begin
				AQ[counter-1] = 1'b0;
			end
			if(R >= B)
			begin

				AQ[counter-1'd1] = 1'b1;
				R = R - B;
			end
			
			counter = counter - 6'd1;
		end
		
		
		
	end
	
	assign q = AQ;
	assign r = R;

endmodule

