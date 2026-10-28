// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`default_nettype none
/*
 * Unit test for the passive checker. +CASE=0 must pass. Cases 1..5 inject
 * deliberately illegal traffic and must terminate with the specified assertion.
 * This test is never part of the synthesis file list.
 */
module tb_checker_negative;
	reg aclk=0, aresetn=0;
	always #5 aclk=~aclk;
	reg [3:0] awid=0;
	reg [31:0] awaddr=0;
	reg [7:0] awlen=0;
	reg [2:0] awsize=2;
	reg [1:0] awburst=1;
	reg awlock=0;
	reg [3:0] awcache=0;
	reg [2:0] awprot=0;
	reg [3:0] awqos=0, awregion=0;
	reg awvalid=0, awready=1;
	reg [31:0] wdata=32'h12345678;
	reg [3:0] wstrb=4'hf;
	reg wlast=1, wvalid=0, wready=1;
	reg [3:0] bid=0;
	reg [1:0] bresp=0;
	reg bvalid=0, bready=1;
	reg [3:0] arid=1;
	reg [31:0] araddr=0;
	reg [7:0] arlen=1;
	reg [2:0] arsize=2;
	reg [1:0] arburst=1;
	reg arlock=0;
	reg [3:0] arcache=0;
	reg [2:0] arprot=0;
	reg [3:0] arqos=0, arregion=0;
	reg arvalid=0, arready=1;
	reg [3:0] rid=1;
	reg [31:0] rdata=32'h12345678;
	reg [1:0] rresp=0;
	reg rlast=0, rvalid=0, rready=1;
	integer test_case=0;
	axi4_protocol_checker dut(.*);

	initial begin
		if (!$value$plusargs("CASE=%d",test_case)) test_case=0;
		repeat (3) @(negedge aclk);
		aresetn=1;
		@(negedge aclk);
		case (test_case)
			0: begin
				// A complete W burst may legally be accepted before its AW.
				wvalid=1;
				@(negedge aclk); wvalid=0; awvalid=1;
				@(negedge aclk); awvalid=0; bvalid=1;
				@(negedge aclk); bvalid=0; arvalid=1;
				@(negedge aclk); arvalid=0; rvalid=1;
				@(negedge aclk); rlast=1;
				@(negedge aclk); rvalid=0;
				repeat (2) @(negedge aclk);
				$display("CHECKER_POSITIVE_PASS");
				$finish;
			end
			1: begin
				// Expected: burst crosses 4KB boundary or address space end.
				awaddr=32'h00000ffc; awlen=1; awvalid=1;
			end
			2: begin
				// Expected: WLAST disagrees with AWLEN.
				awlen=3; awvalid=1;
				@(negedge aclk); awvalid=0; wvalid=1;
				@(negedge aclk); wvalid=0;
			end
			3: begin
				// Expected: AR changed while stalled.
				arvalid=1; arready=0;
				@(negedge aclk); araddr=4;
			end
			4: begin
				// Expected: B without completed AW/W for ID 0.
				awvalid=1;
				@(negedge aclk); awvalid=0; bvalid=1;
			end
			5: begin
				// Expected: missing WLAST at AWLEN boundary.
				awvalid=1;
				@(negedge aclk); awvalid=0; wvalid=1; wlast=0;
				@(negedge aclk); wvalid=0;
			end
			default: $fatal(1,"Unsupported checker unit test case %0d",test_case);
		endcase
		repeat (5) @(negedge aclk);
		$fatal(1,"NEGATIVE_TEST_NOT_DETECTED case=%0d",test_case);
	end
endmodule
`default_nettype wire
