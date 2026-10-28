`timescale 1ns/1ps
import axi_pkg::*;
module tb_legacy_id_adapter;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    target_req_t wide_req;
    target_rsp_t wide_rsp;
    req_t legacy_req;
    rsp_t legacy_rsp;
    axi4_legacy_id_adapter dut(.*);
    integer owner, bit_index;
    reg [7:0] source_id;
    reg [9:0] full_id;
    task automatic exercise(input [9:0] id);
        integer beat;
        begin
            @(negedge clk);
            wide_req.aw='0; wide_req.aw.id=id; wide_req.aw.addr=32'h10000100;
            wide_req.aw.len=3; wide_req.aw.size=2; wide_req.aw.burst=1;
            wide_req.awvalid=1;
            // Read and write slots must accept independently.
            wide_req.ar=wide_req.aw; wide_req.arvalid=1;
            @(posedge clk);
            if(!wide_rsp.awready || !wide_rsp.arready) $fatal(1,"Empty slots did not accept");
            @(negedge clk); wide_req.awvalid=0; wide_req.arvalid=0;
            if(wide_rsp.awready || wide_rsp.arready) $fatal(1,"Busy slots overaccepted");
            if(legacy_req.aw.id!==id[7:0] || legacy_req.ar.id!==id[7:0])
                $fatal(1,"Legacy ID mapping wrong");
            // A legal target waits for WVALID before AWREADY. W must advance.
            wide_req.wvalid=1; wide_req.w.data=32'h12345678; wide_req.w.strb=15; wide_req.w.last=0;
            legacy_rsp.wready=1;
            #1;
            if(!legacy_req.wvalid || !wide_rsp.wready || !legacy_req.awvalid)
                $fatal(1,"W incorrectly waits for legacy AWREADY");
            @(posedge clk);
            @(negedge clk);
            legacy_rsp.awready=1; legacy_rsp.arready=1;
            wide_req.w.data=32'h12345679;
            @(posedge clk);
            @(negedge clk); legacy_rsp.awready=0; legacy_rsp.arready=0;
            for(beat=2;beat<4;beat=beat+1) begin
                wide_req.w.data=32'h12345678+beat; wide_req.w.last=(beat==3);
                @(posedge clk);
                @(negedge clk);
            end
            wide_req.wvalid=0; legacy_rsp.wready=0;
            legacy_rsp.b.id=id[7:0]; legacy_rsp.b.resp=2'b10; legacy_rsp.bvalid=1;
            legacy_rsp.r.id=id[7:0]; legacy_rsp.r.resp=2'b10;
            legacy_rsp.r.data=32'hfedcba98; legacy_rsp.r.last=0; legacy_rsp.rvalid=1;
            repeat(3) begin
                @(posedge clk);
                if(!wide_rsp.bvalid || wide_rsp.b.id!==id || wide_rsp.b.resp!==2'b10 ||
                   !wide_rsp.rvalid || wide_rsp.r.id!==id || wide_rsp.r.data!==32'hfedcba98 ||
                   wide_rsp.awready || wide_rsp.arready)
                    $fatal(1,"Stalled ownership/response corrupted");
            end
            @(negedge clk); wide_req.bready=1; wide_req.rready=1;
            @(posedge clk);
            @(negedge clk); legacy_rsp.bvalid=0; wide_req.bready=0;
            for(beat=1;beat<4;beat=beat+1) begin
                legacy_rsp.r.data=32'hfedcba98+beat; legacy_rsp.r.last=(beat==3);
                @(posedge clk);
                if(wide_rsp.r.id!==id || wide_rsp.r.resp!==2'b10 ||
                   wide_rsp.r.last!==(beat==3) || wide_rsp.r.data!==(32'hfedcba98+beat))
                    $fatal(1,"Burst response identity or data lost");
                @(negedge clk);
            end
            legacy_rsp.rvalid=0; wide_req.rready=0;
            #1;
            if(!wide_rsp.awready || !wide_rsp.arready) $fatal(1,"Retired slots did not reopen");
        end
    endtask
    initial begin
        wide_req='0; legacy_rsp='0;
        repeat(4) @(negedge clk); rst_n=1;
        for(owner=0;owner<4;owner=owner+1)
            for(bit_index=0;bit_index<10;bit_index=bit_index+1) begin
                if(bit_index==0) source_id=0;
                else if(bit_index==9) source_id=255;
                else source_id=1<<(bit_index-1);
                full_id={2'(owner),source_id};
                exercise(full_id);
            end
        // Reset both slots while addresses are buffered and targets blocked.
        @(negedge clk); wide_req.awvalid=1; wide_req.arvalid=1;
        @(posedge clk);
        @(negedge clk); wide_req.awvalid=0; wide_req.arvalid=0; rst_n=0;
        @(posedge clk);
        @(negedge clk); rst_n=1;
        #1;
        if(legacy_req.awvalid || legacy_req.arvalid || wide_rsp.bvalid || wide_rsp.rvalid ||
           !wide_rsp.awready || !wide_rsp.arready) $fatal(1,"Reset did not discard ownership");
        exercise(10'h2a5);
        $display("SOC TEST PASS: legacy adapter 41 concurrent R/W burst pairs; all ID bits and route owners; stalls, SLVERR, reset recovery");
        $finish;
    end
    initial begin #100000; $fatal(1,"Legacy adapter timeout"); end
endmodule
