module MealyPattern(
	input        clock,
	input        i,
	output [1:0] o
);


	reg q1, q2;
	
	initial
	begin
		q1 = 0;
		q2 = 0;
	end
 
	always @ (posedge clock)
	begin
		q1 <= i;
		q2 <= q1;
	end

	assign o[1] = q2 && (!q1) && i;
	assign o[0] = (!q2) && q1 && (!i);
endmodule

module MealyPatternTestbench();
	reg clock;
	reg in;
	wire [1:0] out;

	MealyPattern machine(.clock(clock), .i(in), .o(out));
	initial
	begin
		clock = 0;
		in = 0;
	end
	
	always
		#1
		clock = !clock;

	initial
	begin
		#2
		in = 1;
		#2
		in = 1;
		#2
		in = 0;
		#2
		in = 1;
		#2
		in = 0;
		#2
		in = 1;
		#2
		in = 0;
		#2
		in = 1;
		#2
		in = 1;
		
	end
	
	initial
	begin
		$dumpfile ( "mealy.vcd" ) ;
		$dumpvars ;
	end
	
	initial
		#25
		$finish;
	
endmodule

