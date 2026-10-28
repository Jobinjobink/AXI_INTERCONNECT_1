`timescale 1ns/1ps
import axi_pkg::*;
module tb_soc_axi4_subsystem;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    wire native_done, legacy_done;
    soc_test_system #(.LEGACY(0)) native_system(clk,rst_n,native_done);
    soc_test_system #(.LEGACY(1)) legacy_system(clk,rst_n,legacy_done);
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1;
        wait(native_done && legacy_done);
        $display("SOC TEST PASS: native and legacy 4x4 structs; 32 writes, 32 reads, 128 data beats each direction");
        $finish;
    end
    initial begin #300000; $fatal(1,"SoC integration timeout"); end
endmodule

module soc_test_system #(parameter LEGACY=0)(input wire clk,rst_n,output wire done);
    req_t cpu_req; rsp_t cpu_rsp; wire cpu_done;
    req_t npu_req; rsp_t npu_rsp; wire npu_done;
    req_t gpu_req; rsp_t gpu_rsp; wire gpu_done;
    req_t dma_req; rsp_t dma_rsp; wire dma_done;
    soc_test_master #(.MASTER(0)) cpu_bfm(clk,rst_n,cpu_req,cpu_rsp,cpu_done);
    soc_test_master #(.MASTER(1)) npu_bfm(clk,rst_n,npu_req,npu_rsp,npu_done);
    soc_test_master #(.MASTER(2)) gpu_bfm(clk,rst_n,gpu_req,gpu_rsp,gpu_done);
    soc_test_master #(.MASTER(3)) dma_bfm(clk,rst_n,dma_req,dma_rsp,dma_done);
    assign done=cpu_done && npu_done && gpu_done && dma_done;
    if (LEGACY==0) begin: system_0
        target_req_t ddr_req; target_rsp_t ddr_rsp;
        soc_test_target_0 #(.BANK(0)) ddr_model(clk,rst_n,ddr_req,ddr_rsp);
        target_req_t sram_req; target_rsp_t sram_rsp;
        soc_test_target_0 #(.BANK(1)) sram_model(clk,rst_n,sram_req,sram_rsp);
        target_req_t apb_req; target_rsp_t apb_rsp;
        soc_test_target_0 #(.BANK(2)) apb_model(clk,rst_n,apb_req,apb_rsp);
        target_req_t accel_req; target_rsp_t accel_rsp;
        soc_test_target_0 #(.BANK(3)) accel_model(clk,rst_n,accel_req,accel_rsp);
        soc_axi4_subsystem dut (.*);
    end
    if (LEGACY==1) begin: system_1
        req_t ddr_req; rsp_t ddr_rsp;
        soc_test_target_1 #(.BANK(0)) ddr_model(clk,rst_n,ddr_req,ddr_rsp);
        req_t sram_req; rsp_t sram_rsp;
        soc_test_target_1 #(.BANK(1)) sram_model(clk,rst_n,sram_req,sram_rsp);
        req_t apb_req; rsp_t apb_rsp;
        soc_test_target_1 #(.BANK(2)) apb_model(clk,rst_n,apb_req,apb_rsp);
        req_t accel_req; rsp_t accel_rsp;
        soc_test_target_1 #(.BANK(3)) accel_model(clk,rst_n,accel_req,accel_rsp);
        soc_axi4_legacy_subsystem dut (.*);
    end
endmodule

module soc_test_target_0 #(parameter BANK=0)(
    input wire clk,rst_n,input target_req_t req,output target_rsp_t rsp
);
    target_addr_t aw;
    assign aw = req.aw;
    w_t w;
    assign w = req.w;
    target_addr_t ar;
    assign ar = req.ar;
    target_b_t b;
    assign rsp.b = b;
    target_r_t r;
    assign rsp.r = r;
    // Hold channel admission decisions across the sampling edge. The reused
    // verification model updates internal queue counts with blocking statements.
    wire model_awready, model_wready, model_arready;
    reg allow_aw=0, allow_w=0, allow_ar=0;
    integer cycles=0;
    always @(negedge clk) begin
        cycles=cycles+1;
        allow_aw<=rst_n && model_awready && ((cycles+BANK)%4!=0);
        allow_w<=rst_n && model_wready && ((cycles+BANK)%3!=0);
        allow_ar<=rst_n && model_arready && ((cycles+BANK)%5!=0);
    end
    assign rsp.awready=allow_aw;
    assign rsp.wready=allow_w;
    assign rsp.arready=allow_ar;
    axi4_test_slave #(.ID_WIDTH(10),.BANK(BANK)) model(
        .clk(clk),.resetn(rst_n),.hold_b(1'b0),.hold_r(1'b0),.stalls(1'b0),
        .interleave_mode(1'b0),.response_code(2'b00),
        .awid(aw.id),
        .awaddr(aw.addr),
        .awlen(aw.len),
        .awsize(aw.size),
        .awburst(aw.burst),
        . awvalid(req.awvalid && allow_aw),
        .awready(model_awready),
        .wdata(w.data),
        .wstrb(w.strb),
        .wlast(w.last),
        . wvalid(req.wvalid && allow_w),
        .wready(model_wready),
        .bid(b.id),
        .bresp(b.resp),
        .bvalid(rsp.bvalid),
        .bready(req.bready),
        .arid(ar.id),
        .araddr(ar.addr),
        .arlen(ar.len),
        .arsize(ar.size),
        .arburst(ar.burst),
        . arvalid(req.arvalid && allow_ar),
        .arready(model_arready),
        .rid(r.id),
        .rdata(r.data),
        .rresp(r.resp),
        .rlast(r.last),
        .rvalid(rsp.rvalid),
        .rready(req.rready)
    );
    function automatic [1:0] route(input [1:0] old_index);
        case(old_index) 0:route=0; 1:route=3; 2:route=2; 3:route=1; endcase
    endfunction
    always @(posedge clk) if(rst_n) begin
        if(req.awvalid && rsp.awready) begin
            if(aw.id[7:0]!==8'he7 || aw.cache!==4'ha || aw.prot!==3'd5 ||
               aw.qos!==({2'b0,aw.addr[9:8]}+4'd1) || aw.len!==3 ||
               aw.size!==2 || aw.burst!==1)
                $fatal(1,"AW struct metadata mapping failure");
            if(aw.id[9:8]!==route(aw.addr[9:8]) || aw.region!==0)
                $fatal(1,"AW route ID or region lost");
        end
        if(req.arvalid && rsp.arready) begin
            if(ar.id[7:0]!==8'he7 || ar.cache!==4'ha || ar.prot!==3'd5 ||
               ar.qos!==({2'b0,ar.addr[9:8]}+4'd1) || ar.len!==3 ||
               ar.size!==2 || ar.burst!==1)
                $fatal(1,"AR struct metadata mapping failure");
            if(ar.id[9:8]!==route(ar.addr[9:8]) || ar.region!==0)
                $fatal(1,"AR route ID or region lost");
        end
    end
endmodule

module soc_test_target_1 #(parameter BANK=0)(
    input wire clk,rst_n,input req_t req,output rsp_t rsp
);
    addr_t aw;
    assign aw = req.aw;
    w_t w;
    assign w = req.w;
    addr_t ar;
    assign ar = req.ar;
    b_t b;
    assign rsp.b = b;
    r_t r;
    assign rsp.r = r;
    // Hold channel admission decisions across the sampling edge. The reused
    // verification model updates internal queue counts with blocking statements.
    wire model_awready, model_wready, model_arready;
    reg allow_aw=0, allow_w=0, allow_ar=0;
    integer cycles=0;
    always @(negedge clk) begin
        cycles=cycles+1;
        allow_aw<=rst_n && model_awready && ((cycles+BANK)%4!=0);
        allow_w<=rst_n && model_wready && ((cycles+BANK)%3!=0);
        allow_ar<=rst_n && model_arready && ((cycles+BANK)%5!=0);
    end
    assign rsp.awready=allow_aw;
    assign rsp.wready=allow_w;
    assign rsp.arready=allow_ar;
    axi4_test_slave #(.ID_WIDTH(8),.BANK(BANK)) model(
        .clk(clk),.resetn(rst_n),.hold_b(1'b0),.hold_r(1'b0),.stalls(1'b0),
        .interleave_mode(1'b0),.response_code(2'b00),
        .awid(aw.id),
        .awaddr(aw.addr),
        .awlen(aw.len),
        .awsize(aw.size),
        .awburst(aw.burst),
        . awvalid(req.awvalid && allow_aw),
        .awready(model_awready),
        .wdata(w.data),
        .wstrb(w.strb),
        .wlast(w.last),
        . wvalid(req.wvalid && allow_w),
        .wready(model_wready),
        .bid(b.id),
        .bresp(b.resp),
        .bvalid(rsp.bvalid),
        .bready(req.bready),
        .arid(ar.id),
        .araddr(ar.addr),
        .arlen(ar.len),
        .arsize(ar.size),
        .arburst(ar.burst),
        . arvalid(req.arvalid && allow_ar),
        .arready(model_arready),
        .rid(r.id),
        .rdata(r.data),
        .rresp(r.resp),
        .rlast(r.last),
        .rvalid(rsp.rvalid),
        .rready(req.rready)
    );
    function automatic [1:0] route(input [1:0] old_index);
        case(old_index) 0:route=0; 1:route=3; 2:route=2; 3:route=1; endcase
    endfunction
    always @(posedge clk) if(rst_n) begin
        if(req.awvalid && rsp.awready) begin
            if(aw.id[7:0]!==8'he7 || aw.cache!==4'ha || aw.prot!==3'd5 ||
               aw.qos!==({2'b0,aw.addr[9:8]}+4'd1) || aw.len!==3 ||
               aw.size!==2 || aw.burst!==1)
                $fatal(1,"AW struct metadata mapping failure");
        end
        if(req.arvalid && rsp.arready) begin
            if(ar.id[7:0]!==8'he7 || ar.cache!==4'ha || ar.prot!==3'd5 ||
               ar.qos!==({2'b0,ar.addr[9:8]}+4'd1) || ar.len!==3 ||
               ar.size!==2 || ar.burst!==1)
                $fatal(1,"AR struct metadata mapping failure");
        end
    end
endmodule
module soc_test_master #(parameter MASTER=0)(
    input wire clk,rst_n,output req_t req,input rsp_t rsp,output reg done=0
);
    addr_t aw_drive, ar_drive;
    w_t w_drive;
    b_t b_read;
    r_t r_read;
    assign req.aw=aw_drive;
    assign req.ar=ar_drive;
    assign req.w=w_drive;
    assign b_read=rsp.b;
    assign r_read=rsp.r;
    reg awvalid_drive;
    assign req.awvalid=awvalid_drive;
    reg wvalid_drive;
    assign req.wvalid=wvalid_drive;
    reg bready_drive;
    assign req.bready=bready_drive;
    reg arvalid_drive;
    assign req.arvalid=arvalid_drive;
    reg rready_drive;
    assign req.rready=rready_drive;
    integer phase, target, beat, count;
    reg [31:0] address, expected;
    initial begin
        aw_drive='0; ar_drive='0; w_drive='0; awvalid_drive=0; wvalid_drive=0; bready_drive=0; arvalid_drive=0; rready_drive=0;
        wait(rst_n);
        for(phase=0;phase<4;phase=phase+1) begin
            target=(phase+MASTER)%4;
            address=(target<<28)+(MASTER<<8)+(phase<<5);
            @(negedge clk);
            aw_drive.id=8'he7; aw_drive.addr=address; aw_drive.len=3;
            aw_drive.size=2; aw_drive.burst=1; aw_drive.cache=4'ha;
            aw_drive.prot=5; aw_drive.qos=MASTER+1; awvalid_drive=1;
            #1; while(!rsp.awready) begin @(negedge clk); #1; end
            @(posedge clk);
            @(negedge clk); awvalid_drive=0;
            for(beat=0;beat<4;beat=beat+1) begin
                w_drive.data=32'hab000000+(MASTER<<16)+(phase<<8)+beat;
                w_drive.strb=4'hf; w_drive.last=(beat==3); wvalid_drive=1;
                #1; while(!rsp.wready) begin @(negedge clk); #1; end
            @(posedge clk);
                @(negedge clk); wvalid_drive=0;
            end
            repeat(5) @(negedge clk);
            bready_drive=1;
            #1; while(!rsp.bvalid) begin @(negedge clk); #1; end
            @(posedge clk);
            if(b_read.id!==8'he7 || b_read.resp!==0) $fatal(1,"Master %0d B route/response wrong",MASTER);
            @(negedge clk); bready_drive=0;
            ar_drive=aw_drive; arvalid_drive=1;
            #1; while(!rsp.arready) begin @(negedge clk); #1; end
            @(posedge clk);
            @(negedge clk); arvalid_drive=0;
            for(beat=0;beat<4;beat=beat+1) begin
                repeat(2) @(negedge clk);
                rready_drive=1;
                #1; while(!rsp.rvalid) begin @(negedge clk); #1; end
            @(posedge clk);
                expected=32'hab000000+(MASTER<<16)+(phase<<8)+beat;
                if(r_read.id!==8'he7 || r_read.resp!==0 || r_read.last!==(beat==3) || r_read.data!==expected)
                    $fatal(1,"Master %0d read mismatch phase %0d beat %0d got %h expected %h",MASTER,phase,beat,r_read.data,expected);
                @(negedge clk); rready_drive=0;
            end
        end
        done=1;
    end
endmodule




