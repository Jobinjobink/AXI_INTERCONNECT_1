`timescale 1ns/1ps
`default_nettype none
// Synthesizable Mini-SoC fabric integration boundary. CPU/DMA/GPU/NPU,
// DDR, SRAM, APB bridge and accelerator implementations remain external.
import axi_pkg::*;
module soc_axi4_subsystem #(
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
    axi4_struct_crossbar #(.THREADS(THREADS),.ACCEPT(ACCEPT),.ISSUE(ISSUE),
        .BASE(BASE),.WIDTH(WIDTH),.CONNECT_READ(CONNECT_READ),
        .CONNECT_WRITE(CONNECT_WRITE),.SECURE(SECURE)) fabric (.*);
endmodule
`default_nettype wire

