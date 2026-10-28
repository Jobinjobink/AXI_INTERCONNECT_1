`timescale 1ns/1ps
`default_nettype none
// Full AXI struct-to-packed-port adaptation. No queues or protocol changes.
// Named ports preserve the user's CPU,NPU,GPU,DMA order at the SoC boundary;
// the packed core uses CPU,DMA,GPU,NPU and tags IDs with that core index.
import axi_pkg::*;
module axi4_struct_crossbar #(
    parameter integer THREADS=4, ACCEPT=8, ISSUE=8,
    parameter [127:0] BASE=soc_address_map_pkg::BASE,
    parameter [127:0] WIDTH=soc_address_map_pkg::WIDTH,
    parameter [15:0] CONNECT_READ=16'hffff, CONNECT_WRITE=16'hffff,
    parameter [3:0] SECURE=4'b0000
)(
    input wire clk, rst_n,
    input req_t cpu_req,
    output rsp_t cpu_rsp,
    input req_t npu_req,
    output rsp_t npu_rsp,
    input req_t gpu_req,
    output rsp_t gpu_rsp,
    input req_t dma_req,
    output rsp_t dma_rsp,
    output target_req_t ddr_req,
    input target_rsp_t ddr_rsp,
    output target_req_t sram_req,
    input target_rsp_t sram_rsp,
    output target_req_t apb_req,
    input target_rsp_t apb_rsp,
    output target_req_t accel_req,
    input target_rsp_t accel_rsp
);
    addr_t cpu_aw;
    assign cpu_aw = cpu_req.aw;
    w_t cpu_w;
    assign cpu_w = cpu_req.w;
    addr_t cpu_ar;
    assign cpu_ar = cpu_req.ar;
    b_t cpu_b;
    assign cpu_rsp.b = cpu_b;
    r_t cpu_r;
    assign cpu_rsp.r = cpu_r;
    addr_t npu_aw;
    assign npu_aw = npu_req.aw;
    w_t npu_w;
    assign npu_w = npu_req.w;
    addr_t npu_ar;
    assign npu_ar = npu_req.ar;
    b_t npu_b;
    assign npu_rsp.b = npu_b;
    r_t npu_r;
    assign npu_rsp.r = npu_r;
    addr_t gpu_aw;
    assign gpu_aw = gpu_req.aw;
    w_t gpu_w;
    assign gpu_w = gpu_req.w;
    addr_t gpu_ar;
    assign gpu_ar = gpu_req.ar;
    b_t gpu_b;
    assign gpu_rsp.b = gpu_b;
    r_t gpu_r;
    assign gpu_rsp.r = gpu_r;
    addr_t dma_aw;
    assign dma_aw = dma_req.aw;
    w_t dma_w;
    assign dma_w = dma_req.w;
    addr_t dma_ar;
    assign dma_ar = dma_req.ar;
    b_t dma_b;
    assign dma_rsp.b = dma_b;
    r_t dma_r;
    assign dma_rsp.r = dma_r;
    target_addr_t ddr_aw;
    assign ddr_req.aw = ddr_aw;
    w_t ddr_w;
    assign ddr_req.w = ddr_w;
    target_addr_t ddr_ar;
    assign ddr_req.ar = ddr_ar;
    target_b_t ddr_b;
    assign ddr_b = ddr_rsp.b;
    target_r_t ddr_r;
    assign ddr_r = ddr_rsp.r;
    target_addr_t sram_aw;
    assign sram_req.aw = sram_aw;
    w_t sram_w;
    assign sram_req.w = sram_w;
    target_addr_t sram_ar;
    assign sram_req.ar = sram_ar;
    target_b_t sram_b;
    assign sram_b = sram_rsp.b;
    target_r_t sram_r;
    assign sram_r = sram_rsp.r;
    target_addr_t apb_aw;
    assign apb_req.aw = apb_aw;
    w_t apb_w;
    assign apb_req.w = apb_w;
    target_addr_t apb_ar;
    assign apb_req.ar = apb_ar;
    target_b_t apb_b;
    assign apb_b = apb_rsp.b;
    target_r_t apb_r;
    assign apb_r = apb_rsp.r;
    target_addr_t accel_aw;
    assign accel_req.aw = accel_aw;
    w_t accel_w;
    assign accel_req.w = accel_w;
    target_addr_t accel_ar;
    assign accel_req.ar = accel_ar;
    target_b_t accel_b;
    assign accel_b = accel_rsp.b;
    target_r_t accel_r;
    assign accel_r = accel_rsp.r;
    wire [3:0][7:0] m_awid;
    assign m_awid = {npu_aw.id, gpu_aw.id, dma_aw.id, cpu_aw.id};
    wire [3:0][31:0] m_awaddr;
    assign m_awaddr = {npu_aw.addr, gpu_aw.addr, dma_aw.addr, cpu_aw.addr};
    wire [3:0][7:0] m_awlen;
    assign m_awlen = {npu_aw.len, gpu_aw.len, dma_aw.len, cpu_aw.len};
    wire [3:0][2:0] m_awsize;
    assign m_awsize = {npu_aw.size, gpu_aw.size, dma_aw.size, cpu_aw.size};
    wire [3:0][1:0] m_awburst;
    assign m_awburst = {npu_aw.burst, gpu_aw.burst, dma_aw.burst, cpu_aw.burst};
    wire [3:0] m_awlock;
    assign m_awlock = {npu_aw.lock, gpu_aw.lock, dma_aw.lock, cpu_aw.lock};
    wire [3:0][3:0] m_awcache;
    assign m_awcache = {npu_aw.cache, gpu_aw.cache, dma_aw.cache, cpu_aw.cache};
    wire [3:0][2:0] m_awprot;
    assign m_awprot = {npu_aw.prot, gpu_aw.prot, dma_aw.prot, cpu_aw.prot};
    wire [3:0][3:0] m_awqos;
    assign m_awqos = {npu_aw.qos, gpu_aw.qos, dma_aw.qos, cpu_aw.qos};
    wire [3:0][3:0] m_awregion;
    assign m_awregion = 16'b0;
    wire [3:0] m_awvalid;
    assign m_awvalid = {npu_req.awvalid, gpu_req.awvalid, dma_req.awvalid, cpu_req.awvalid};
    wire [3:0] m_awready;
    assign {npu_rsp.awready, gpu_rsp.awready, dma_rsp.awready, cpu_rsp.awready} = m_awready;
    wire [3:0][31:0] m_wdata;
    assign m_wdata = {npu_w.data, gpu_w.data, dma_w.data, cpu_w.data};
    wire [3:0][3:0] m_wstrb;
    assign m_wstrb = {npu_w.strb, gpu_w.strb, dma_w.strb, cpu_w.strb};
    wire [3:0] m_wlast;
    assign m_wlast = {npu_w.last, gpu_w.last, dma_w.last, cpu_w.last};
    wire [3:0] m_wvalid;
    assign m_wvalid = {npu_req.wvalid, gpu_req.wvalid, dma_req.wvalid, cpu_req.wvalid};
    wire [3:0] m_wready;
    assign {npu_rsp.wready, gpu_rsp.wready, dma_rsp.wready, cpu_rsp.wready} = m_wready;
    wire [3:0][7:0] m_bid;
    assign {npu_b.id, gpu_b.id, dma_b.id, cpu_b.id} = m_bid;
    wire [3:0][1:0] m_bresp;
    assign {npu_b.resp, gpu_b.resp, dma_b.resp, cpu_b.resp} = m_bresp;
    wire [3:0] m_bvalid;
    assign {npu_rsp.bvalid, gpu_rsp.bvalid, dma_rsp.bvalid, cpu_rsp.bvalid} = m_bvalid;
    wire [3:0] m_bready;
    assign m_bready = {npu_req.bready, gpu_req.bready, dma_req.bready, cpu_req.bready};
    wire [3:0][7:0] m_arid;
    assign m_arid = {npu_ar.id, gpu_ar.id, dma_ar.id, cpu_ar.id};
    wire [3:0][31:0] m_araddr;
    assign m_araddr = {npu_ar.addr, gpu_ar.addr, dma_ar.addr, cpu_ar.addr};
    wire [3:0][7:0] m_arlen;
    assign m_arlen = {npu_ar.len, gpu_ar.len, dma_ar.len, cpu_ar.len};
    wire [3:0][2:0] m_arsize;
    assign m_arsize = {npu_ar.size, gpu_ar.size, dma_ar.size, cpu_ar.size};
    wire [3:0][1:0] m_arburst;
    assign m_arburst = {npu_ar.burst, gpu_ar.burst, dma_ar.burst, cpu_ar.burst};
    wire [3:0] m_arlock;
    assign m_arlock = {npu_ar.lock, gpu_ar.lock, dma_ar.lock, cpu_ar.lock};
    wire [3:0][3:0] m_arcache;
    assign m_arcache = {npu_ar.cache, gpu_ar.cache, dma_ar.cache, cpu_ar.cache};
    wire [3:0][2:0] m_arprot;
    assign m_arprot = {npu_ar.prot, gpu_ar.prot, dma_ar.prot, cpu_ar.prot};
    wire [3:0][3:0] m_arqos;
    assign m_arqos = {npu_ar.qos, gpu_ar.qos, dma_ar.qos, cpu_ar.qos};
    wire [3:0][3:0] m_arregion;
    assign m_arregion = 16'b0;
    wire [3:0] m_arvalid;
    assign m_arvalid = {npu_req.arvalid, gpu_req.arvalid, dma_req.arvalid, cpu_req.arvalid};
    wire [3:0] m_arready;
    assign {npu_rsp.arready, gpu_rsp.arready, dma_rsp.arready, cpu_rsp.arready} = m_arready;
    wire [3:0][7:0] m_rid;
    assign {npu_r.id, gpu_r.id, dma_r.id, cpu_r.id} = m_rid;
    wire [3:0][31:0] m_rdata;
    assign {npu_r.data, gpu_r.data, dma_r.data, cpu_r.data} = m_rdata;
    wire [3:0][1:0] m_rresp;
    assign {npu_r.resp, gpu_r.resp, dma_r.resp, cpu_r.resp} = m_rresp;
    wire [3:0] m_rlast;
    assign {npu_r.last, gpu_r.last, dma_r.last, cpu_r.last} = m_rlast;
    wire [3:0] m_rvalid;
    assign {npu_rsp.rvalid, gpu_rsp.rvalid, dma_rsp.rvalid, cpu_rsp.rvalid} = m_rvalid;
    wire [3:0] m_rready;
    assign m_rready = {npu_req.rready, gpu_req.rready, dma_req.rready, cpu_req.rready};
    wire [3:0][9:0] s_awid;
    assign {accel_aw.id, apb_aw.id, sram_aw.id, ddr_aw.id} = s_awid;
    wire [3:0][31:0] s_awaddr;
    assign {accel_aw.addr, apb_aw.addr, sram_aw.addr, ddr_aw.addr} = s_awaddr;
    wire [3:0][7:0] s_awlen;
    assign {accel_aw.len, apb_aw.len, sram_aw.len, ddr_aw.len} = s_awlen;
    wire [3:0][2:0] s_awsize;
    assign {accel_aw.size, apb_aw.size, sram_aw.size, ddr_aw.size} = s_awsize;
    wire [3:0][1:0] s_awburst;
    assign {accel_aw.burst, apb_aw.burst, sram_aw.burst, ddr_aw.burst} = s_awburst;
    wire [3:0] s_awlock;
    assign {accel_aw.lock, apb_aw.lock, sram_aw.lock, ddr_aw.lock} = s_awlock;
    wire [3:0][3:0] s_awcache;
    assign {accel_aw.cache, apb_aw.cache, sram_aw.cache, ddr_aw.cache} = s_awcache;
    wire [3:0][2:0] s_awprot;
    assign {accel_aw.prot, apb_aw.prot, sram_aw.prot, ddr_aw.prot} = s_awprot;
    wire [3:0][3:0] s_awqos;
    assign {accel_aw.qos, apb_aw.qos, sram_aw.qos, ddr_aw.qos} = s_awqos;
    wire [3:0][3:0] s_awregion;
    assign {accel_aw.region, apb_aw.region, sram_aw.region, ddr_aw.region} = s_awregion;
    wire [3:0] s_awvalid;
    assign {accel_req.awvalid, apb_req.awvalid, sram_req.awvalid, ddr_req.awvalid} = s_awvalid;
    wire [3:0] s_awready;
    assign s_awready = {accel_rsp.awready, apb_rsp.awready, sram_rsp.awready, ddr_rsp.awready};
    wire [3:0][31:0] s_wdata;
    assign {accel_w.data, apb_w.data, sram_w.data, ddr_w.data} = s_wdata;
    wire [3:0][3:0] s_wstrb;
    assign {accel_w.strb, apb_w.strb, sram_w.strb, ddr_w.strb} = s_wstrb;
    wire [3:0] s_wlast;
    assign {accel_w.last, apb_w.last, sram_w.last, ddr_w.last} = s_wlast;
    wire [3:0] s_wvalid;
    assign {accel_req.wvalid, apb_req.wvalid, sram_req.wvalid, ddr_req.wvalid} = s_wvalid;
    wire [3:0] s_wready;
    assign s_wready = {accel_rsp.wready, apb_rsp.wready, sram_rsp.wready, ddr_rsp.wready};
    wire [3:0][9:0] s_bid;
    assign s_bid = {accel_b.id, apb_b.id, sram_b.id, ddr_b.id};
    wire [3:0][1:0] s_bresp;
    assign s_bresp = {accel_b.resp, apb_b.resp, sram_b.resp, ddr_b.resp};
    wire [3:0] s_bvalid;
    assign s_bvalid = {accel_rsp.bvalid, apb_rsp.bvalid, sram_rsp.bvalid, ddr_rsp.bvalid};
    wire [3:0] s_bready;
    assign {accel_req.bready, apb_req.bready, sram_req.bready, ddr_req.bready} = s_bready;
    wire [3:0][9:0] s_arid;
    assign {accel_ar.id, apb_ar.id, sram_ar.id, ddr_ar.id} = s_arid;
    wire [3:0][31:0] s_araddr;
    assign {accel_ar.addr, apb_ar.addr, sram_ar.addr, ddr_ar.addr} = s_araddr;
    wire [3:0][7:0] s_arlen;
    assign {accel_ar.len, apb_ar.len, sram_ar.len, ddr_ar.len} = s_arlen;
    wire [3:0][2:0] s_arsize;
    assign {accel_ar.size, apb_ar.size, sram_ar.size, ddr_ar.size} = s_arsize;
    wire [3:0][1:0] s_arburst;
    assign {accel_ar.burst, apb_ar.burst, sram_ar.burst, ddr_ar.burst} = s_arburst;
    wire [3:0] s_arlock;
    assign {accel_ar.lock, apb_ar.lock, sram_ar.lock, ddr_ar.lock} = s_arlock;
    wire [3:0][3:0] s_arcache;
    assign {accel_ar.cache, apb_ar.cache, sram_ar.cache, ddr_ar.cache} = s_arcache;
    wire [3:0][2:0] s_arprot;
    assign {accel_ar.prot, apb_ar.prot, sram_ar.prot, ddr_ar.prot} = s_arprot;
    wire [3:0][3:0] s_arqos;
    assign {accel_ar.qos, apb_ar.qos, sram_ar.qos, ddr_ar.qos} = s_arqos;
    wire [3:0][3:0] s_arregion;
    assign {accel_ar.region, apb_ar.region, sram_ar.region, ddr_ar.region} = s_arregion;
    wire [3:0] s_arvalid;
    assign {accel_req.arvalid, apb_req.arvalid, sram_req.arvalid, ddr_req.arvalid} = s_arvalid;
    wire [3:0] s_arready;
    assign s_arready = {accel_rsp.arready, apb_rsp.arready, sram_rsp.arready, ddr_rsp.arready};
    wire [3:0][9:0] s_rid;
    assign s_rid = {accel_r.id, apb_r.id, sram_r.id, ddr_r.id};
    wire [3:0][31:0] s_rdata;
    assign s_rdata = {accel_r.data, apb_r.data, sram_r.data, ddr_r.data};
    wire [3:0][1:0] s_rresp;
    assign s_rresp = {accel_r.resp, apb_r.resp, sram_r.resp, ddr_r.resp};
    wire [3:0] s_rlast;
    assign s_rlast = {accel_r.last, apb_r.last, sram_r.last, ddr_r.last};
    wire [3:0] s_rvalid;
    assign s_rvalid = {accel_rsp.rvalid, apb_rsp.rvalid, sram_rsp.rvalid, ddr_rsp.rvalid};
    wire [3:0] s_rready;
    assign {accel_req.rready, apb_req.rready, sram_req.rready, ddr_req.rready} = s_rready;
    axi4_interconnect_4x4 #(
        .ID_WIDTH(axi_pkg::ID_W), .DATA_WIDTH(axi_pkg::DATA_W), .ADDR_WIDTH(axi_pkg::ADDR_W),
        .THREADS(THREADS), .ACCEPT(ACCEPT), .ISSUE(ISSUE),
        .M_BASE_ADDR(BASE), .M_ADDR_WIDTH(WIDTH),
        .CONNECT_READ(CONNECT_READ), .CONNECT_WRITE(CONNECT_WRITE), .SECURE(SECURE)
    ) core (
        .aclk(clk), .aresetn(rst_n),
        .m_awid(m_awid),
        .m_awaddr(m_awaddr),
        .m_awlen(m_awlen),
        .m_awsize(m_awsize),
        .m_awburst(m_awburst),
        .m_awlock(m_awlock),
        .m_awcache(m_awcache),
        .m_awprot(m_awprot),
        .m_awqos(m_awqos),
        .m_awregion(m_awregion),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_wdata(m_wdata),
        .m_wstrb(m_wstrb),
        .m_wlast(m_wlast),
        .m_wvalid(m_wvalid),
        .m_wready(m_wready),
        .m_bid(m_bid),
        .m_bresp(m_bresp),
        .m_bvalid(m_bvalid),
        .m_bready(m_bready),
        .m_arid(m_arid),
        .m_araddr(m_araddr),
        .m_arlen(m_arlen),
        .m_arsize(m_arsize),
        .m_arburst(m_arburst),
        .m_arlock(m_arlock),
        .m_arcache(m_arcache),
        .m_arprot(m_arprot),
        .m_arqos(m_arqos),
        .m_arregion(m_arregion),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_rid(m_rid),
        .m_rdata(m_rdata),
        .m_rresp(m_rresp),
        .m_rlast(m_rlast),
        .m_rvalid(m_rvalid),
        .m_rready(m_rready),
        .s_awid(s_awid),
        .s_awaddr(s_awaddr),
        .s_awlen(s_awlen),
        .s_awsize(s_awsize),
        .s_awburst(s_awburst),
        .s_awlock(s_awlock),
        .s_awcache(s_awcache),
        .s_awprot(s_awprot),
        .s_awqos(s_awqos),
        .s_awregion(s_awregion),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_wdata(s_wdata),
        .s_wstrb(s_wstrb),
        .s_wlast(s_wlast),
        .s_wvalid(s_wvalid),
        .s_wready(s_wready),
        .s_bid(s_bid),
        .s_bresp(s_bresp),
        .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_arid(s_arid),
        .s_araddr(s_araddr),
        .s_arlen(s_arlen),
        .s_arsize(s_arsize),
        .s_arburst(s_arburst),
        .s_arlock(s_arlock),
        .s_arcache(s_arcache),
        .s_arprot(s_arprot),
        .s_arqos(s_arqos),
        .s_arregion(s_arregion),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_rid(s_rid),
        .s_rdata(s_rdata),
        .s_rresp(s_rresp),
        .s_rlast(s_rlast),
        .s_rvalid(s_rvalid),
        .s_rready(s_rready)
    );
endmodule
`default_nettype wire

