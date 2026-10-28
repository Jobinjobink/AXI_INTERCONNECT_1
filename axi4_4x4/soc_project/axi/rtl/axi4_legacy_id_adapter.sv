`timescale 1ns/1ps
`default_nettype none
// Single-slot ID preservation bridge for a legacy eight-bit-ID target.
// AW/AR are buffered independently. W may progress before target AWREADY.
// Retire ownership only after the B / final R handshake at the wide side.
// Payload conversion is purely structural: no burst conversion or recovery.
import axi_pkg::*;
module axi4_legacy_id_adapter (
    input wire clk, rst_n,
    input target_req_t wide_req,
    output target_rsp_t wide_rsp,
    output req_t legacy_req,
    input rsp_t legacy_rsp
);
    target_addr_t aw_hold, ar_hold;
    logic write_active, aw_pending, write_data_done;
    logic read_active, ar_pending;

    always @* begin
        legacy_req='0;
        wide_rsp='0;
        wide_rsp.awready=rst_n && !write_active;
        wide_rsp.arready=rst_n && !read_active;
        legacy_req.aw.id=aw_hold.id[7:0];
        legacy_req.aw.addr=aw_hold.addr;
        legacy_req.aw.len=aw_hold.len;
        legacy_req.aw.size=aw_hold.size;
        legacy_req.aw.burst=aw_hold.burst;
        legacy_req.aw.lock=aw_hold.lock;
        legacy_req.aw.cache=aw_hold.cache;
        legacy_req.aw.prot=aw_hold.prot;
        legacy_req.aw.qos=aw_hold.qos;
        legacy_req.awvalid=rst_n && write_active && aw_pending;
        legacy_req.w=wide_req.w;
        legacy_req.wvalid=rst_n && write_active && !write_data_done && wide_req.wvalid;
        wide_rsp.wready=rst_n && write_active && !write_data_done && legacy_rsp.wready;
        legacy_req.bready=rst_n && write_active && !aw_pending && write_data_done && wide_req.bready;
        wide_rsp.bvalid=rst_n && write_active && !aw_pending && write_data_done && legacy_rsp.bvalid;
        wide_rsp.b.id=aw_hold.id;
        wide_rsp.b.resp=legacy_rsp.b.resp;
        legacy_req.ar.id=ar_hold.id[7:0];
        legacy_req.ar.addr=ar_hold.addr;
        legacy_req.ar.len=ar_hold.len;
        legacy_req.ar.size=ar_hold.size;
        legacy_req.ar.burst=ar_hold.burst;
        legacy_req.ar.lock=ar_hold.lock;
        legacy_req.ar.cache=ar_hold.cache;
        legacy_req.ar.prot=ar_hold.prot;
        legacy_req.ar.qos=ar_hold.qos;
        legacy_req.arvalid=rst_n && read_active && ar_pending;
        legacy_req.rready=rst_n && read_active && !ar_pending && wide_req.rready;
        wide_rsp.rvalid=rst_n && read_active && !ar_pending && legacy_rsp.rvalid;
        wide_rsp.r.id=ar_hold.id;
        wide_rsp.r.data=legacy_rsp.r.data;
        wide_rsp.r.resp=legacy_rsp.r.resp;
        wide_rsp.r.last=legacy_rsp.r.last;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aw_hold<='0; ar_hold<='0;
            write_active<=0; aw_pending<=0; write_data_done<=0;
            read_active<=0; ar_pending<=0;
        end else begin
            if (wide_req.awvalid && wide_rsp.awready) begin
                aw_hold<=wide_req.aw;
                write_active<=1; aw_pending<=1; write_data_done<=0;
            end
            if (legacy_req.awvalid && legacy_rsp.awready) aw_pending<=0;
            if (legacy_req.wvalid && legacy_rsp.wready && legacy_req.w.last) write_data_done<=1;
            if (wide_rsp.bvalid && wide_req.bready) write_active<=0;
            if (wide_req.arvalid && wide_rsp.arready) begin
                ar_hold<=wide_req.ar;
                read_active<=1; ar_pending<=1;
            end
            if (legacy_req.arvalid && legacy_rsp.arready) ar_pending<=0;
            if (wide_rsp.rvalid && wide_req.rready && wide_rsp.r.last) read_active<=0;
        end
    end
endmodule
`default_nettype wire


