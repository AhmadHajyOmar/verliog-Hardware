
module Datapath(
	input         clk, reset,
	input         memtoreg,
	input         dobranch,
	input         alusrcbimm,
	input  [4:0]  destreg,
	input         regwrite,
	input         jump,
	input  [2:0]  alucontrol,
	output        zero,
	output [31:0] pc,
	input  [31:0] instr,
	output [31:0] aluout,
	output [31:0] writedata,
	input  [31:0] readdata
);
	wire [31:0] pc;
	wire [31:0] signimm;
	wire [31:0] srca, srcb, srcbimm;
	wire [31:0] result;
	wire [1:0] signExtC; // von mir!!!
	wire [5:0] op = instr[31:26]; // von mir!!!
	wire [5:0] func = instr[5:0];
	wire jal;
	wire jr;
	wire isDiv, delay;
	
	//interlock 
	interlock lock(dividing, op, func, delay);
	
	// Fetch: Reiche PC an Instruktionsspeicher weiter und update PC
	assign jr = (op == 6'd0 && func == 6'b001000) ? 1'b1 : 1'b0;
	ProgramCounter pcenv(clk, reset, dobranch, signimm, jump,result,jr,instr[25:0],delay, pc);

	// Execute:
	// (a) Wähle Operanden aus
	
	//assign signExtC = (op==6'b001111) ? 2'b01: //lui
		//			  (op==6'b001101) ? 2'b11: //Ori
		//				2'b00;
	//SignExtension se(signExtC, instr[15:0], signimm);
	SignExtension se(op, instr[15:0], signimm);
	
	assign srcbimm = alusrcbimm ? signimm : srcb;
	// (b) Führe Berechnung in der ALU durch
	
	assign isDiv = (op == 6'd0 && func == 6'b011011) ? 1'b1 : 1'b0;
	
	ArithmeticLogicUnit alu(clk,srca, srcbimm, alucontrol, isDiv,aluout, zero, dividing); //isDiv vor aluout; clk vorne
	// (c) Wähle richtiges Ergebnis aus
	
	assign jal = (op == 6'b000011) ? 1'b1 : 1'b0; // für Jal
	assign result = memtoreg ? readdata :
					jal ? pc + 32'd4 :
					aluout;

	// Memory: Datenwort das zur (möglichen) Speicherung an den Datenspeicher übertragen wird
	assign writedata = srcb;

	// Write-Back: Stelle Operanden bereit und schreibe das jeweilige Resultat zurück
	RegisterFile gpr(clk, regwrite, instr[25:21], instr[20:16],
				   destreg, result, srca, srcb);
endmodule

module interlock(
	input dividing,
	input[5:0] op,
	input[5:0] func,
	output delay
);
	assign delay = (dividing && (op ==  6'd0) && (func == 6'b010000 ||func == 6'b010010)) 
					? 1'b1 : 1'b0;
	
endmodule

module ProgramCounter(
	input         clk,
	input         reset,
	input         dobranch,
	input  [31:0] branchoffset,
	input         dojump,
	input  [31:0] aluResult, // für jr
	input  		  doJr, //für jr
	input  [25:0] jumptarget,
	input 		  delay,
	output [31:0] progcounter
);
	reg  [31:0] pc;
	wire [31:0] incpc, branchpc, nextpc;

	// Inkrementiere Befehlszähler um 4 (word-aligned)
	Adder pcinc(.a(pc), .b(32'b100), .cin(1'b0), .y(incpc));
	// Berechne mögliches (PC-relatives) Sprungziel
	Adder pcbranch(.a(incpc), .b({branchoffset[29:0], 2'b00}), .cin(1'b0), .y(branchpc));
	// Wähle den nächsten Wert des Befehlszählers aus
	assign nextpc = dojump   ? {incpc[31:28], jumptarget, 2'b00} :
					dobranch ? branchpc :
					doJr ? aluResult :
					delay ? pc : incpc; // if delay we get the same pc

	// Der Befehlszähler ist ein Speicherbaustein
	always @(posedge clk)
	begin
		if (reset) begin // Initialisierung mit Adresse 0x00400000
			pc <= 'h00400000;
		end else begin
			pc <= nextpc;
		end
	end

	// Ausgabe
	assign progcounter = pc;

endmodule

module RegisterFile(
	input         clk,
	input         we3,
	input  [4:0]  ra1, ra2, wa3,
	input  [31:0] wd3,
	output [31:0] rd1, rd2
);
	reg [31:0] registers[31:0];
	

	always @(posedge clk)
		if (we3) begin
			registers[wa3] <= wd3;
		end

	assign rd1 = (ra1 != 0) ? registers[ra1] : 0;
	assign rd2 = (ra2 != 0) ? registers[ra2] : 0;
endmodule

module Adder(
	input  [31:0] a, b,
	input         cin,
	output [31:0] y,
	output        cout
);
	assign {cout, y} = a + b + cin;
endmodule


module SignExtension(  /// signed extension ändern für OR
    input [5:0] opp,
    input  [15:0] a,
    output [31:0] y
);   
     
    assign y= (opp == 6'b001101) ? ({{16{1'b0}}, a}) : //ori?
              (opp == 6'b001111) ? a<<16              : //lui?
             
              {{16{a[15]}}, a};                            //normal sign extend
endmodule


module ArithmeticLogicUnit(  
	input 		  clock, //division
	input  [31:0] a, b,
	input  [2:0]  alucontrol,
	input 		  isDiv,  // division
	output [31:0] result,
	output        zero,
	output 		  possible_delay //division
);
	// TODO Implementierung der ALU
	reg [31:0] HI, LO; //multi
	wire[63:0] mul_result = a*b;// Ahmad multiplication
	wire[31:0] q,r; //division
	wire dividing; //division
	reg stop_div; //division

	
	
	Division_Bonus div(clock,isDiv,a,b,q,r, dividing); //division
	
	always @(negedge dividing) //division
		begin
		if(!stop_div)
			begin
				HI <= r; 
				LO <= q;
			end
		end
		
	always @(posedge clock)
		begin
			$display(result);
		end
		
	always @(posedge isDiv) //division
		stop_div <= 1'b0;
	
	
	always @* //multiplication
		begin
			if(alucontrol[2:0] == 3'b100 && (!isDiv)) //stoping division if we multiply
				begin
					stop_div <= 1'b1; //division
					HI <= mul_result[63:32];
					LO <= mul_result[31:0];
				end
		end

	
	assign result  = (alucontrol[2:0] == 3'b000) ? a & b:
					(alucontrol[2:0] == 3'b001) ? a | b:
					(alucontrol[2:0] == 3'b010) ? a + b: 
					(alucontrol[2:0] == 3'b110) ? a - b:
					(alucontrol[2:0] == 3'b101) ? HI: //multi mfhi
					(alucontrol[2:0] == 3'b011) ? LO: //multi mflo
					(a<b);                                   //(sub[32]==1) ? 1: 0; 
					
	assign zero = (result == 32'd0);			
	assign possible_delay = dividing; //division
endmodule	





module Division_Bonus(
	input         clock,
	input         start,
	input  [31:0] a,
	input  [31:0] b,
	output [31:0] q,
	output [31:0] r,
	output busy

);

	reg[31:0] R, AQ, B;
	reg[5:0] counter;
	reg Dividing = 1'b0;
	

	always @(posedge start)
	begin
		R <= 32'd0;
		AQ <= a;
		B <= b;
		counter <= 6'd32;
		Dividing <= 1'b1;
	end
	
	always @(posedge clock)
	begin
		

		if(counter > 5'd0)
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
		else 
			begin
				Dividing <= 1'b0;
			end
		
		
		
	end
	
	assign busy = Dividing;
	assign q = AQ;
	assign r = R;

endmodule


