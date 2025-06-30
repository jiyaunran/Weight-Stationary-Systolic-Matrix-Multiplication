//=======================================================
//				Matrix Accumulation Unit
//=======================================================
module MAU #(
parameter data_length = 8,
parameter acc_length = 32
)(
	// input
	clk, rst_n, in_image, in_weight, in_weight_load, in_image_load, acc_in,
	// output
	out_weight_load, out_image_load, acc_out, out_image, out_weight,
	// DFT
	weight_store_DFT, mult_result_DFT, add_result_DFT
);

// Local parameter
parameter IDLE = 0;
parameter LOAD_IMAGE = 1;
parameter LOAD_WEIGHT = 2;
parameter ERROR = 3;

// IO
input 							clk;
input 							rst_n;
input 							in_weight_load, in_image_load;
input [data_length-1:0] 		in_image, in_weight;
input [acc_length-1:0] 			acc_in;

output reg 						out_image_load, out_weight_load;
output reg [data_length-1:0] 	out_image, out_weight;
output reg [acc_length-1:0] 	acc_out;
output reg [data_length-1:0]	weight_store_DFT;
output reg [acc_length-1:0]		mult_result_DFT, add_result_DFT;
// Wire & Reg
wire signed	[acc_length-1:0]	add_in1, add_in2, add_out;
reg signed [acc_length-1:0] 	mult_result;
reg signed [data_length-1:0] 	mult_in1, mult_in2;
reg [data_length-1:0]			weight_store;
reg [data_length-1:0]			weight_store_comb;
reg [data_length-1:0] 			out_image_comb, out_weight_comb;
reg [acc_length-1:0] 			acc_out_comb;
reg 							out_weight_load_comb, out_image_load_comb;
reg [1:0]						state;


reg [1:0]						state_comb;
wire							both_input;

// FSM
assign both_input = in_image_load & in_weight_load;
always @ (*) begin
	case(state) // sysnopsys full_case
		IDLE		:	begin
							if(both_input)
								state_comb = ERROR;
							else if(in_weight_load)
								state_comb = LOAD_WEIGHT;
							else
								state_comb = IDLE;
						end
		LOAD_IMAGE	:	begin
							if(both_input)
								state_comb = ERROR;
							else if(!in_image_load)
								state_comb = LOAD_WEIGHT;
							else
								state_comb = LOAD_IMAGE;
						end
		LOAD_WEIGHT	:	begin
							if(both_input)
								state_comb = ERROR;
							else if(in_image_load)
								state_comb = LOAD_IMAGE;
							else
								state_comb = LOAD_WEIGHT;
						end
		ERROR	:		state_comb = IDLE;
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else 
		state <= state_comb;
end

// Input assignment
always @ (*) begin
	if(in_weight_load)
		weight_store_comb = in_weight;
	else
		weight_store_comb = weight_store;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		weight_store <= 'd0;
	else
		weight_store <= weight_store_comb;
end

// Adder
assign add_in1 = mult_result;
assign add_in2 = acc_in;
assign add_out = add_in1 + add_in2;

// Multiplication
always @ (*) begin
	acc_out_comb = 'd0;
	
	mult_in1 = in_image;
	mult_in2 = weight_store;
	
	mult_result = mult_in1 * mult_in2;
	
	if((state == LOAD_WEIGHT | state == LOAD_IMAGE) & in_image_load) begin
		acc_out_comb = add_out;
	end
end

// IO Assignment
always @ (*) begin
out_image_load_comb = 'd0;

	if(in_image_load)
		out_image_load_comb = 'd1;
end

always @ (*) begin
out_image_comb = 'd0;

	if(in_image_load) 
		out_image_comb = in_image;
end

always @ (*) begin
out_weight_load_comb = 'd0;
	if(state == LOAD_WEIGHT && in_weight_load)
		out_weight_load_comb = 'd1;
end

always @ (*) begin
out_weight_comb = 'd0;
	if(state == LOAD_WEIGHT && in_weight_load)
		out_weight_comb = weight_store;
end


always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_image <= 'd0;
		out_weight <= 'd0;
		out_image_load <= 'd0;
		out_weight_load <= 'd0;
		acc_out <= 'd0;
	end
	else begin
		out_image <= out_image_comb;
		out_weight <= out_weight_comb;
		out_image_load <= out_image_load_comb;
		out_weight_load <= out_weight_load_comb;
		acc_out <= acc_out_comb;
	end
end

// DFT
always @ (*) begin
	weight_store_DFT = weight_store;
	add_result_DFT = add_out;
	mult_result_DFT = mult_result;
end

endmodule