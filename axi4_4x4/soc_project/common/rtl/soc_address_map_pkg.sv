`timescale 1ns/1ps
package soc_address_map_pkg;
    // New 4x4 map: this intentionally differs from the old 4x7 Mini-SoC map.
    localparam logic [127:0] BASE={32'h3000_0000,32'h2000_0000,32'h1000_0000,32'h0000_0000};
    localparam logic [127:0] WIDTH={32'd16,32'd16,32'd16,32'd28};
    // Original master array order, retained at the struct adapter boundary.
    localparam int CPU=0, NPU=1, GPU=2, DMA=3;
    localparam int DDR=0, SRAM=1, APB=2, ACCEL=3;
endpackage
