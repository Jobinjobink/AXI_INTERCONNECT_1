// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_owner_table;
	reg clk=0;
	always #5 clk=~clk;
	reg rst_n=0, allocate=0, release_owner=0;
	reg [1:0] master=0;
	wire valid;
	wire [1:0] owner;
	axi_write_owner_table dut(.*);
	task automatic cycle(input bit reset_value, alloc, rel, input [1:0] who,
		input bit expect_valid, input [1:0] expect_owner);
		begin
			@(negedge clk); rst_n=reset_value; allocate=alloc; release_owner=rel; master=who;
			@(posedge clk); #1;
			if (valid !== expect_valid || owner !== expect_owner)
				$fatal(1,"OWNER TABLE state mismatch valid=%b owner=%0d expected=%b/%0d",valid,owner,expect_valid,expect_owner);
		end
	endtask
	integer i;
	initial begin
		cycle(0,0,0,0,0,0);
		cycle(1,1,0,2,1,2);
		// Changing incoming requests cannot change an allocated entry.
		for (i=0;i<16;i=i+1) cycle(1,0,0,2'(i),1,2);
		cycle(1,0,1,0,0,2);
		cycle(1,1,0,3,1,3);
		// Defined primitive semantics; crossbar scheduling does not overwrite
		// a live entry, even though the primitive supports this simultaneous case.
		cycle(1,1,1,1,1,1);
		cycle(0,1,1,3,0,0);
		cycle(1,1,0,0,1,0);
		cycle(1,0,1,3,0,0);
		$display("OWNER TABLE PASS allocation hold release priority reset recovery");
		$finish;
	end
	initial begin #10000; $fatal(1,"OWNER TABLE watchdog"); end
endmodule
