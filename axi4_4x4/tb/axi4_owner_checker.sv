// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`default_nettype none
/* Verification-only observer of one real per-target owner table entry.
 * Observe the pre-output-register boundary. Allocation occurs from a valid
 * AW grant, even before AW handshake, so W-before-AW-acceptance is legal.
 * Functional memory and external-ID scoreboards remain independent checks.
 */
module axi4_owner_checker #(
	parameter integer MW=2,
	parameter integer TARGET=0
)(
	input wire clk, rst_n,
	input wire allocate, release_owner,
	input wire [MW-1:0] grant_master,
	input wire [7:0] grant_len,
	input wire owner_valid,
	input wire [MW-1:0] owner,
	input wire wvalid, wready, wlast
);
	reg expected_valid=0;
	reg [MW-1:0] expected_owner=0;
	integer beats_left=0;
	integer allocations=0, completed=0, stalled_cycles=0;
	always @(posedge clk) begin
		if (!rst_n) begin expected_valid=0; expected_owner=0; beats_left=0; end
		else begin
			if (owner_valid !== expected_valid)
				$fatal(1,"OWNER target=%0d valid differs from allocation/release history",TARGET);
			if (expected_valid && owner !== expected_owner)
				$fatal(1,"OWNER target=%0d changed before accepted WLAST",TARGET);
			if (wvalid && !owner_valid)
				$fatal(1,"OWNER target=%0d WVALID without owner",TARGET);
			if (release_owner !== (wvalid && wready && wlast))
				$fatal(1,"OWNER target=%0d release without accepted WLAST",TARGET);
			if (wvalid && !wready) stalled_cycles=stalled_cycles+1;
			if (wvalid && wready) begin
				if (beats_left<=0 || wlast !== (beats_left==1))
					$fatal(1,"OWNER target=%0d WLAST inconsistent with allocated AWLEN",TARGET);
				beats_left=beats_left-1;
			end
			if (allocate) begin
				if (expected_valid)
					$fatal(1,"OWNER target=%0d allocated over a live burst",TARGET);
				expected_valid=1;
				expected_owner=grant_master;
				beats_left=int'(grant_len)+1;
				allocations=allocations+1;
			end else if (release_owner) begin
				expected_valid=0;
				completed=completed+1;
			end
		end
	end
endmodule
`default_nettype wire
