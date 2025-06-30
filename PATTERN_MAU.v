`define CYCLE_TIME  20.0
`define PATTERN_NUM  100

module PATTERN_MAU #(
parameter data_length=8,
parameter mesh_length=4,
parameter acc_length=32
)(
	// Output
	clk, rst_n, in_image, in_weight, in_weight_load, in_image_load, acc_in,
	// Input
	out_weight_load, out_image_load, acc_out, out_image, out_weight
);

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter 	in_length = data_length * mesh_length;
parameter 	out_length = acc_length * mesh_length;

parameter	LOAD_WEIGHT = 0;
parameter	LOAD_IMAGE  = 1;

// IO
output reg 						clk;
output reg 						rst_n;
output reg [data_length-1:0]	in_image, in_weight;
output reg [acc_length-1:0] 	acc_in;
output reg 						in_weight_load, in_image_load;
	
input[acc_length-1:0] 			acc_out;
input[data_length-1:0] 			out_image, out_weight;
input 							out_weight_load, out_image_load;
		
reg signed [data_length-1:0] 	image_random, weight_random;
reg [data_length-1:0] 			weight_store;
reg [data_length-1:0] 			image_store;
reg signed [acc_length-1:0]  	acc_in_random;
reg								action;

integer i_pat;
integer N_PAT = `PATTERN_NUM;
integer latency, total_latency;
integer i,j,k,a,x,y;

integer Golden_answer;

real CYCLE = `CYCLE_TIME;
//---------------------------------------------------------------------
//   Verification
//---------------------------------------------------------------------
always # (CYCLE/2.0) clk = ~clk;

initial begin
	reset_signal_task;
	
	i_pat = 0;
	total_latency = 0;
	input_weight_task;
	for(i_pat=0; i_pat<N_PAT; i_pat=i_pat+1) begin
		input_task;
		wait_outvalid_task;
		check_ans_task;
		total_latency = total_latency + latency;
		$display("PASS PATTERN NO.%4d", i_pat);
	end
	YOU_PASS_task;
end

//---------------------------------------------------------------------
//   Task
//---------------------------------------------------------------------
task reset_signal_task; begin
	rst_n = 'd1;
	in_weight_load = 'd0;
	in_image_load = 'd0;
	
	in_image = 'dx;
	in_weight = 'dx;
	acc_in   = 'dx;
	
	total_latency = 'd0;
	force clk = 0;
	
	#CYCLE;		rst_n = 'd0;
	#(CYCLE*2); rst_n = 'd1;
	
	if(acc_out!== 'd0 | out_image !== 'd0 | out_weight !== 'd0 | out_image_load !== 'd0 | out_weight_load !== 'd0) begin
		$display("----------------------------------------------------------------------------------------");
        $display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
        $display("    ▄▀            ▀▄      ▄▄                                          ");
        $display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
        $display("    █   ▀▀            ▀▀▀   ▀▄  ╭  Output signal should be 0 after RESET  at %8t", $time);
        $display("    █  ▄▀▀▀▄                 █  ╭                                        ");
        $display("    ▀▄                       █                                           ");
        $display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
        $display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
        $display("----------------------------------------------------------------------------------------");
        repeat(2) #CYCLE;
        $finish;
	end
	
	#CYCLE; release clk;	
end endtask

task input_weight_task; begin
	repeat ($random() % 5 + 1) @(negedge clk);
	in_weight_load = 'd1;
	
	weight_random = $random();
	weight_store = weight_random;
	in_weight = weight_random;
	
	@(negedge clk);
	
	in_weight = weight_random;
	
	@(negedge clk);
	
end endtask

task input_task; begin
	repeat ($random() % 5 + 1) @(negedge clk);
	action = $random();
	if(action == LOAD_IMAGE) begin
		in_weight_load = 'd0;
		in_weight = 'd0;
		
		in_image_load = 'd1;
		image_random = $random();
		in_image = image_random;
		
		acc_in_random = $random();
		acc_in = acc_in_random;
	end
	else begin
		in_image_load = 'd0;
		in_image = 'd0;
		
		in_weight_load = 'd1;
		weight_random = $random();
		in_weight = weight_random;
		
		acc_in_random = 'd0;
		acc_in = 'd0;
	end
	
	
	@(negedge clk);
	in_weight_load = 'd0;
	in_weight = 'd0;
	
	in_image_load = 'd0;
	in_image = 'd0;
	
	acc_in = 'd0;
	
end endtask

task wait_outvalid_task; begin
	latency = 0;
	while(out_image_load !== 1 & out_weight_load !== 1) begin
		latency = latency + 1;
		if(acc_out!== 'd0 | out_image !== 'd0 | out_weight !== 'd0) begin
			$display("--------------------------------------------------------------------------------");
            $display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
            $display("    ▄▀            ▀▄      ▄▄                                          ");
            $display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
            $display("    █   ▀▀            ▀▀▀   ▀▄  ╭   The output should remain 0 until out_valid go high");
            $display("    █  ▄▀▀▀▄                 █  ╭                                        ");
            $display("    ▀▄                       █                                           ");
            $display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
            $display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
            $display("--------------------------------------------------------------------------------");
			repeat(2)@(negedge clk);
			$finish;
		end
		if(latency == 500) begin
			$display("--------------------------------------------------------------------------------");
            $display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
            $display("    ▄▀            ▀▄      ▄▄                                          ");
            $display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
            $display("    █   ▀▀            ▀▀▀   ▀▄  ╭   The execution cycles are over %3d\033[m", 10000);
            $display("    █  ▄▀▀▀▄                 █  ╭                                        ");
            $display("    ▀▄                       █                                           ");
            $display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
            $display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
            $display("--------------------------------------------------------------------------------");
			repeat(2)@(negedge clk);
			$finish;
		end
		@(negedge clk);
	end
	if(action === LOAD_IMAGE & out_weight_load) begin
		$display("--------------------------------------------------------------------------------");
		$display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
		$display("    ▄▀            ▀▄      ▄▄                                          ");
		$display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
		$display("    █   ▀▀            ▀▀▀   ▀▄  ╭   WRONG Out_valid go high");
		$display("    █  ▄▀▀▀▄                 █  ╭                                        ");
		$display("    ▀▄                       █                                           ");
		$display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
		$display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
		$display("--------------------------------------------------------------------------------");
		repeat(2)@(negedge clk);
		$finish;
	end
	else if(action === LOAD_WEIGHT & out_image_load) begin
		$display("--------------------------------------------------------------------------------");
		$display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
		$display("    ▄▀            ▀▄      ▄▄                                          ");
		$display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
		$display("    █   ▀▀            ▀▀▀   ▀▄  ╭   WRONG Out_valid go high");
		$display("    █  ▄▀▀▀▄                 █  ╭                                        ");
		$display("    ▀▄                       █                                           ");
		$display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
		$display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
		$display("--------------------------------------------------------------------------------");
		repeat(2)@(negedge clk);
		$finish;
	end
	
end endtask

task check_ans_task; begin
// ===============================================================
// 							Calcuate ans
// ===============================================================
	Golden_answer = image_random * weight_random + acc_in_random;
	if(action == LOAD_IMAGE) begin
		if (acc_out !== Golden_answer) begin
			$display("--------------------------------------------------------------------------------");
			$display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
			$display("    ▄▀            ▀▄       ▄▄                                          ");
			$display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
			$display("    █   ▀▀            ▀▀▀   ▀▄  ╭   WRONG ANSWER!! Your value: %d, GOLDEN ANSWER: %d",acc_out,Golden_answer);
			$display("    █  ▄▀▀▀▄                 █  ╭                                        ");
			$display("    ▀▄                       █                                           ");
			$display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
			$display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
			$display("--------------------------------------------------------------------------------");
			repeat(20)@(negedge clk);
			$finish;
		end
		
		if (out_image !== image_random) begin
			$display("--------------------------------------------------------------------------------");
			$display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
			$display("    ▄▀            ▀▄       ▄▄                                          ");
			$display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
			$display("    █   ▀▀            ▀▀▀   ▀▄  ╭   WRONG IMAGE OUTPUT!! Your value: %d, GOLDEN ANSWER: %d",out_image,image_random);
			$display("    █  ▄▀▀▀▄                 █  ╭                                        ");
			$display("    ▀▄                       █                                           ");
			$display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
			$display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
			$display("--------------------------------------------------------------------------------");
			repeat(20)@(negedge clk);
			$finish;
		end
	end
	else begin
		if (out_weight !== weight_store) begin
			$display("--------------------------------------------------------------------------------");
			$display("     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                   ");
			$display("    ▄▀            ▀▄       ▄▄                                          ");
			$display("    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            ");
			$display("    █   ▀▀            ▀▀▀   ▀▄  ╭   WRONG WEIGHT OUTPUT!! Your value: %d, GOLDEN ANSWER: %d",out_weight,weight_store);
			$display("    █  ▄▀▀▀▄                 █  ╭                                        ");
			$display("    ▀▄                       █                                           ");
			$display("     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           ");
			$display("     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            ");
			$display("--------------------------------------------------------------------------------");
			repeat(20)@(negedge clk);
			$finish;
		end
		weight_store = weight_random;
	end
	@(negedge clk);
	
end endtask
task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end endtask
endmodule