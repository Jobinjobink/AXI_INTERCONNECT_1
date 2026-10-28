`timescale 1ns/1ps
`default_nettype none
// Optional bridge for existing eight-bit-ID AXI targets. Each target can have
// one read and one write outstanding independently; the crossbar keeps its
// own multiple-outstanding capability and four-target concurrency.
import axi_pkg::*;
module soc_axi4_legacy_subsystem #(
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
    output req_t ddr_req,
    input rsp_t ddr_rsp,
    output req_t sram_req,
    input rsp_t sram_rsp,
    output req_t apb_req,
    input rsp_t apb_rsp,
    output req_t accel_req,
    input rsp_t accel_rsp
);
    target_req_t ddr_wide_req;
    target_rsp_t ddr_wide_rsp;
    target_req_t sram_wide_req;
    target_rsp_t sram_wide_rsp;
    target_req_t apb_wide_req;
    target_rsp_t apb_wide_rsp;
    target_req_t accel_wide_req;
    target_rsp_t accel_wide_rsp;
    soc_axi4_subsystem #(.THREADS(THREADS),.ACCEPT(ACCEPT),.ISSUE(ISSUE),
        .BASE(BASE),.WIDTH(WIDTH),.CONNECT_READ(CONNECT_READ),
        .CONNECT_WRITE(CONNECT_WRITE),.SECURE(SECURE)) fabric (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_req), .cpu_rsp(cpu_rsp),
        .dma_req(dma_req), .dma_rsp(dma_rsp),
        .gpu_req(gpu_req), .gpu_rsp(gpu_rsp),
        .npu_req(npu_req), .npu_rsp(npu_rsp),
        .ddr_req(ddr_wide_req), .ddr_rsp(ddr_wide_rsp),
        .sram_req(sram_wide_req), .sram_rsp(sram_wide_rsp),
        .apb_req(apb_wide_req), .apb_rsp(apb_wide_rsp),
        .accel_req(accel_wide_req), .accel_rsp(accel_wide_rsp)
    );
    axi4_legacy_id_adapter ddr_adapter(.clk(clk),.rst_n(rst_n),.wide_req(ddr_wide_req),.wide_rsp(ddr_wide_rsp),.legacy_req(ddr_req),.legacy_rsp(ddr_rsp));
    axi4_legacy_id_adapter sram_adapter(.clk(clk),.rst_n(rst_n),.wide_req(sram_wide_req),.wide_rsp(sram_wide_rsp),.legacy_req(sram_req),.legacy_rsp(sram_rsp));
    axi4_legacy_id_adapter apb_adapter(.clk(clk),.rst_n(rst_n),.wide_req(apb_wide_req),.wide_rsp(apb_wide_rsp),.legacy_req(apb_req),.legacy_rsp(apb_rsp));
    axi4_legacy_id_adapter accel_adapter(.clk(clk),.rst_n(rst_n),.wide_req(accel_wide_req),.wide_rsp(accel_wide_rsp),.legacy_req(accel_req),.legacy_rsp(accel_rsp));
endmodule
`default_nettype wire

