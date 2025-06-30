`include "MAU.v"

module MA #(
parameter data_length=8,
parameter mesh_length=4,
parameter acc_length=32
)(
	// Input
	clk, rst_n, in_image, in_weight, in_weight_load, in_image_load,
	// Output
	out_valid_image, out_valid_weight, out_data
);

// local parameter
parameter in_length = data_length * mesh_length;
parameter out_length = acc_length * mesh_length;

parameter IDLE = 0;
parameter IMAGE_LOAD = 1;
parameter WEIGHT_LOADING = 2;
parameter WEIGHT_LOADED = 3;
parameter IMAGE_OUTPUT = 4;
parameter PROCESSING = 5;
parameter ERROR = 6;
parameter store_unit = mesh_length * (mesh_length-1) / 2;

parameter mesh_length_log2 = (mesh_length == 1) ? 1 : $clog2(mesh_length);

// IO
input 						clk;
input 						rst_n;
input 						in_weight_load;
input 						in_image_load;
input [in_length-1:0] 		in_image,in_weight;

output reg					out_valid_image, out_valid_weight;
output reg [out_length-1:0] out_data;

// Wire & Registers
reg [in_length-1:0]			in_image_buf;
reg							in_image_load_buf;

wire [data_length-1:0] 		din_1_0[0:mesh_length-1];
wire [data_length-1:0] 		din_2_0[0:mesh_length-1];

wire [data_length-1:0]		data1_in[0:mesh_length-1][0:mesh_length];
wire [data_length-1:0]		data1_out[0:mesh_length-1][0:mesh_length];
wire [data_length-1:0]		data2_inout[0:mesh_length][0:mesh_length-1];
	
wire [acc_length-1:0] 		acc_in[0:mesh_length][0:mesh_length-1];
wire [acc_length-1:0] 		acc_out[0:mesh_length][0:mesh_length-1];
	
reg 						valid_image[0:mesh_length];
wire 						valid_image_comb_in[0:mesh_length][0:mesh_length];
wire 						valid_image_comb_out[0:mesh_length][0:mesh_length];
wire 						valid_weight[0:mesh_length][0:mesh_length-1];
wire [mesh_length:0]		valid_image_bundle;
	
reg [acc_length-1:0]		out_SR_store_comb[0:mesh_length-1][0:mesh_length-1];
reg [acc_length-1:0] 		out_SR_store[0:mesh_length-1][0:mesh_length-1];
wire						SR_Store_Head_trig[0:mesh_length-1];
reg [acc_length-1:0]		SR_Store_Head[0:mesh_length-1];

wire [out_length-1:0]		out_SR_store_bundle;
	
reg [out_length-1:0]		out_data_comb;
reg							out_valid_image_comb, out_valid_weight_comb;
	
reg [2:0]					state, state_comb;
wire						both_input;
wire						any_input;

reg	[mesh_length_log2-1:0]	weight_cnt, weight_cnt_comb;
reg	[mesh_length_log2:0]	image_cnt, image_cnt_comb;

wire [data_length-1:0]		weight_store_DFT[0:mesh_length-1][0:mesh_length-1];
wire [acc_length-1:0]		add_result_DFT[0:mesh_length-1][0:mesh_length-1], mult_result_DFT[0:mesh_length-1][0:mesh_length-1];

reg [mesh_length_log2:0] 	out_SR_store_cnt, out_SR_store_cnt_comb;
reg [mesh_length_log2-1:0]	out_SR_release_cnt, out_SR_release_cnt_comb;
//================================================================
// 								FSM
//================================================================
always @ (*) begin
weight_cnt_comb = 'd0;
	if(in_weight_load) 
		weight_cnt_comb = weight_cnt + 'd1;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		weight_cnt <= 'd0;
	else
		weight_cnt <= weight_cnt_comb;
end

always @ (*) begin
image_cnt_comb = 'd0;
	if(in_weight_load) 
		image_cnt_comb = image_cnt + 'd1;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		image_cnt <= 'd0;
	else
		image_cnt <= image_cnt_comb;
end

assign both_input = in_image_load & in_weight_load;
assign any_input = in_image_load | in_weight_load;
always @ (*) begin
	case(state) // sysnopsys full_case
		IDLE		:	begin
							if(in_image_load)
								state_comb = ERROR;
							else if(in_weight_load)
								state_comb = WEIGHT_LOADING;
							else
								state_comb = IDLE;
						end
		IMAGE_LOAD	:	begin
							if(both_input | in_weight_load)
								state_comb = ERROR;
							else if(in_image_load)
								state_comb = IMAGE_LOAD;
							else
								state_comb = PROCESSING;
						end
		WEIGHT_LOADING:	begin
							if(both_input)
								state_comb = ERROR;
							else if(weight_cnt == mesh_length-1)
								state_comb = WEIGHT_LOADED;
							else if(in_weight_load & weight_cnt < mesh_length)
								state_comb = WEIGHT_LOADING;
							else
								state_comb = ERROR;
						end
		WEIGHT_LOADED:	begin
							if(both_input)
								state_comb = ERROR;
							else if(in_image_load)
								state_comb = IMAGE_LOAD;
							else if(in_weight_load)
								state_comb = WEIGHT_LOADING;
							else
								state_comb = WEIGHT_LOADED;
						end
		PROCESSING:		begin
							if(any_input)
								state_comb = ERROR;
							else if(out_SR_store_cnt == 2*mesh_length-2)
								state_comb = IMAGE_OUTPUT;
							else
								state_comb = PROCESSING;
						end
		IMAGE_OUTPUT:	begin
							if(both_input)
								state_comb = ERROR;
							else if(out_SR_release_cnt == mesh_length-1)
								state_comb = WEIGHT_LOADED;
							else
								state_comb = IMAGE_OUTPUT;
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

//================================================================
// 							Input buffer
//================================================================
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		in_image_buf 		<= 'd0;
		in_image_load_buf	<= 'd0;
	end
	else begin
		in_image_buf 		<= in_image;
		in_image_load_buf 	<= in_image_load;
	end
end

genvar i,j;

generate
	for (i=0; i<mesh_length; i=i+1) begin : indata_assignment
		assign din_1_0[i] = in_image_buf[((i+1)*data_length-1):i*data_length];
		assign din_2_0[i] = in_weight[((i+1)*data_length-1):i*data_length];
	end
	
//================================================================
// 							Matrix
//================================================================
	
	// Input Assignment
	for (i=0; i<mesh_length;i=i+1) begin : side_mesh_input_assignment
		// First Row Assigning
		assign	data1_in[i][0] = din_1_0[i];
			
		// First Column Assigning
		assign	data2_inout[0][i] = din_2_0[i];
	end
	
	// Weight Assignment
	for (i=0; i<mesh_length; i=i+1) begin : valid_weight_pin2mesh
		assign	valid_weight[0][i] = in_weight_load;
	end
	
	// First Row valid_image Signal (Shift Register)
	/*
	for (i=0; i<mesh_length; i=i+1) begin : valid_image_pin2mesh
		assign	valid_image[i][0] = in_image_load;
	end
	*/
	
	always @ (*) begin
		valid_image[0] = in_image_load_buf;
	end
	
	for (i=0; i<mesh_length; i=i+1) begin: side_mesh_valid_image_assignment
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				valid_image[i+1] <= 'd0;
			end
			else begin
				valid_image[i+1] <= valid_image[i];
			end
		end
		

		assign	valid_image_comb_in[i][0] = valid_image[i];
	end
	
	for (i=0; i<mesh_length; i=i+1) begin: valid_image_comb_in_assignment_i
		for (j=1; j<mesh_length; j=j+1) begin: valid_image_comb_in_assignment_j
			assign valid_image_comb_in[i][j] = valid_image_comb_out[i][j-1];
			assign data1_in[i][j] = data1_out[i][j-1];
			assign acc_in[j][i] = acc_out	[j-1][i];
		end
	end
	
	// First Column Din signal
	for(i=0; i<mesh_length; i=i+1) begin : side_mesh_acc_assignment
		assign	acc_in[0][i] = 'd0;
	end
	
	
	for (i=0; i<mesh_length; i=i+1) begin : mesh_assignment_i
		for (j=0; j<mesh_length; j=j+1) begin : mesh_assignment_j
			MAU m(clk, rst_n, data1_in[i][j], data2_inout[i][j], valid_weight[i][j], valid_image_comb_in[i][j], acc_in[i][j], 
			valid_weight[i+1][j], valid_image_comb_out[i][j], acc_out[i][j], data1_out[i][j], data2_inout[i+1][j], weight_store_DFT[i][j], mult_result_DFT[i][j], add_result_DFT[i][j]);
		end
	end
	/*
	MAU m_DFT(clk, rst_n, data1_inout[3][0], data2_inout[3][0], valid_weight[3][0], valid_image[3][0], acc_inout[3][0], 
	valid_weight[4][0], valid_image[3][1], acc_inout[4][0], data1_inout[3][1], data2_inout[4][0], weight_store_DFT[3][0]);
		
	for (i=0; i<3; i=i+1) begin : mesh_assignment_i
		for (j=0; j<mesh_length; j=j+1) begin : mesh_assignment_j
			MAU m(clk, rst_n, data1_inout[i][j], data2_inout[i][j], valid_weight[i][j], valid_image[i][j], acc_inout[i][j], 
			valid_weight[i+1][j], valid_image[i][j+1], acc_inout[i+1][j], data1_inout[i][j+1], data2_inout[i+1][j], weight_store_DFT[i][j]);
		end
	end
	for (j=1; j<mesh_length; j=j+1) begin : mesh_assignment_j_2	
		MAU m(clk, rst_n, data1_inout[3][j], data2_inout[3][j], valid_weight[3][j], valid_image[3][j], acc_inout[3][j], 
		valid_weight[4][j], valid_image[3][j+1], acc_inout[4][j], data1_inout[3][j+1], data2_inout[4][j], weight_store_DFT[3][j]);
	end
	*/
	
	//================================================================
	// 							Storing
	//================================================================
	// each shift register have different saving timing 
	for(i=0; i<mesh_length; i=i+1) begin : SR_Store_Head_trig_assignment_i
		assign SR_Store_Head_trig[i] = valid_image_comb_out[i][mesh_length-1] & (out_SR_store_cnt < (mesh_length + i)) & (out_SR_store_cnt >= i);
	end
	
	for(i=0; i<mesh_length; i=i+1) begin : SR_Store_Head_assignment_i
		always @ (*) begin
			SR_Store_Head[i] = out_SR_store[mesh_length-1][i];	
			if(SR_Store_Head_trig[i])
				SR_Store_Head[i] = acc_out[mesh_length-1][i];
			else if(out_valid_image_comb)
				SR_Store_Head[i] = 'd0;
		end
	end
	
	for(j=0; j<mesh_length; j=j+1) begin : out_SR_store_side_assignment_j
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n)
				out_SR_store[mesh_length-1][j] <= 'd0;
			else
				out_SR_store[mesh_length-1][j] <= SR_Store_Head[j];
		end
	end	
	
	for(i=0; i<mesh_length-1; i=i+1) begin : out_SR_store_assignment_i
		for(j=0; j<mesh_length; j=j+1) begin : out_SR_store_assignment_j
			always @ (posedge clk or negedge rst_n) begin
				if(!rst_n)
					out_SR_store[i][j] <= 'd0;
				else begin
					if(SR_Store_Head_trig[j] | out_valid_image_comb)
						out_SR_store[i][j] <= out_SR_store[i+1][j];
					else
						out_SR_store[i][j] <= out_SR_store[i][j];
				end
			end
		end	
	end
	
	for(i=0; i<mesh_length; i=i+1) begin : out_SR_store_bundle_assignment_i
		always @ (*) begin
			if(state == IMAGE_OUTPUT)
				out_data_comb[(i+1)*acc_length-1:i*acc_length] = out_SR_store[0][i];
			else
				out_data_comb[(i+1)*acc_length-1:i*acc_length] = 'd0;
		end
		// assign out_SR_store_bundle[(i+1)*acc_length-1:i*acc_length] = out_SR_store[0][i];
	end
endgenerate

//================================================================
// 							Output
//================================================================
// Image Storing counter
always @ (*) begin
out_SR_store_cnt_comb = 'd0;
	if(valid_image_comb_out[0][mesh_length-1])
		out_SR_store_cnt_comb = out_SR_store_cnt + 'd1;
	else if(out_SR_store_cnt == mesh_length-1)
		out_SR_store_cnt_comb = 'd0;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		out_SR_store_cnt <= 'd0;
	else
		out_SR_store_cnt <= out_SR_store_cnt_comb;
end

// Image Outputing counter
always @ (*) begin
out_SR_release_cnt_comb = 'd0;
	if(state == IMAGE_OUTPUT)
		out_SR_release_cnt_comb = out_SR_release_cnt + 'd1;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		out_SR_release_cnt <= 'd0;
	else
		out_SR_release_cnt <= out_SR_release_cnt_comb;
end

// output data assignment
/*
always @ (*) begin
out_data_comb = 'd0;
	if(state == IMAGE_OUTPUT)
		out_data_comb = out_SR_store_bundle;
end
*/

always @ (*) begin
out_valid_image_comb = 'd0;
	if(state == IMAGE_OUTPUT)
		out_valid_image_comb = 'd1;
end

always @ (*) begin
	out_valid_weight_comb = 'd0;
	if(weight_cnt == mesh_length-1) begin
		out_valid_weight_comb = 'd1;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid_weight <= 'd0;
		out_valid_image <= 'd0;
		out_data <= 'd0;
	end
	else begin
		out_valid_weight <= out_valid_weight_comb;
		out_valid_image <= out_valid_image_comb;
		out_data <= out_data_comb;
	end
end
endmodule