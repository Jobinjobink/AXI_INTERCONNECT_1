/*
 * Mini-SoC AXI4 4x4 nonblocking crossbar integration.
 *
 * Naming follows your original axi4_interconnect_4x4.sv:
 *   m_* connects CPU[0], DMA[1], GPU[2], NPU[3] (external AXI masters).
 *   s_* connects DDR[0], SRAM[1], APB bridge[2], accelerator[3] (AXI slaves).
 * The upstream library names its ports from the interconnect perspective,
 * so library s_axi_* maps to our m_*, and library m_axi_* maps to our s_*.
 *
 * All four different targets can transfer simultaneously. Read and write
 * fabrics are independent. Source IDs become {master_index[1:0], source_id}
 * at targets, then lose the two routing bits on the return path.
 *
 * A thread (one ID and direction) stays pinned to one target until its
 * outstanding count drains; this preserves same-ID response ordering.
 * Different IDs may target different slaves and complete out of order.
 * W has no ID in AXI4: AW routing decisions determine W ownership through
 * WLAST. An early WVALID is safe and may be backpressured until AW is known.
 *
 * Core RTL: Alex Forencich/verilog-axi, MIT, locally patched under rtl/vendor/.
 * Custom wrapper and verification: MIT. See docs/ARCHITECTURE.md.
 * Single clock domain. aresetn is sampled synchronously at rising aclk.
 */
`timescale 1ns/1ps
`default_nettype none
module axi4_interconnect_4x4 #(
	parameter integer ID_WIDTH = 4,
	parameter integer DATA_WIDTH = 32,
	parameter integer ADDR_WIDTH = 32,
	// Per external master, per direction: active IDs and admitted transactions.
	parameter integer THREADS = 4,
	parameter integer ACCEPT = 8,
	// Per external slave, per direction: issued transactions waiting for completion.
	parameter integer ISSUE = 8,
	// Entry 0 is the least significant packed field. Regions must not overlap.
	parameter [4*ADDR_WIDTH-1:0] M_BASE_ADDR = {
		ADDR_WIDTH'(32'h3000_0000), ADDR_WIDTH'(32'h2000_0000),
		ADDR_WIDTH'(32'h1000_0000), ADDR_WIDTH'(32'h0000_0000)},
	// Region size is 2**width bytes. Zero disables a target. Minimum enabled=12.
	parameter [127:0] M_ADDR_WIDTH = {32'd16,32'd16,32'd16,32'd28},
	// Bit [slave*4+master] permits the corresponding path.
	parameter [15:0] CONNECT_READ = 16'hffff,
	parameter [15:0] CONNECT_WRITE = 16'hffff,
	// Bit i rejects nonsecure accesses (AxPROT[1]=1) to external slave i.
	parameter [3:0] SECURE = 4'b0000
) (
	input  wire aclk,
	input  wire aresetn,
	input  wire [3:0][ID_WIDTH-1:0]  m_awid,
	input  wire [3:0][ADDR_WIDTH-1:0]  m_awaddr,
	input  wire [3:0][7:0]  m_awlen,
	input  wire [3:0][2:0]  m_awsize,
	input  wire [3:0][1:0]  m_awburst,
	input  wire [3:0] m_awlock,
	input  wire [3:0][3:0]  m_awcache,
	input  wire [3:0][2:0]  m_awprot,
	input  wire [3:0][3:0]  m_awqos,
	input  wire [3:0][3:0]  m_awregion,
	input  wire [3:0] m_awvalid,
	output wire [3:0] m_awready,
	input  wire [3:0][DATA_WIDTH-1:0]  m_wdata,
	input  wire [3:0][DATA_WIDTH/8-1:0]  m_wstrb,
	input  wire [3:0] m_wlast,
	input  wire [3:0] m_wvalid,
	output wire [3:0] m_wready,
	output wire [3:0][ID_WIDTH-1:0]  m_bid,
	output wire [3:0][1:0]  m_bresp,
	output wire [3:0] m_bvalid,
	input  wire [3:0] m_bready,
	input  wire [3:0][ID_WIDTH-1:0]  m_arid,
	input  wire [3:0][ADDR_WIDTH-1:0]  m_araddr,
	input  wire [3:0][7:0]  m_arlen,
	input  wire [3:0][2:0]  m_arsize,
	input  wire [3:0][1:0]  m_arburst,
	input  wire [3:0] m_arlock,
	input  wire [3:0][3:0]  m_arcache,
	input  wire [3:0][2:0]  m_arprot,
	input  wire [3:0][3:0]  m_arqos,
	input  wire [3:0][3:0]  m_arregion,
	input  wire [3:0] m_arvalid,
	output wire [3:0] m_arready,
	output wire [3:0][ID_WIDTH-1:0]  m_rid,
	output wire [3:0][DATA_WIDTH-1:0]  m_rdata,
	output wire [3:0][1:0]  m_rresp,
	output wire [3:0] m_rlast,
	output wire [3:0] m_rvalid,
	input  wire [3:0] m_rready,
	output wire [3:0][ID_WIDTH+1:0]  s_awid,
	output wire [3:0][ADDR_WIDTH-1:0]  s_awaddr,
	output wire [3:0][7:0]  s_awlen,
	output wire [3:0][2:0]  s_awsize,
	output wire [3:0][1:0]  s_awburst,
	output wire [3:0] s_awlock,
	output wire [3:0][3:0]  s_awcache,
	output wire [3:0][2:0]  s_awprot,
	output wire [3:0][3:0]  s_awqos,
	output wire [3:0][3:0]  s_awregion,
	output wire [3:0] s_awvalid,
	input  wire [3:0] s_awready,
	output wire [3:0][DATA_WIDTH-1:0]  s_wdata,
	output wire [3:0][DATA_WIDTH/8-1:0]  s_wstrb,
	output wire [3:0] s_wlast,
	output wire [3:0] s_wvalid,
	input  wire [3:0] s_wready,
	input  wire [3:0][ID_WIDTH+1:0]  s_bid,
	input  wire [3:0][1:0]  s_bresp,
	input  wire [3:0] s_bvalid,
	output wire [3:0] s_bready,
	output wire [3:0][ID_WIDTH+1:0]  s_arid,
	output wire [3:0][ADDR_WIDTH-1:0]  s_araddr,
	output wire [3:0][7:0]  s_arlen,
	output wire [3:0][2:0]  s_arsize,
	output wire [3:0][1:0]  s_arburst,
	output wire [3:0] s_arlock,
	output wire [3:0][3:0]  s_arcache,
	output wire [3:0][2:0]  s_arprot,
	output wire [3:0][3:0]  s_arqos,
	output wire [3:0][3:0]  s_arregion,
	output wire [3:0] s_arvalid,
	input  wire [3:0] s_arready,
	input  wire [3:0][ID_WIDTH+1:0]  s_rid,
	input  wire [3:0][DATA_WIDTH-1:0]  s_rdata,
	input  wire [3:0][1:0]  s_rresp,
	input  wire [3:0] s_rlast,
	input  wire [3:0] s_rvalid,
	output wire [3:0] s_rready
);

	/* Synchronous active-high reset expected by the library. Reset the whole
	 * connected AXI domain together; a reset discards in-flight transactions. */
	wire rst = !aresetn;

	/* The library contains independent read/write fabrics, per-target round
	 * robin arbiters, ID thread admission control, and local DECERR sinks.
	 * Address/W output and B/R return registers use the upstream defaults.
	 * They add elastic storage; ACCEPT/ISSUE count core admissions rather
	 * than every request that can reside in those boundary registers. */
	axi_crossbar #(
		.S_COUNT(4), .M_COUNT(4),
		.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
		.STRB_WIDTH(DATA_WIDTH/8),
		.S_ID_WIDTH(ID_WIDTH), .M_ID_WIDTH(ID_WIDTH+2),
		.S_THREADS({4{32'(THREADS)}}),
		.S_ACCEPT({4{32'(ACCEPT)}}),
		.M_ISSUE({4{32'(ISSUE)}}),
		.M_REGIONS(1), .M_BASE_ADDR(M_BASE_ADDR),
		.M_ADDR_WIDTH(M_ADDR_WIDTH),
		.M_CONNECT_READ(CONNECT_READ), .M_CONNECT_WRITE(CONNECT_WRITE),
		.M_SECURE(SECURE)
	) crossbar (
		.clk(aclk), .rst(rst),
		.s_axi_awid(m_awid),
		.s_axi_awaddr(m_awaddr),
		.s_axi_awlen(m_awlen),
		.s_axi_awsize(m_awsize),
		.s_axi_awburst(m_awburst),
		.s_axi_awlock(m_awlock),
		.s_axi_awcache(m_awcache),
		.s_axi_awprot(m_awprot),
		.s_axi_awqos(m_awqos),
		.s_axi_awvalid(m_awvalid),
		.s_axi_awready(m_awready),
		.s_axi_wdata(m_wdata),
		.s_axi_wstrb(m_wstrb),
		.s_axi_wlast(m_wlast),
		.s_axi_wvalid(m_wvalid),
		.s_axi_wready(m_wready),
		.s_axi_bid(m_bid),
		.s_axi_bresp(m_bresp),
		.s_axi_bvalid(m_bvalid),
		.s_axi_bready(m_bready),
		.s_axi_arid(m_arid),
		.s_axi_araddr(m_araddr),
		.s_axi_arlen(m_arlen),
		.s_axi_arsize(m_arsize),
		.s_axi_arburst(m_arburst),
		.s_axi_arlock(m_arlock),
		.s_axi_arcache(m_arcache),
		.s_axi_arprot(m_arprot),
		.s_axi_arqos(m_arqos),
		.s_axi_arvalid(m_arvalid),
		.s_axi_arready(m_arready),
		.s_axi_rid(m_rid),
		.s_axi_rdata(m_rdata),
		.s_axi_rresp(m_rresp),
		.s_axi_rlast(m_rlast),
		.s_axi_rvalid(m_rvalid),
		.s_axi_rready(m_rready),
		.m_axi_awid(s_awid),
		.m_axi_awaddr(s_awaddr),
		.m_axi_awlen(s_awlen),
		.m_axi_awsize(s_awsize),
		.m_axi_awburst(s_awburst),
		.m_axi_awlock(s_awlock),
		.m_axi_awcache(s_awcache),
		.m_axi_awprot(s_awprot),
		.m_axi_awqos(s_awqos),
		.m_axi_awregion(s_awregion),
		.m_axi_awvalid(s_awvalid),
		.m_axi_awready(s_awready),
		.m_axi_wdata(s_wdata),
		.m_axi_wstrb(s_wstrb),
		.m_axi_wlast(s_wlast),
		.m_axi_wvalid(s_wvalid),
		.m_axi_wready(s_wready),
		.m_axi_bid(s_bid),
		.m_axi_bresp(s_bresp),
		.m_axi_bvalid(s_bvalid),
		.m_axi_bready(s_bready),
		.m_axi_arid(s_arid),
		.m_axi_araddr(s_araddr),
		.m_axi_arlen(s_arlen),
		.m_axi_arsize(s_arsize),
		.m_axi_arburst(s_arburst),
		.m_axi_arlock(s_arlock),
		.m_axi_arcache(s_arcache),
		.m_axi_arprot(s_arprot),
		.m_axi_arqos(s_arqos),
		.m_axi_arregion(s_arregion),
		.m_axi_arvalid(s_arvalid),
		.m_axi_arready(s_arready),
		.m_axi_rid(s_rid),
		.m_axi_rdata(s_rdata),
		.m_axi_rresp(s_rresp),
		.m_axi_rlast(s_rlast),
		.m_axi_rvalid(s_rvalid),
		.m_axi_rready(s_rready),
		.s_axi_awuser(4'b0000),
		.s_axi_wuser(4'b0000),
		.s_axi_buser(),
		.s_axi_aruser(4'b0000),
		.s_axi_ruser(),
		.m_axi_awuser(),
		.m_axi_wuser(),
		.m_axi_buser(4'b0000),
		.m_axi_aruser(),
		.m_axi_ruser(4'b0000)
	);

	/* AXREGION is generated from the decoded region index. Each target has
	 * one region, so outgoing s_awregion/s_arregion are zero. The optional
	 * m_awregion/m_arregion inputs remain for source compatibility and are
	 * deliberately ignored. QoS is forwarded, not used as a priority. */

	// Configuration mistakes are simulation/elaboration failures.
	// synthesis translate_off
	initial begin
		if (ID_WIDTH < 1 || ADDR_WIDTH < 32 || DATA_WIDTH < 8 ||
			(DATA_WIDTH % 8) != 0 || ((DATA_WIDTH/8) & ((DATA_WIDTH/8)-1)) != 0)
			$fatal(1,"Widths require ID>=1, address>=32, data/8 a power of two");
		if (THREADS < 1 || ACCEPT < THREADS || ISSUE < 1)
			$fatal(1,"Require ACCEPT >= THREADS >= 1 and ISSUE >= 1");
		for (integer i=0; i<4; i=i+1)
			if (M_ADDR_WIDTH[i*32+:32] != 0 &&
				(M_ADDR_WIDTH[i*32+:32] < 12 || M_ADDR_WIDTH[i*32+:32] > ADDR_WIDTH))
				$fatal(1,"Enabled address region width must be 12..ADDR_WIDTH");
	end
	// synthesis translate_on
endmodule
`default_nettype wire
