// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_owner_checker_negative;
	reg clk=0;
	always #5 clk=~clk;
	reg rst_n=0, allocate=0, release_owner=0;
	reg [1:0] grant_master=2, owner=0;
	reg [7:0] grant_len=1;
	reg owner_valid=0, wvalid=0, wready=0, wlast=0;
	integer test_case=0;
	axi4_owner_checker dut(.*);
	initial begin
		if (!$value$plusargs("CASE=%d",test_case)) test_case=0;
		repeat(2) @(negedge clk);
		rst_n=1; allocate=1;
		@(negedge clk); allocate=0; owner_valid=1; owner=2;
		wvalid=1; wready=0; wlast=0;
		repeat(4) @(negedge clk);
		if (test_case==1) owner=1;
		if (test_case==2) release_owner=1;
		@(negedge clk); wready=1;
		@(negedge clk); wlast=1; release_owner=1;
		@(negedge clk); wvalid=0; release_owner=0; owner_valid=0;
		repeat(2) @(negedge clk);
		if (test_case!=0) $fatal(1,"OWNER checker failed to detect injected violation");
		$display("OWNER CHECKER LEGAL PASS");
		$finish;
	end
	initial begin #10000; $fatal(1,"OWNER CHECKER watchdog"); end
endmodule
