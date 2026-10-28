`timescale 1ns/1ps
/* Verification-only AXI4 subordinate. Independent AW/B/AR queues let tests
 * withhold responses while many commands are accepted. W follows AW order.
 * Storage is byte addressed; its cursor algorithm is independent of the BFM. */
module axi4_test_slave #(
	parameter integer ID_WIDTH=6, BANK=0, DEPTH=32, WAIT_AW_FOR_W=0,
	parameter integer W_STALL_PERIOD=3, W_STALL_CYCLES=1
)(
	input wire clk, resetn, hold_b, hold_r, stalls, interleave_mode,
	input wire [1:0] response_code,
	input wire [ID_WIDTH-1:0] awid,
	input wire [31:0] awaddr,
	input wire [7:0] awlen,
	input wire [2:0] awsize,
	input wire [1:0] awburst,
	input wire awvalid,
	output wire awready,
	input wire [31:0] wdata,
	input wire [3:0] wstrb,
	input wire wlast, wvalid,
	output wire wready,
	output reg [ID_WIDTH-1:0] bid,
	output reg [1:0] bresp,
	output reg bvalid,
	input wire bready,
	input wire [ID_WIDTH-1:0] arid,
	input wire [31:0] araddr,
	input wire [7:0] arlen,
	input wire [2:0] arsize,
	input wire [1:0] arburst,
	input wire arvalid,
	output wire arready,
	output reg [ID_WIDTH-1:0] rid,
	output reg [31:0] rdata,
	output reg [1:0] rresp,
	output reg rlast, rvalid,
	input wire rready
);
	reg [7:0] mem [0:65535];
	reg [ID_WIDTH-1:0] widq [0:DEPTH-1], bidq [0:DEPTH-1], ridq [0:DEPTH-1];
	reg [31:0] waq [0:DEPTH-1], raq [0:DEPTH-1], wsq [0:DEPTH-1], rsq [0:DEPTH-1];
	integer wlq [0:DEPTH-1], rlq [0:DEPTH-1], wsizeq [0:DEPTH-1], rsizeq [0:DEPTH-1];
	integer wburstq [0:DEPTH-1], rburstq [0:DEPTH-1], wbq [0:DEPTH-1], rbq [0:DEPTH-1];
	reg [1:0] bcq [0:DEPTH-1], rcq [0:DEPTH-1];
	integer wh, wt, wc, bh, bt, bc, rh, rt, rc;
	integer cycle, n, lane, addr_lane;
	function automatic [31:0] advance(input [31:0] current_addr, input [31:0] start,
		input integer len, size, burst);
		reg [31:0] following, floor_addr, span;
		begin
			following=((current_addr>>size)+1)<<size;
			span=(len+1)<<size; floor_addr=start&~(span-1);
			if (burst==0) advance=current_addr;
			else if (burst==2 && following==floor_addr+span) advance=floor_addr;
			else advance=following;
		end
	endfunction
	initial for (n=0; n<65536; n=n+1) mem[n]=0;
	// A legal subordinate may wait for WVALID before accepting AW. This option
	// detects fabrics that incorrectly gate WVALID with downstream AWREADY.
	assign awready=resetn && wc<DEPTH-1 && (!WAIT_AW_FOR_W || wvalid) && (!stalls || (cycle+BANK)%4!=0);
	assign wready=resetn && wc>0 && bc<DEPTH-1 && (!stalls || (cycle+BANK)%W_STALL_PERIOD>=W_STALL_CYCLES);
	assign arready=resetn && rc<DEPTH-1 && (!stalls || (cycle+BANK)%5!=0);
	/* Blocking FIFO bookkeeping deliberately handles simultaneous push/pop in
	 * one occupancy value. Payload outputs use nonblocking assignments. */
	always @(posedge clk) begin
		if (!resetn) begin
			wh=0; wt=0; wc=0; bh=0; bt=0; bc=0; rh=0; rt=0; rc=0; cycle=0;
			bid<=0; bresp<=0; bvalid<=0; rid<=0; rdata<=0; rresp<=0; rlast<=0; rvalid<=0;
		end else begin
			cycle=cycle+1;
			if (bvalid && bready) bvalid<=0;
			if (!bvalid && !hold_b && bc>0) begin
				bid<=bidq[bh]; bresp<=bcq[bh]; bvalid<=1; bh=(bh+1)%DEPTH; bc=bc-1;
			end
			if (rvalid && rready) begin
				rvalid<=0;
				if (rlast) begin rh=(rh+1)%DEPTH; rc=rc-1; end
				else begin
					rbq[rh]=rbq[rh]+1; raq[rh]=advance(raq[rh],rsq[rh],rlq[rh],rsizeq[rh],rburstq[rh]);
					/* Dedicated interleave test uses unique downstream IDs only.
					 * Rotate a partial descriptor behind its peers after each beat. */
					if(interleave_mode && rc>1) begin
						ridq[rt]=ridq[rh]; raq[rt]=raq[rh]; rsq[rt]=rsq[rh]; rlq[rt]=rlq[rh];
						rsizeq[rt]=rsizeq[rh]; rburstq[rt]=rburstq[rh]; rbq[rt]=rbq[rh]; rcq[rt]=rcq[rh];
						rt=(rt+1)%DEPTH; rh=(rh+1)%DEPTH;
					end
				end
			end
			if (!rvalid && !hold_r && rc>0 && (!stalls || (cycle+BANK)%3!=1)) begin
				rid<=ridq[rh]; rresp<=rcq[rh]; rlast<=(rbq[rh]==rlq[rh]); rvalid<=1;
				addr_lane=raq[rh]&16'hfffc;
				rdata<={mem[addr_lane+3],mem[addr_lane+2],mem[addr_lane+1],mem[addr_lane]};
			end
			if (awvalid && awready) begin
				widq[wt]=awid; waq[wt]=awaddr; wsq[wt]=awaddr; wlq[wt]=awlen;
				wsizeq[wt]=awsize; wburstq[wt]=awburst; wbq[wt]=0; wt=(wt+1)%DEPTH; wc=wc+1;
			end
			if (wvalid && wready) begin
				if (wlast !== (wbq[wh]==wlq[wh])) $fatal(1,"Slave %0d WLAST/order mismatch",BANK);
				addr_lane=waq[wh]&16'hfffc;
				for (lane=0; lane<4; lane=lane+1) if (wstrb[lane]) mem[addr_lane+lane]=wdata[lane*8+:8];
				if (wlast) begin
					bidq[bt]=widq[wh]; bcq[bt]=response_code; bt=(bt+1)%DEPTH; bc=bc+1; wh=(wh+1)%DEPTH; wc=wc-1;
				end else begin wbq[wh]=wbq[wh]+1; waq[wh]=advance(waq[wh],wsq[wh],wlq[wh],wsizeq[wh],wburstq[wh]); end
			end
			if (arvalid && arready) begin
				ridq[rt]=arid; raq[rt]=araddr; rsq[rt]=araddr; rlq[rt]=arlen;
				rsizeq[rt]=arsize; rburstq[rt]=arburst; rbq[rt]=0; rcq[rt]=response_code; rt=(rt+1)%DEPTH; rc=rc+1;
			end
		end
	end
endmodule

