// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`default_nettype none
/*
 * Passive AXI4 simulation checker. Not synthesizable and not formal proof.
 *
 * AW and completed W bursts use independent queues. This deliberately permits
 * W to precede AW and matches them in AXI4 write-address order (there is no WID).
 * Read queues are per ID, so responses may interleave between different IDs.
 * All bookkeeping observes handshakes; backpressure never consumes a transfer.
 */
module axi4_protocol_checker #(
	parameter integer ADDR_WIDTH=32,
	parameter integer DATA_WIDTH=32,
	parameter integer ID_WIDTH=4,
	parameter integer MAX_OUTSTANDING=64,
	parameter integer CHECK_ID_RESPONSES=1
) (
	input wire aclk, aresetn,
	input wire [ID_WIDTH-1:0] awid,
	input wire [ADDR_WIDTH-1:0] awaddr,
	input wire [7:0] awlen,
	input wire [2:0] awsize,
	input wire [1:0] awburst,
	input wire awlock,
	input wire [3:0] awcache,
	input wire [2:0] awprot,
	input wire [3:0] awqos, awregion,
	input wire awvalid, awready,
	input wire [DATA_WIDTH-1:0] wdata,
	input wire [DATA_WIDTH/8-1:0] wstrb,
	input wire wlast, wvalid, wready,
	input wire [ID_WIDTH-1:0] bid,
	input wire [1:0] bresp,
	input wire bvalid, bready,
	input wire [ID_WIDTH-1:0] arid,
	input wire [ADDR_WIDTH-1:0] araddr,
	input wire [7:0] arlen,
	input wire [2:0] arsize,
	input wire [1:0] arburst,
	input wire arlock,
	input wire [3:0] arcache,
	input wire [2:0] arprot,
	input wire [3:0] arqos, arregion,
	input wire arvalid, arready,
	input wire [ID_WIDTH-1:0] rid,
	input wire [DATA_WIDTH-1:0] rdata,
	input wire [1:0] rresp,
	input wire rlast, rvalid, rready
);
	localparam integer A_BITS=ID_WIDTH+ADDR_WIDTH+8+3+2+1+4+3+4+4;
	localparam integer W_BITS=DATA_WIDTH+DATA_WIDTH/8+1;
	localparam integer R_BITS=ID_WIDTH+DATA_WIDTH+2+1;
	localparam integer NUM_IDS=2**ID_WIDTH;
	wire [A_BITS-1:0] aw_payload={awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awregion};
	wire [A_BITS-1:0] ar_payload={arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,arregion};
	wire [W_BITS-1:0] w_payload={wdata,wstrb,wlast};
	wire [ID_WIDTH+1:0] b_payload={bid,bresp};
	wire [R_BITS-1:0] r_payload={rid,rdata,rresp,rlast};
	reg [A_BITS-1:0] old_aw, old_ar;
	reg [W_BITS-1:0] old_w;
	reg [ID_WIDTH+1:0] old_b;
	reg [R_BITS-1:0] old_r;
	reg aw_stalled=0, w_stalled=0, b_stalled=0, ar_stalled=0, r_stalled=0;
	integer aw_head=0, aw_tail=0, aw_count=0;
	integer w_head=0, w_tail=0, w_count=0, w_beats=0;
	integer aw_beats [0:MAX_OUTSTANDING-1];
	integer aw_ids [0:MAX_OUTSTANDING-1];
	integer complete_w_beats [0:MAX_OUTSTANDING-1];
	integer b_credit [0:NUM_IDS-1];
	integer r_head [0:NUM_IDS-1];
	integer r_tail [0:NUM_IDS-1];
	integer r_count [0:NUM_IDS-1];
	integer r_beats [0:NUM_IDS-1][0:MAX_OUTSTANDING-1];
	integer i, ident;

	// Check the complete burst footprint using one extra carry bit. Unaligned
	// FIXED/INCR starts are legal; only WRAP requires transfer-size alignment.
	task automatic check_address;
		input [ADDR_WIDTH-1:0] addr;
		input [7:0] len;
		input [2:0] size;
		input [1:0] burst;
		reg [ADDR_WIDTH:0] beat_bytes, aligned_addr, span, first_addr, last_addr;
		begin
			if ((^addr===1'bx) || (^len===1'bx) || (^size===1'bx) || (^burst===1'bx))
				$fatal(1,"%m unknown address/control on accepted request");
			beat_bytes=1;
			beat_bytes=beat_bytes << size;
			if (beat_bytes > DATA_WIDTH/8)
				$fatal(1,"%m AxSIZE exceeds data bus width");
			aligned_addr={1'b0,addr} & ~(beat_bytes-1);
			span=beat_bytes * (int'(len)+1);
			first_addr={1'b0,addr};
			last_addr=aligned_addr+beat_bytes-1;
			case (burst)
				2'b00: if (len>15) $fatal(1,"%m FIXED burst exceeds 16 beats");
				2'b01: last_addr=aligned_addr+span-1;
				2'b10: begin
					if (!(len==1 || len==3 || len==7 || len==15))
						$fatal(1,"%m invalid WRAP burst length");
					if (({1'b0,addr} & (beat_bytes-1))!=0)
						$fatal(1,"%m unaligned WRAP start");
					first_addr={1'b0,addr} & ~(span-1);
					last_addr=first_addr+span-1;
				end
				default: $fatal(1,"%m reserved AxBURST encoding");
			endcase
			if (first_addr[ADDR_WIDTH:12] != {1'b0,addr[ADDR_WIDTH-1:12]} ||
				last_addr[ADDR_WIDTH:12] != {1'b0,addr[ADDR_WIDTH-1:12]})
				$fatal(1,"%m burst crosses 4KB boundary or address space end");
		end
	endtask

	always @(posedge aclk) begin
		if (!aresetn) begin
			aw_stalled<=0; w_stalled<=0; b_stalled<=0; ar_stalled<=0; r_stalled<=0;
			aw_head=0; aw_tail=0; aw_count=0;
			w_head=0; w_tail=0; w_count=0; w_beats=0;
			for (i=0; i<NUM_IDS; i=i+1) begin
				b_credit[i]=0; r_head[i]=0; r_tail[i]=0; r_count[i]=0;
			end
		end else begin
			if (aw_stalled && (!awvalid || aw_payload!==old_aw)) $fatal(1,"%m AW changed while stalled");
			if (w_stalled && (!wvalid || w_payload!==old_w)) $fatal(1,"%m W changed while stalled");
			if (b_stalled && (!bvalid || b_payload!==old_b)) $fatal(1,"%m B changed while stalled");
			if (ar_stalled && (!arvalid || ar_payload!==old_ar)) $fatal(1,"%m AR changed while stalled");
			if (r_stalled && (!rvalid || r_payload!==old_r)) $fatal(1,"%m R changed while stalled");
			aw_stalled<=awvalid && !awready; old_aw<=aw_payload;
			w_stalled<=wvalid && !wready; old_w<=w_payload;
			b_stalled<=bvalid && !bready; old_b<=b_payload;
			ar_stalled<=arvalid && !arready; old_ar<=ar_payload;
			r_stalled<=rvalid && !rready; old_r<=r_payload;

			if (awvalid && awready) begin
				check_address(awaddr,awlen,awsize,awburst);
				if (aw_count>=MAX_OUTSTANDING) $fatal(1,"%m checker AW queue exhausted");
				if (^awid===1'bx) $fatal(1,"%m unknown AWID");
				aw_beats[aw_tail]=int'(awlen)+1; aw_ids[aw_tail]=int'(awid);
				aw_tail=(aw_tail+1)%MAX_OUTSTANDING; aw_count=aw_count+1;
			end
			if (wvalid && wready) begin
				w_beats=w_beats+1;
				if (w_beats>256) $fatal(1,"%m W burst exceeds 256 beats or missing WLAST");
				if (wlast) begin
					if (w_count>=MAX_OUTSTANDING) $fatal(1,"%m checker completed-W queue exhausted");
					complete_w_beats[w_tail]=w_beats;
					w_tail=(w_tail+1)%MAX_OUTSTANDING; w_count=w_count+1; w_beats=0;
				end
			end
			// AXI4 W order is exactly AW order, even across distinct AWIDs.
			while (aw_count>0 && w_count>0) begin
				if (aw_beats[aw_head]!=complete_w_beats[w_head])
					$fatal(1,"%m WLAST disagrees with AWLEN: expected %0d observed %0d",aw_beats[aw_head],complete_w_beats[w_head]);
				ident=aw_ids[aw_head];
				if (CHECK_ID_RESPONSES) b_credit[ident]=b_credit[ident]+1;
				aw_head=(aw_head+1)%MAX_OUTSTANDING; aw_count=aw_count-1;
				w_head=(w_head+1)%MAX_OUTSTANDING; w_count=w_count-1;
			end
			// Also detect an absent/late WLAST as soon as the AW length is
			// known, including when the data beat was accepted before AW.
			if (aw_count>0 && w_count==0 && w_beats>=aw_beats[aw_head])
				$fatal(1,"%m missing WLAST at AWLEN boundary");
			if (CHECK_ID_RESPONSES && bvalid) begin
				if (^bid===1'bx) $fatal(1,"%m unknown BID");
				if (b_credit[int'(bid)]==0) $fatal(1,"%m B without completed AW/W for ID %0d",bid);
				if (bready) b_credit[int'(bid)]=b_credit[int'(bid)]-1;
			end
			if (arvalid && arready) begin
				check_address(araddr,arlen,arsize,arburst);
				if (^arid===1'bx) $fatal(1,"%m unknown ARID");
				if (CHECK_ID_RESPONSES) begin
					ident=int'(arid);
					if (r_count[ident]>=MAX_OUTSTANDING) $fatal(1,"%m checker AR queue exhausted");
					r_beats[ident][r_tail[ident]]=int'(arlen)+1;
					r_tail[ident]=(r_tail[ident]+1)%MAX_OUTSTANDING;
					r_count[ident]=r_count[ident]+1;
				end
			end
			if (CHECK_ID_RESPONSES && rvalid) begin
				if (^rid===1'bx) $fatal(1,"%m unknown RID");
				ident=int'(rid);
				if (r_count[ident]==0) $fatal(1,"%m R without accepted AR for ID %0d",rid);
				if (rlast !== (r_beats[ident][r_head[ident]]==1))
					$fatal(1,"%m RLAST disagrees with ARLEN for ID %0d",rid);
				if (rready) begin
					r_beats[ident][r_head[ident]]=r_beats[ident][r_head[ident]]-1;
					if (rlast) begin
						r_head[ident]=(r_head[ident]+1)%MAX_OUTSTANDING;
						r_count[ident]=r_count[ident]-1;
					end
				end
			end
		end
	end
endmodule
`default_nettype wire
