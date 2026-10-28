`timescale 1ns/1ps
module tb_config;
	localparam integer ID_WIDTH = 4;
	localparam integer MEM_WORDS = 4096;
	logic aclk = 0;
	logic aresetn = 0;
	always #5 aclk = ~aclk;
	logic [3:0][3:0] m_awid, m_bid, m_arid, m_rid;
	logic [3:0][31:0] m_awaddr, m_araddr, m_wdata, m_rdata;
	logic [3:0][7:0] m_awlen, m_arlen;
	logic [3:0][2:0] m_awsize, m_arsize, m_awprot, m_arprot;
	logic [3:0][1:0] m_awburst, m_arburst, m_bresp, m_rresp;
	logic [3:0][3:0] m_awcache, m_awqos, m_awregion, m_wstrb;
	logic [3:0][3:0] m_arcache, m_arqos, m_arregion;
	logic [3:0] m_awlock, m_awvalid, m_awready, m_wlast, m_wvalid, m_wready;
	logic [3:0] m_bvalid, m_bready, m_arlock, m_arvalid, m_arready;
	logic [3:0] m_rlast, m_rvalid, m_rready;
	logic [3:0][5:0] s_awid, s_bid, s_arid, s_rid;
	logic [3:0][31:0] s_awaddr, s_araddr, s_wdata, s_rdata;
	logic [3:0][7:0] s_awlen, s_arlen;
	logic [3:0][2:0] s_awsize, s_arsize, s_awprot, s_arprot;
	logic [3:0][1:0] s_awburst, s_arburst, s_bresp, s_rresp;
	logic [3:0][3:0] s_awcache, s_awqos, s_awregion, s_wstrb;
	logic [3:0][3:0] s_arcache, s_arqos, s_arregion;
	logic [3:0] s_awlock, s_awvalid, s_awready, s_wlast, s_wvalid, s_wready;
	logic [3:0] s_bvalid, s_bready, s_arlock, s_arvalid, s_arready;
	logic [3:0] s_rlast, s_rvalid, s_rready;
	// Relocated 4-KiB regions, one disabled region, independent permissions.
	axi4_interconnect_4x4 #(
		.M_BASE_ADDR({32'h83000000,32'h82000000,32'h81000000,32'h80000000}),
		.M_ADDR_WIDTH({32'd0,32'd12,32'd12,32'd12}),
		.CONNECT_READ(16'hfffe), .CONNECT_WRITE(16'hffdf), .SECURE(4'b0100)
	) dut (.*);
	integer aw_seen=0,ar_seen=0;
	logic [3:0] pending=0;
	logic [3:0][5:0] pending_id=0;
	assign s_awready=~pending & ~s_bvalid;
	assign s_wready=pending;
	assign s_arready=~s_rvalid;
	always @(posedge aclk) begin
		if(!aresetn) begin pending<=0; s_bvalid<=0; s_rvalid<=0; end
		else for(integer k=0;k<4;k=k+1) begin
			if(s_bvalid[k]&&s_bready[k]) s_bvalid[k]<=0;
			if(s_rvalid[k]&&s_rready[k]) s_rvalid[k]<=0;
			if(s_awvalid[k]&&s_awready[k]) begin
				pending[k]<=1; pending_id[k]<=s_awid[k]; aw_seen=aw_seen+1;
				if((s_awaddr[k] >> 24) != (8'h80+k)) $fatal(1,"Relocated AW decode mismatch");
			end
			if(s_wvalid[k]&&s_wready[k]&&s_wlast[k]) begin
				pending[k]<=0; s_bvalid[k]<=1; s_bid[k]<=pending_id[k]; s_bresp[k]<=0;
			end
			if(s_arvalid[k]&&s_arready[k]) begin
				s_rvalid[k]<=1; s_rid[k]<=s_arid[k]; s_rdata[k]<=32'hcafe1234; s_rresp[k]<=0; s_rlast[k]<=1; ar_seen=ar_seen+1;
				if((s_araddr[k] >> 24) != (8'h80+k)) $fatal(1,"Relocated AR decode mismatch");
			end
		end
	end
	task automatic wr(input integer master,input [31:0] addr,input bit nonsecure,input [1:0] expected);
		begin
			@(negedge aclk); m_awid[master]=3; m_awaddr[master]=addr; m_awprot[master]=nonsecure?2:0; m_awvalid[master]=1;
			do @(posedge aclk); while(!m_awready[master]);
			@(negedge aclk); m_awvalid[master]=0; m_wvalid[master]=1;
			do @(posedge aclk); while(!m_wready[master]);
			@(negedge aclk); m_wvalid[master]=0;
			while(!m_bvalid[master]) @(negedge aclk);
			if(m_bresp[master]!==expected || m_bid[master]!==3) $fatal(1,"Config write response mismatch");
			@(negedge aclk);
		end
	endtask
	task automatic rd(input integer master,input [31:0] addr,input bit nonsecure,input [1:0] expected);
		begin
			@(negedge aclk); m_arid[master]=5; m_araddr[master]=addr; m_arprot[master]=nonsecure?2:0; m_arvalid[master]=1;
			do @(posedge aclk); while(!m_arready[master]);
			@(negedge aclk); m_arvalid[master]=0;
			while(!m_rvalid[master]) @(negedge aclk);
			if(m_rresp[master]!==expected || m_rid[master]!==5 || !m_rlast[master]) $fatal(1,"Config read response mismatch");
			@(negedge aclk);
		end
	endtask
	initial begin
		m_awid=0;m_awaddr=0;m_awlen=0;m_awsize={4{3'd2}};m_awburst={4{2'd1}};
		m_awlock=0;m_awcache=0;m_awprot=0;m_awqos=0;m_awregion=0;m_awvalid=0;
		m_wdata={4{32'h12345678}};m_wstrb='1;m_wlast='1;m_wvalid=0;m_bready='1;
		m_arid=0;m_araddr=0;m_arlen=0;m_arsize={4{3'd2}};m_arburst={4{2'd1}};
		m_arlock=0;m_arcache=0;m_arprot=0;m_arqos=0;m_arregion=0;m_arvalid=0;m_rready='1;
		s_bid=0;s_bresp=0;s_bvalid=0;s_rid=0;s_rdata=0;s_rresp=0;s_rlast=0;s_rvalid=0;
		repeat(6) @(negedge aclk); aresetn=1;
		// Denied paths and nonsecure requests must never reach a real slave.
		rd(0,32'h80000000,0,3); wr(1,32'h81000000,0,3);
		rd(2,32'h82000000,1,3); wr(2,32'h82000000,1,3);
		rd(3,32'h83000000,0,3); wr(3,32'h83000000,0,3);
		if(aw_seen!=0||ar_seen!=0) $fatal(1,"Denied path leaked downstream");
		// Allowed routes at the relocated map must dispatch and return original IDs.
		rd(1,32'h80000000,0,0); wr(0,32'h81000000,0,0);
		rd(2,32'h82000000,0,0); wr(2,32'h82000000,0,0);
		if(aw_seen!=2||ar_seen!=2) $fatal(1,"Allowed config paths not observed");
		$display("CONFIG PASS relocated-map secure-connectivity disabled-region"); $finish;
	end
	initial begin #100000; $fatal(1,"Config watchdog timeout"); end
endmodule
