`timescale 1ns/1ps
// PATTERN
`include "PATTERN_MA.v"
// DESIGN
`include "MA.v"

module TESTBED_MA();

parameter data_length=8;
parameter mesh_length=16;
parameter acc_length=32;

parameter 	in_length = data_length * mesh_length;
parameter 	out_length = acc_length * mesh_length;

wire clk, rst_n;
wire [in_length-1:0] in_image, in_weight;
wire in_weight_load, in_image_load;

wire out_valid_image, out_valid_weight;
wire [out_length-1:0] out_data;

initial begin
	$dumpfile("MA.wlf");
	$dumpvars(0, "TESTBED_MA");
end	

MA #(.data_length(data_length), .mesh_length(mesh_length), .acc_length(acc_length)) I_MA(
	// Input
	.clk(clk), 
	.rst_n(rst_n), 
	.in_image(in_image), 
	.in_weight(in_weight), 
	.in_weight_load(in_weight_load), 
	.in_image_load(in_image_load),
	// Output
	.out_valid_image(out_valid_image), 
	.out_valid_weight(out_valid_weight), 
	.out_data(out_data)
);

PATTERN_MA #(.data_length(data_length), .mesh_length(mesh_length), .acc_length(acc_length)) I_PATTERN_MA(
	// Output
	.clk(clk), 
	.rst_n(rst_n), 
	.in_image(in_image), 
	.in_weight(in_weight), 
	.in_weight_load(in_weight_load), 
	.in_image_load(in_image_load),
	// Input
	.out_valid_image(out_valid_image), 
	.out_valid_weight(out_valid_weight), 
	.out_data(out_data)
);

endmodule