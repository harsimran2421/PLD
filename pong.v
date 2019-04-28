module pong(clock, reset, h_sync, v_sync, DAC_clock, vga_R, vga_G, vga_B, left_key, right_key, blank_n, left_key1, right_key1);
input clock, reset;
output reg [7:0] vga_R, vga_G, vga_B;
wire VGA_clock;
output h_sync, v_sync, DAC_clock;
input left_key, right_key, left_key1, right_key1;
output blank_n;
wire R,G,B;
wire displayArea;
wire [9:0] CounterX;
wire [8:0] CounterY;
reg colour;
reg end_game=0;

									
//instantiating various modules
clock_divide red(clock,VGA_clock);
VGA_gen gen1(VGA_clock, CounterX, CounterY, displayArea, h_sync, v_sync, blank_n);
updateclock UPDATE(clock,update);

assign DAC_clock = VGA_clock;

/////////////////////////////////////////////
reg [8:0] bar;
reg [8:0] bar1;
reg [8:0] temp;
reg [2:0] left_keyr, right_keyr;
reg [2:0] left_keyr1, right_keyr1;
always @(posedge VGA_clock) 
	left_keyr <= {left_keyr[1:0], left_key};

always @(posedge VGA_clock) 
	right_keyr <= {right_keyr[1:0], right_key};

always @(posedge VGA_clock) 
	left_keyr1 <= {left_keyr1[1:0], left_key1};
always @(posedge VGA_clock) 
	right_keyr1 <= {right_keyr1[1:0], right_key1};

always @(posedge VGA_clock)
// so that no two keys are pressed at the same time
if(left_keyr[2] ^ left_keyr[1] ^ right_keyr[2] ^ right_keyr[1])
begin
	// if left key is pressed
	if(reset==1)
	bar<=0;
	else if(left_keyr[0] > right_keyr[0])
	begin
		if(~&bar)        // making sure the value doesn't overflow
			bar <= bar + 6'b111000;	// changing the velocity of the paddle
	end
	// if right key is pressed
	else if(left_keyr[0] < right_keyr[0])
	begin
		if(|bar)        // making sure the value doesn't underflow
			bar <= bar - 6'b111000;
	end
	else
		// should retain the original value
		bar <= bar;
end

always @(posedge VGA_clock)
// so that no two keys are pressed at the same time
if(left_keyr1[2] ^ left_keyr1[1] ^ right_keyr1[2] ^ right_keyr1[1])
begin
	if(reset==1)
	bar1<=0;
	// if left key is pressed
	else if(left_keyr1[0] > right_keyr1[0])
	begin
		if(~&bar1)        // making sure the value doesn't overflow
			bar1 <= bar1 + 6'b111000;	// changing the velocity of the paddle
	end
	// if right key is pressed
	else if(left_keyr1[0] < right_keyr1[0])
	begin
		if(|(bar1-192))        // making sure the value doesn't underflow
			bar1 <= bar1 - 6'b111000;
	end
	else
		// should retain the original value
		bar1 <= bar1;
end

reg [9:0] ballX = 50;
reg [9:0] ballY = 50;
reg ball_inX, ball_inY;
integer i;
always @(posedge VGA_clock)
if(ball_inX==0) 
   begin
	ball_inX <= (CounterX==ballX) & ball_inY; 
	end
else 
	ball_inX <= !(CounterX==(ballX+16));

always @(posedge VGA_clock)
if(ball_inY==0) 
	ball_inY <= ((CounterY)==(ballY));
else 
	ball_inY <= !(CounterY==(ballY+16));

wire ball = ball_inX & ball_inY;


// (paddle + 8) so that it starts from the right of the left border. Width of the paddle is 112.
wire paddle = (CounterX>=(bar+8)) && (CounterX<=(bar+120)) && (CounterY[8:4]==27);

wire paddle1 = (CounterX>=(bar1+8)) && (CounterX<=(bar1+120)) && (CounterY[8:4]==3);

// checking if the count value has reached the border
wire border = (CounterX[9:3]==0) || (CounterX[9:3]==79) || (CounterY[8:3]==0) || (CounterY[8:3]==59);

//to check if the ball has touched the paddle or a border
wire bouncing_ball = border | paddle | paddle1; // active if the border or paddle is redrawing itself
wire end_touch = border;
wire paddle_touch = paddle |paddle1;

reg reset_collision;
// active only once for every video frame
always @(posedge VGA_clock)
reset_collision <= (CounterY==500) & (CounterX==0);

reg collision_X1, collision_X2, collision_Y1, collision_Y2, top,bottom;
always @(posedge VGA_clock) 
	if(reset_collision) 
		collision_X1<=0; 
	else if(bouncing_ball & (CounterX==ballX) & (CounterY==(ballY+8))) 
		collision_X1<=1;
		
always @(posedge VGA_clock) 
	if(reset_collision) 
		collision_X2<=0; 
	else if(bouncing_ball & (CounterX==(ballX+16)) & (CounterY==(ballY+8))) 
		collision_X2<=1;
		
always @(posedge VGA_clock) 
	if(reset_collision) 
		collision_Y1<=0; 
	else if(paddle_touch & (CounterX==(ballX+8)) & (CounterY==ballY)) 
		collision_Y1<=1;
		
always @(posedge VGA_clock) 
	if(reset_collision) 
		collision_Y2<=0;
	else if(paddle_touch & (CounterX==(ballX+8)) & (CounterY==(ballY+16))) 
		collision_Y2<=1;
		
always @(posedge VGA_clock) 
	if(reset_collision) 
		top<=0; 
	else if(end_touch & (CounterX==(ballX+8)) & (CounterY==ballY)) 
		top<=1;

always @(posedge VGA_clock) 
	if(reset_collision)
		bottom<=0;
	else if(end_touch & (CounterX==(ballX+8)) & (CounterY==(ballY+16))) 
		bottom<=1;


wire new_ball_position = reset_collision;  // update the ball position at the same time that we reset the collision detectors

reg ball_dirX=0;
reg ball_dirY=0;
always @(posedge VGA_clock)
if(new_ball_position)
begin
	if(~(collision_X1 & collision_X2))   
		begin
		if(reset==1)
		ballX<=50;
		else
		ballX <= ballX + (ball_dirX ? -3'b100 : 3'b100);
		if(collision_X2) 
				ball_dirX <= 1;
		else if(collision_X1)
				ball_dirX <= 0;
	end

	if(~(collision_Y1 & collision_Y2))
	begin
	if(reset==1)
	   ballY<=50;
	else if(bottom || top)
		 ballY<=ballY;
	else
	begin
		ballY <= ballY + (ball_dirY ? -3'b100: 3'b100);
		end_game<=1;
		if(reset==1)
		ball_dirY<=0;
		else if(collision_Y2)
				begin
				ball_dirY <= 1;
				colour=~colour;
				end
		else if(collision_Y1)
			begin
			ball_dirY <= 0;
			colour=~colour;
			end
			//colour<=~colour;
		end
	end
end 


/////////////////////////////////////////////////////////////////
assign R = bouncing_ball | ball;
assign G = bouncing_ball| (CounterX[1] ^ CounterY[1]) | ball;
assign B = bouncing_ball | (CounterX[1] ^ CounterY[1]) | ball;

//reg vga_R, vga_G, vga_B;
//shows white color for paddle, ball and border
always @(posedge VGA_clock)
begin
 if(((CounterX==ballX) & ball_inY) && (CounterY==ballY))
	begin
		vga_R <= {7{R}};
		vga_G <= {4{G}};
		vga_B <= {8{B}};
	end
	if(((CounterX>=(bar+8)) && (CounterX<=(bar+120)) && (CounterY[8:4]==27)) || ((CounterX>=(bar1+8)) && (CounterX<=(bar1+120)) && (CounterY[8:4]==3)))
	begin
		vga_R <= {2{R}};
		vga_G <= {8{G}};
		vga_B <= {7{B}};
	end
	else if(CounterX[9:3]==0)
	begin
		vga_R <= {7{R}};
		vga_G <= {0{G}};
		vga_B <= {1{B}};
	end
	else if(CounterX[9:3]==79)
	begin
		vga_R <= {7{R}};
		vga_G <= {0{G}};
		vga_B <= {1{B}};
	end
	else if(CounterY[8:3]==0)
	begin
		vga_R <= {7{R}};
		vga_G <= {8{G}};
		vga_B <= {0{B}};
	end
	else if(CounterY[8:3]==59)
	begin
		vga_R <= {0{R}};
		vga_G <= {8{G}};
		vga_B <= {7{B}};
	end
	else if(colour)
	begin
		vga_R <= {8{R}};
		vga_G <= {10{G}};
		vga_B <= {2{B}};
	end
else
	begin
		vga_R <= {8{R}};
		vga_G <= {8{G}};
		vga_B <= {8{B}};
	end
end
endmodule

 
//clock reduce for vga
module clock_divide(clock, VGA_clock);
	input clock; 			//50MHz clock
	output reg VGA_clock; //25MHz clock
	reg q;

	always@(posedge clock)
	begin
		q <= ~q; 
		VGA_clock <= q;
	end
endmodule


// generates the vga signals
module VGA_gen(VGA_clock, CounterX, CounterY, displayArea, h_sync, v_sync, blank_n);

	input VGA_clock;
	output reg [9:0]CounterX, CounterY; 
	output reg displayArea;  
	output v_sync, h_sync, blank_n;

	reg p_hSync, p_vSync; 
	
	integer porchHF = 640; 	//start of horizantal front porch
	integer syncH = 655;	//start of horizontal sync
	integer porchHB = 747; 	//start of horizontal back porch
	integer maxH = 793; 	//total length of line.

	integer porchVF = 480; 	//start of vertical front porch 
	integer syncV = 490; 	//start of vertical sync
	integer porchVB = 492; 	//start of vertical back porch
	integer maxV = 525; 	//total rows. 

	//scanning horizontally
	always@(posedge VGA_clock)
	begin
		if(CounterX === maxH)
			CounterX <= 0;
		else
			CounterX <= CounterX + 1'b1;
	end

	//scanning vertically	
	always@(posedge VGA_clock)
	begin
		if(CounterX === maxH)
		begin
			if(CounterY === maxV)
				CounterY <= 0;
			else
			CounterY <= CounterY + 1'b1;
		end
	end
	
	
	always@(posedge VGA_clock)
	begin
		displayArea <= ((CounterX < porchHF) && (CounterY < porchVF)); 
	end

	//strips it off the porch signals
	always@(posedge VGA_clock)
	begin
		p_hSync <= ((CounterX >= syncH) && (CounterX < porchHB)); 
		p_vSync <= ((CounterY >= syncV) && (CounterY < porchVB)); 
	end
 
	//we invert the signals because the VGA outputs need to be negative
	assign v_sync = ~p_vSync; 
	assign  h_sync= ~p_hSync;
	assign blank_n = displayArea;
endmodule	


module updateclock(clock, update);
		input clock;
		output reg update;
		reg [21:0] count;
		always @(posedge clock)
			begin
			count <= count + 1'b1;
			if(count == 1777777)
			begin
				update <= ~update;
				count <= 0;
			end
		end
	endmodule