`timescale 1ns/1ps
module tb_axi4_interconnect #(parameter integer TARGET_B_REG_TYPE=0);
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
	logic [3:0][5:0] s_awid, s_bid, s_bid_raw, s_arid, s_rid;
	logic [3:0][31:0] s_awaddr, s_araddr, s_wdata, s_rdata;
	logic [3:0][7:0] s_awlen, s_arlen;
	logic [3:0][2:0] s_awsize, s_arsize, s_awprot, s_arprot;
	logic [3:0][1:0] s_awburst, s_arburst, s_bresp, s_rresp;
	logic [3:0][3:0] s_awcache, s_awqos, s_awregion, s_wstrb;
	logic [3:0][3:0] s_arcache, s_arqos, s_arregion;
	logic [3:0] s_awlock, s_awvalid, s_awready, s_wlast, s_wvalid, s_wready;
	logic [3:0] s_bvalid, s_bready, s_arlock, s_arvalid, s_arready;
	logic [3:0] s_rlast, s_rvalid, s_rready;
	axi4_interconnect_4x4 #(.ID_WIDTH(ID_WIDTH)) dut (.*);
	defparam dut.crossbar.M_B_REG_TYPE={4{2'(TARGET_B_REG_TYPE)}};

		
	generate for(genvar c=0;c<4;c=c+1) begin : protocol
		axi4_protocol_checker #(.ID_WIDTH(4)) m_check (
			.aclk(aclk),.aresetn(aresetn),
			.awid(m_awid[c]),
			.awaddr(m_awaddr[c]),
			.awlen(m_awlen[c]),
			.awsize(m_awsize[c]),
			.awburst(m_awburst[c]),
			.awlock(m_awlock[c]),
			.awcache(m_awcache[c]),
			.awprot(m_awprot[c]),
			.awqos(m_awqos[c]),
			.awregion(m_awregion[c]),
			.awvalid(m_awvalid[c]),
			.awready(m_awready[c]),
			.wdata(m_wdata[c]),
			.wstrb(m_wstrb[c]),
			.wlast(m_wlast[c]),
			.wvalid(m_wvalid[c]),
			.wready(m_wready[c]),
			.bid(m_bid[c]),
			.bresp(m_bresp[c]),
			.bvalid(m_bvalid[c]),
			.bready(m_bready[c]),
			.arid(m_arid[c]),
			.araddr(m_araddr[c]),
			.arlen(m_arlen[c]),
			.arsize(m_arsize[c]),
			.arburst(m_arburst[c]),
			.arlock(m_arlock[c]),
			.arcache(m_arcache[c]),
			.arprot(m_arprot[c]),
			.arqos(m_arqos[c]),
			.arregion(m_arregion[c]),
			.arvalid(m_arvalid[c]),
			.arready(m_arready[c]),
			.rid(m_rid[c]),
			.rdata(m_rdata[c]),
			.rresp(m_rresp[c]),
			.rlast(m_rlast[c]),
			.rvalid(m_rvalid[c]),
			.rready(m_rready[c])
		);
		axi4_protocol_checker #(.ID_WIDTH(6)) s_check (
			.aclk(aclk),.aresetn(aresetn),
			.awid(s_awid[c]),
			.awaddr(s_awaddr[c]),
			.awlen(s_awlen[c]),
			.awsize(s_awsize[c]),
			.awburst(s_awburst[c]),
			.awlock(s_awlock[c]),
			.awcache(s_awcache[c]),
			.awprot(s_awprot[c]),
			.awqos(s_awqos[c]),
			.awregion(s_awregion[c]),
			.awvalid(s_awvalid[c]),
			.awready(s_awready[c]),
			.wdata(s_wdata[c]),
			.wstrb(s_wstrb[c]),
			.wlast(s_wlast[c]),
			.wvalid(s_wvalid[c]),
			.wready(s_wready[c]),
			.bid(s_bid[c]),
			.bresp(s_bresp[c]),
			.bvalid(s_bvalid[c]),
			.bready(s_bready[c]),
			.arid(s_arid[c]),
			.araddr(s_araddr[c]),
			.arlen(s_arlen[c]),
			.arsize(s_arsize[c]),
			.arburst(s_arburst[c]),
			.arlock(s_arlock[c]),
			.arcache(s_arcache[c]),
			.arprot(s_arprot[c]),
			.arqos(s_arqos[c]),
			.arregion(s_arregion[c]),
			.arvalid(s_arvalid[c]),
			.arready(s_arready[c]),
			.rid(s_rid[c]),
			.rdata(s_rdata[c]),
			.rresp(s_rresp[c]),
			.rlast(s_rlast[c]),
			.rvalid(s_rvalid[c]),
			.rready(s_rready[c])
		);
	end endgenerate
	// Reset release must leave valid controls known even when targets hold
    // READY low before any traffic is launched.
    always @(negedge aclk) if (aresetn) begin
        if ((^s_awvalid === 1'bx) || (^s_wvalid === 1'bx) ||
            (^s_arvalid === 1'bx) || (^m_bvalid === 1'bx) || (^m_rvalid === 1'bx))
            $fatal(1,"Unknown AXI valid after reset release");
    end
	// One visible row per target, backed by the actual synthesizable owner
	// entries. These hierarchical observations are verification-only.
	wire [3:0] owner_valid;
	wire [3:0][1:0] owner_master;
	generate for(genvar o=0;o<4;o=o+1) begin : ownership
		assign owner_valid[o]=dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].w_select_valid_reg;
		assign owner_master[o]=dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].w_select_reg;
		axi4_owner_checker #(.TARGET(o)) check_owner (
			.clk(aclk),.rst_n(aresetn),
			.allocate(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].owner_table_inst.allocate),
			.release_owner(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].owner_table_inst.release_owner),
			.grant_master(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].a_grant_encoded),
			.grant_len(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].s_axi_awlen_mux),
			.owner_valid(owner_valid[o]),.owner(owner_master[o]),
			.wvalid(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].s_axi_wvalid_mux),
			.wready(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].s_axi_wready_mux),
			.wlast(dut.crossbar.axi_crossbar_wr_inst.m_ifaces[o].s_axi_wlast_mux)
		);
	end endgenerate
	localparam integer QDEPTH=64;
	logic [3:0] hold_b=0, hold_r=0;
	logic stalls=0, backpressure=0, interleave_mode=0, exclusive_mode=0;
	logic [3:0] force_bstall=0, force_rstall=0;
	logic [3:0][1:0] response_code=0;
	reg [7:0] expected_mem [0:3][0:65535];
	integer wtail [0:3][0:15], bhead [0:3][0:15], wforward [0:3][0:15];
	integer rtail [0:3][0:15], rhead [0:3][0:15], rforward [0:3][0:15];
	reg [31:0] wa [0:3][0:15][0:QDEPTH-1], ra [0:3][0:15][0:QDEPTH-1];
	integer wlen [0:3][0:15][0:QDEPTH-1], rlen [0:3][0:15][0:QDEPTH-1];
	integer wsize [0:3][0:15][0:QDEPTH-1], rsize [0:3][0:15][0:QDEPTH-1];
	integer wburst [0:3][0:15][0:QDEPTH-1], rburst [0:3][0:15][0:QDEPTH-1];
	integer wcode [0:3][0:15][0:QDEPTH-1], rcode [0:3][0:15][0:QDEPTH-1];
	integer rbeat [0:3][0:15][0:QDEPTH-1];
	integer live_w [0:3], live_r [0:3], peak_w [0:3], peak_r [0:3];
	integer down_aw [0:3], down_ar [0:3];
	integer writes_checked=0, reads_checked=0, read_beats_checked=0;
	integer max_w_lanes=0, max_r_lanes=0, rw_overlap=0, early_w_cycles=0;
	integer seed=1;
	integer owner_stalls_before=0;
	integer interleaved_reads=0, aw_waits_for_w=0;
	integer last_rid [0:3];
	logic last_was_rlast [0:3];
	reg [31:0] random_state=32'h17ac5e39;
	integer mm, ii, jj, kk, bn, ow, idv, qi, ad, active_w, active_r;
	reg [31:0] beat_address, observed_data;
	reg [3:0] lane_mask;
	genvar g;
	generate for (g=0; g<4; g=g+1) begin : target
		// BID may change with BVALID low; buffered return routing must use
		// the registered internal ID rather than this live external signal.
		assign s_bid[g] = s_bvalid[g] ? s_bid_raw[g] : 6'b0;
		axi4_test_slave #(.BANK(g),.WAIT_AW_FOR_W(1),.W_STALL_PERIOD(16),.W_STALL_CYCLES(10)) ram (
			.clk(aclk),.resetn(aresetn),.hold_b(hold_b[g]),.hold_r(hold_r[g]),
			.stalls(stalls),.interleave_mode(interleave_mode),.response_code(response_code[g]),
			.awid(s_awid[g]),.awaddr(s_awaddr[g]),.awlen(s_awlen[g]),.awsize(s_awsize[g]),
			.awburst(s_awburst[g]),.awvalid(s_awvalid[g]),.awready(s_awready[g]),
			.wdata(s_wdata[g]),.wstrb(s_wstrb[g]),.wlast(s_wlast[g]),.wvalid(s_wvalid[g]),.wready(s_wready[g]),
			.bid(s_bid_raw[g]),.bresp(s_bresp[g]),.bvalid(s_bvalid[g]),.bready(s_bready[g]),
			.arid(s_arid[g]),.araddr(s_araddr[g]),.arlen(s_arlen[g]),.arsize(s_arsize[g]),
			.arburst(s_arburst[g]),.arvalid(s_arvalid[g]),.arready(s_arready[g]),
			.rid(s_rid[g]),.rdata(s_rdata[g]),.rresp(s_rresp[g]),.rlast(s_rlast[g]),.rvalid(s_rvalid[g]),.rready(s_rready[g])
		);
	end endgenerate

	function automatic [31:0] base(input integer bank);
		base=bank*32'h10000000;
	endfunction
	function automatic integer bank_of(input [31:0] addr);
		if (addr<32'h10000000) bank_of=0;
		else if (addr>=32'h10000000 && addr<32'h10010000) bank_of=1;
		else if (addr>=32'h20000000 && addr<32'h20010000) bank_of=2;
		else if (addr>=32'h30000000 && addr<32'h30010000) bank_of=3;
		else bank_of=-1;
	endfunction
	/* Closed-form scoreboard address calculation; model uses a cursor instead. */
	function automatic [31:0] address_at(input [31:0] start,
		input integer beat, len, size, burst);
		reg [31:0] bytes, span, lower;
		begin
			bytes=1<<size; span=bytes*(len+1); lower=(start/span)*span;
			if (burst==0 || beat==0) address_at=start;
			else if (burst==2) address_at=lower+(start-lower+beat*bytes)%span;
			else address_at=(start/bytes)*bytes+beat*bytes;
		end
	endfunction
	function automatic [3:0] active_lanes(input [31:0] addr, input integer size);
		integer n;
		begin
			active_lanes=0;
			for(n=0;n<4;n=n+1)
				if(n>=addr%4 && n<((addr>>size)<<size)%4+(1<<size)) active_lanes[n]=1;
		end
	endfunction
	function automatic [31:0] pattern(input integer master, tag, beat);
		pattern=32'h91c75a30^(master<<26)^(tag*32'h01030711)^(beat*32'h01010101)^seed;
	endfunction

	/* Expected descriptors are posted before VALID and checked on observed
	 * downstream address transfers and upstream B/R handshakes. Per-ID queues
	 * permit different IDs to complete out of order without weakening checks. */
	always @(posedge aclk) begin
		if (!aresetn) begin
			for(mm=0;mm<4;mm=mm+1) begin
				live_w[mm]=0; live_r[mm]=0; last_rid[mm]=0; last_was_rlast[mm]=1;
				for(ii=0;ii<16;ii=ii+1) begin
					wtail[mm][ii]=0; bhead[mm][ii]=0; wforward[mm][ii]=0;
					rtail[mm][ii]=0; rhead[mm][ii]=0; rforward[mm][ii]=0;
				end
			end
		end else begin
			active_w=0; active_r=0;
			for(mm=0;mm<4;mm=mm+1) begin
				if(m_awvalid[mm] && m_awready[mm]) live_w[mm]=live_w[mm]+1;
				if(m_arvalid[mm] && m_arready[mm]) live_r[mm]=live_r[mm]+1;
				if(m_bvalid[mm] && m_bready[mm]) begin
					idv=m_bid[mm]; qi=bhead[mm][idv]%QDEPTH;
					if(bhead[mm][idv]>=wtail[mm][idv]) $fatal(1,"Unexpected B master=%0d ID=%0d",mm,idv);
					if(m_bresp[mm] !== 2'(wcode[mm][idv][qi])) $fatal(1,"BRESP mismatch master=%0d ID=%0d",mm,idv);
					bhead[mm][idv]=bhead[mm][idv]+1; writes_checked=writes_checked+1; live_w[mm]=live_w[mm]-1;
				end
				if(m_rvalid[mm] && m_rready[mm]) begin
					idv=m_rid[mm]; qi=rhead[mm][idv]%QDEPTH;
				if(!last_was_rlast[mm] && last_rid[mm]!=idv) interleaved_reads=interleaved_reads+1;
				last_rid[mm]=idv; last_was_rlast[mm]=m_rlast[mm];
					if(rhead[mm][idv]>=rtail[mm][idv]) $fatal(1,"Unexpected R master=%0d ID=%0d",mm,idv);
					if(m_rresp[mm] !== 2'(rcode[mm][idv][qi])) $fatal(1,"RRESP mismatch master=%0d ID=%0d",mm,idv);
					if(m_rlast[mm] !== (rbeat[mm][idv][qi]==rlen[mm][idv][qi])) $fatal(1,"RLAST mismatch");
					beat_address=address_at(ra[mm][idv][qi],rbeat[mm][idv][qi],rlen[mm][idv][qi],rsize[mm][idv][qi],rburst[mm][idv][qi]);
					observed_data=m_rdata[mm]; bn=bank_of(beat_address); ad=beat_address&16'hfffc; lane_mask=active_lanes(beat_address,rsize[mm][idv][qi]);
					if(bn>=0) begin
						for(jj=0;jj<4;jj=jj+1)
							if(lane_mask[jj] && observed_data[jj*8+:8] !== expected_mem[bn][ad+jj])
								$fatal(1,"RDATA mismatch m=%0d id=%0d addr=%h beat=%0d lane=%0d got=%h expected=%h",mm,idv,beat_address,rbeat[mm][idv][qi],jj,m_rdata[mm],expected_mem[bn][ad+jj]);
					end
					rbeat[mm][idv][qi]=rbeat[mm][idv][qi]+1; read_beats_checked=read_beats_checked+1;
					if(m_rlast[mm]) begin rhead[mm][idv]=rhead[mm][idv]+1; reads_checked=reads_checked+1; live_r[mm]=live_r[mm]-1; end
				end
				if(live_w[mm]>peak_w[mm]) peak_w[mm]=live_w[mm];
				if(live_r[mm]>peak_r[mm]) peak_r[mm]=live_r[mm];
				if(s_wvalid[mm] && s_wready[mm]) active_w=active_w+1;
				if(s_awvalid[mm] && !s_awready[mm] && !s_wvalid[mm]) aw_waits_for_w=aw_waits_for_w+1;
				if(s_rvalid[mm] && s_rready[mm]) active_r=active_r+1;
				if(m_wvalid[mm] && !m_awvalid[mm] && live_w[mm]==0) early_w_cycles=early_w_cycles+1;
				if(s_awvalid[mm] && s_awready[mm]) begin
					ow=s_awid[mm]>>ID_WIDTH; idv=s_awid[mm]&15;
				while(wforward[ow][idv]<wtail[ow][idv] && bank_of(wa[ow][idv][wforward[ow][idv]%QDEPTH])<0) wforward[ow][idv]=wforward[ow][idv]+1;
				qi=wforward[ow][idv]%QDEPTH;
					if(wforward[ow][idv]>=wtail[ow][idv] || s_awaddr[mm] !== wa[ow][idv][qi] || bank_of(s_awaddr[mm])!=mm)
						$fatal(1,"AW ID/address/target association mismatch");
					if(s_awlen[mm] !== 8'(wlen[ow][idv][qi]) || s_awsize[mm] !== 3'(wsize[ow][idv][qi]) || s_awburst[mm] !== 2'(wburst[ow][idv][qi])) $fatal(1,"AW attributes mismatch");
					if(s_awcache[mm] !== 4'ha || s_awprot[mm] !== 3'b001 || s_awqos[mm] !== 4'(ow+1) || s_awregion[mm] !== 0 || s_awlock[mm] !== exclusive_mode) $fatal(1,"AW sideband mismatch");
					wforward[ow][idv]=wforward[ow][idv]+1; down_aw[mm]=down_aw[mm]+1;
				end
				if(s_arvalid[mm] && s_arready[mm]) begin
					ow=s_arid[mm]>>ID_WIDTH; idv=s_arid[mm]&15;
				while(rforward[ow][idv]<rtail[ow][idv] && bank_of(ra[ow][idv][rforward[ow][idv]%QDEPTH])<0) rforward[ow][idv]=rforward[ow][idv]+1;
				qi=rforward[ow][idv]%QDEPTH;
					if(rforward[ow][idv]>=rtail[ow][idv] || s_araddr[mm] !== ra[ow][idv][qi] || bank_of(s_araddr[mm])!=mm)
						$fatal(1,"AR ID/address/target association mismatch");
					if(s_arlen[mm] !== 8'(rlen[ow][idv][qi]) || s_arsize[mm] !== 3'(rsize[ow][idv][qi]) || s_arburst[mm] !== 2'(rburst[ow][idv][qi])) $fatal(1,"AR attributes mismatch");
					if(s_arcache[mm] !== 4'h6 || s_arprot[mm] !== 3'b011 || s_arqos[mm] !== 4'(ow+3) || s_arregion[mm] !== 0 || s_arlock[mm] !== exclusive_mode) $fatal(1,"AR sideband mismatch");
					rforward[ow][idv]=rforward[ow][idv]+1; down_ar[mm]=down_ar[mm]+1;
				end
			end
			if(active_w>max_w_lanes) max_w_lanes=active_w;
			if(active_r>max_r_lanes) max_r_lanes=active_r;
			if(active_w>0 && active_r>0) rw_overlap=rw_overlap+1;
		end
	end
	/* READY changes on falling edges. Seeded stalls are deterministic and never
	 * alter VALID payloads, allowing the independent protocol checkers to run. */
	always @(negedge aclk) begin
		if(aresetn) begin
			random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
			m_bready=(backpressure ? (random_state[3:0]|4'b0001) : 4'hf) & ~force_bstall;
			m_rready=(backpressure ? (random_state[7:4]|4'b0010) : 4'hf) & ~force_rstall;
		end
	end

	task automatic tick(input integer count);
		repeat(count) @(posedge aclk);
	endtask
	task automatic send_aw(input integer master, id, input [31:0] addr,
		input integer len, size, burst, code);
		integer q, wait_cycles;
		begin
			@(negedge aclk); q=wtail[master][id]%QDEPTH;
			if(wtail[master][id]-bhead[master][id]>=QDEPTH) $fatal(1,"TB write expectation queue overflow");
			wa[master][id][q]=addr; wlen[master][id][q]=len; wsize[master][id][q]=size;
			wburst[master][id][q]=burst; wcode[master][id][q]=code; wtail[master][id]=wtail[master][id]+1;
			m_awid[master]=4'(id); m_awaddr[master]=addr; m_awlen[master]=8'(len); m_awsize[master]=3'(size);
			m_awburst[master]=2'(burst); m_awcache[master]=4'ha; m_awprot[master]=1;
			m_awqos[master]=4'(master+1); m_awregion[master]=4'hd; m_awlock[master]=exclusive_mode; m_awvalid[master]=1;
			wait_cycles=0;
			do begin @(posedge aclk); wait_cycles=wait_cycles+1; if(wait_cycles>10000) $fatal(1,"AW handshake timeout master=%0d",master); end while(!m_awready[master]);
			@(negedge aclk); m_awvalid[master]=0;
		end
	endtask
	task automatic send_w(input integer master, input [31:0] addr,
		input integer len, size, burst, tag);
		integer beat, bank, address_byte, lane, wait_cycles;
		reg [31:0] ba, data;
		reg [3:0] mask;
		begin
			for(beat=0;beat<=len;beat=beat+1) begin
				@(negedge aclk); ba=address_at(addr,beat,len,size,burst); data=pattern(master,tag,beat); mask=active_lanes(ba,size);
				if(!exclusive_mode && size==2 && beat%3==2) mask=mask&4'b1011;
				if(!exclusive_mode && beat%7==6) mask=0;
				m_wdata[master]=data; m_wstrb[master]=mask; m_wlast[master]=(beat==len); m_wvalid[master]=1;
				wait_cycles=0;
			do begin @(posedge aclk); wait_cycles=wait_cycles+1; if(wait_cycles>10000) $fatal(1,"W handshake timeout master=%0d",master); end while(!m_wready[master]);
				bank=bank_of(ba); address_byte=ba&16'hfffc;
				if(bank>=0) for(lane=0;lane<4;lane=lane+1) if(mask[lane]) expected_mem[bank][address_byte+lane]=data[lane*8+:8];
				@(negedge aclk); m_wvalid[master]=0;
			end
		end
	endtask
	task automatic send_ar(input integer master, id, input [31:0] addr,
		input integer len, size, burst, code);
		integer q, wait_cycles;
		begin
			@(negedge aclk); q=rtail[master][id]%QDEPTH;
			if(rtail[master][id]-rhead[master][id]>=QDEPTH) $fatal(1,"TB read expectation queue overflow");
			ra[master][id][q]=addr; rlen[master][id][q]=len; rsize[master][id][q]=size; rburst[master][id][q]=burst;
			rcode[master][id][q]=code; rbeat[master][id][q]=0; rtail[master][id]=rtail[master][id]+1;
			m_arid[master]=4'(id); m_araddr[master]=addr; m_arlen[master]=8'(len); m_arsize[master]=3'(size);
			m_arburst[master]=2'(burst); m_arcache[master]=6; m_arprot[master]=3;
			m_arqos[master]=4'(master+3); m_arregion[master]=4'he; m_arlock[master]=exclusive_mode; m_arvalid[master]=1;
			wait_cycles=0;
			do begin @(posedge aclk); wait_cycles=wait_cycles+1; if(wait_cycles>10000) $fatal(1,"AR handshake timeout master=%0d",master); end while(!m_arready[master]);
			@(negedge aclk); m_arvalid[master]=0;
		end
	endtask
	task automatic drain_master(input integer master);
		integer timeout_count;
		begin
			timeout_count=0; @(negedge aclk);
			while(live_w[master]!=0 || live_r[master]!=0) begin
				@(negedge aclk); timeout_count=timeout_count+1;
				if(timeout_count>20000) $fatal(1,"Completion timeout m=%0d W=%0d R=%0d",master,live_w[master],live_r[master]);
			end
		end
	endtask
	task automatic drain_all;
		begin drain_master(0); drain_master(1); drain_master(2); drain_master(3); tick(8); end
	endtask
	task automatic write_tx(input integer master, id, input [31:0] addr,
		input integer len, size, burst, tag, code);
		begin
            // Independent channel producers: neither VALID waits for AWREADY.
            fork
                send_aw(master,id,addr,len,size,burst,code);
                send_w(master,addr,len,size,burst,tag);
            join
            drain_master(master);
        end
	endtask
	task automatic read_tx(input integer master, id, input [31:0] addr,
		input integer len, size, burst, code);
		begin send_ar(master,id,addr,len,size,burst,code); drain_master(master); end
	endtask
	task automatic write_read(input integer master, id, input [31:0] addr,
		input integer len, size, burst, tag);
		begin write_tx(master,id,addr,len,size,burst,tag,0); read_tx(master,id,addr,len,size,burst,0); end
	endtask
	task automatic random_traffic(input integer master);
		integer n, target_bank, nbeats, size, burst;
		reg [31:0] addr, state;
		begin
			state=32'h5f173a91^(master*32'h1f314a7d)^seed;
			for(n=0;n<16;n=n+1) begin
				state={state[30:0],state[31]^state[21]^state[1]^state[0]};
				target_bank=(state>>4)&3; size=(state>>6)%3; burst=(state>>9)%3;
				nbeats=1+((state>>12)&7); if(burst==2) nbeats=4;
				addr=base(target_bank)+32'h8000+master*32'h1000+n*64;
				write_read(master,1+n%7,addr,nbeats-1,size,burst,700+master*32+n);
			end
		end
	endtask

	integer saved_aw, saved_ar, saved_b, saved_r;
	integer m, b, n;
	initial begin
		if(!$value$plusargs("SEED=%d",seed)) seed=1;
		random_state=32'h17ac5e39^seed;
		m_awid=0; m_awaddr=0; m_awlen=0; m_awsize=0; m_awburst=0; m_awlock=0;
		m_awcache=0; m_awprot=0; m_awqos=0; m_awregion=0; m_awvalid=0;
		m_wdata=0; m_wstrb=0; m_wlast=0; m_wvalid=0; m_bready=0;
		m_arid=0; m_araddr=0; m_arlen=0; m_arsize=0; m_arburst=0; m_arlock=0;
		m_arcache=0; m_arprot=0; m_arqos=0; m_arregion=0; m_arvalid=0; m_rready=0;
		for(m=0;m<4;m=m+1) begin
			peak_w[m]=0; peak_r[m]=0; down_aw[m]=0; down_ar[m]=0;
			for(b=0;b<65536;b=b+1) expected_mem[m][b]=0;
		end
		if($test$plusargs("VCD")) begin $dumpfile("axi4_4x4.vcd"); $dumpvars(0,tb_axi4_interconnect); end
		tick(6); @(negedge aclk); aresetn=1; tick(4);
		$display("TEST four independent targets, colliding source IDs");
		fork
			write_tx(0,1,base(0)+32'h100,15,2,1,100,0);
			write_tx(1,1,base(1)+32'h100,15,2,1,101,0);
			write_tx(2,1,base(2)+32'h100,15,2,1,102,0);
			write_tx(3,1,base(3)+32'h100,15,2,1,103,0);
		join
		fork
			read_tx(0,1,base(0)+32'h100,15,2,1,0);
			read_tx(1,1,base(1)+32'h100,15,2,1,0);
			read_tx(2,1,base(2)+32'h100,15,2,1,0);
			read_tx(3,1,base(3)+32'h100,15,2,1,0);
		join
		if(max_w_lanes!=4 || max_r_lanes!=4) $fatal(1,"Crossbar concurrency not demonstrated W=%0d R=%0d",max_w_lanes,max_r_lanes);

		$display("TEST WVALID before AWVALID");
		fork
			begin tick(10); send_aw(0,2,32'h200,7,2,1,0); end
			send_w(0,32'h200,7,2,1,200);
		join
		drain_all(); read_tx(0,2,32'h200,7,2,1,0);

		$display("TEST multiple IDs, four destinations, responses withheld");
		@(negedge aclk); hold_b=15; hold_r=15;
		for(n=0;n<4;n=n+1) begin
			send_aw(0,n+2,base(n)+32'h400,3,2,1,0); send_w(0,base(n)+32'h400,3,2,1,300+n);
		end
		tick(20);
		for(n=0;n<4;n=n+1) send_ar(0,n+2,base(n)+32'h400,3,2,1,0);
		tick(20);
		if(live_w[0]<4 || live_r[0]<4) $fatal(1,"Four outstanding commands not demonstrated");
		@(negedge aclk); hold_b=0; hold_r=0; drain_all();

		$display("TEST repeated same-ID transactions to one destination");
		@(negedge aclk); hold_b=1; hold_r=1;
		for(n=0;n<4;n=n+1) begin
			send_aw(0,8,32'h600+n*32,3,2,1,0); send_w(0,32'h600+n*32,3,2,1,350+n);
		end
		tick(20); for(n=0;n<4;n=n+1) send_ar(0,8,32'h600+n*32,3,2,1,0);
		tick(10); if(live_w[0]<4 || live_r[0]<4) $fatal(1,"Same-ID outstanding depth not demonstrated");
		@(negedge aclk); hold_b=0; hold_r=0; drain_all();

		$display("TEST eight outstanding same-ID commands at configured capacity");
		@(negedge aclk); hold_b=1; hold_r=1;
		for(n=0;n<8;n=n+1) begin
			send_aw(0,8,32'h2000+n*32,3,2,1,0); send_w(0,32'h2000+n*32,3,2,1,360+n);
		end
		tick(20); for(n=0;n<8;n=n+1) send_ar(0,8,32'h2000+n*32,3,2,1,0);
		tick(20); if(live_w[0]<8 || live_r[0]<8) $fatal(1,"Configured eight-command capacity not demonstrated");
		@(negedge aclk); hold_b=0; hold_r=0; drain_all();
		$display("TEST same-ID cross-target ordering and read/write independence");
		@(negedge aclk); hold_b=1; hold_r=1;
		send_aw(0,9,32'h1000,1,2,1,0); send_w(0,32'h1000,1,2,1,400);
		send_ar(0,9,32'h1000,1,2,1,0); tick(20);
		saved_aw=down_aw[1]; saved_ar=down_ar[1];
		fork
			begin send_aw(0,9,base(1)+32'h1000,1,2,1,0); send_w(0,base(1)+32'h1000,1,2,1,401); end
			begin send_ar(0,9,base(1)+32'h1000,1,2,1,0); end
			begin
				tick(30);
				if(down_aw[1]!=saved_aw || down_ar[1]!=saved_ar) $fatal(1,"Same-ID retargeted before response");
				@(negedge aclk); hold_b=0;
				tick(30); if(down_aw[1]!=saved_aw+1 || down_ar[1]!=saved_ar) $fatal(1,"Read/write ordering state incorrectly coupled");
				@(negedge aclk); hold_r=0;
			end
		join
		drain_all();

		$display("TEST different-ID completion out of order");
		@(negedge aclk); hold_b=1; hold_r=1;
		saved_b=bhead[1][11]; saved_r=rhead[1][11];
		send_aw(1,10,32'h1400,1,2,1,0); send_w(1,32'h1400,1,2,1,450);
		send_aw(1,11,base(1)+32'h1400,1,2,1,0); send_w(1,base(1)+32'h1400,1,2,1,451);
		tick(15); send_ar(1,10,32'h1400,1,2,1,0); send_ar(1,11,base(1)+32'h1400,1,2,1,0);
		tick(100);
		if(bhead[1][11]!=saved_b+1 || rhead[1][11]!=saved_r+1 || live_w[1]!=1 || live_r[1]!=1) $fatal(1,"Independent-ID OOO completion missing");
		@(negedge aclk); hold_b=0; hold_r=0; drain_all();

		$display("TEST opposite destination order with AW ahead of W");
		fork
			begin send_aw(0,6,base(0)+32'h1800,3,2,1,0); send_aw(0,7,base(1)+32'h1800,3,2,1,0); end
			begin send_aw(1,6,base(1)+32'h1900,3,2,1,0); send_aw(1,7,base(0)+32'h1900,3,2,1,0); end
			/* W starts after an independent delay; it does not wait for second
			 * AWREADY, which would create a dependency forbidden in an AXI master. */
			begin tick(20); send_w(0,base(0)+32'h1800,3,2,1,460); send_w(0,base(1)+32'h1800,3,2,1,461); end
			begin tick(20); send_w(1,base(1)+32'h1900,3,2,1,462); send_w(1,base(0)+32'h1900,3,2,1,463); end
		join
		drain_all();
		fork
			begin read_tx(0,6,base(0)+32'h1800,3,2,1,0); read_tx(0,7,base(1)+32'h1800,3,2,1,0); end
			begin read_tx(1,6,base(1)+32'h1900,3,2,1,0); read_tx(1,7,base(0)+32'h1900,3,2,1,0); end
		join

		$display("TEST slave read-response interleaving across tagged IDs");
		for(n=0;n<4;n=n+1) write_tx(n,1,base(2)+32'h6800+n*64,7,2,1,470+n,0);
		@(negedge aclk); hold_r=4'b0100; interleave_mode=1;
		fork
			begin send_ar(0,1,base(2)+32'h6800,7,2,1,0); send_ar(0,2,base(2)+32'h6800,7,2,1,0); end
			begin send_ar(1,1,base(2)+32'h6840,7,2,1,0); send_ar(1,2,base(2)+32'h6840,7,2,1,0); end
			begin send_ar(2,1,base(2)+32'h6880,7,2,1,0); send_ar(2,2,base(2)+32'h6880,7,2,1,0); end
			begin send_ar(3,1,base(2)+32'h68c0,7,2,1,0); send_ar(3,2,base(2)+32'h68c0,7,2,1,0); end
		join
		tick(30); @(negedge aclk); hold_r=0; drain_all();
		@(negedge aclk); interleave_mode=0;
		if(interleaved_reads==0) $fatal(1,"Read interleaving was not observed");
		$display("TEST crossed interleaved read responses on two targets");
		write_tx(0,5,base(0)+32'h7400,7,2,1,480,0);
		write_tx(1,5,base(0)+32'h7440,7,2,1,481,0);
		write_tx(1,6,base(1)+32'h7440,7,2,1,482,0);
		write_tx(0,6,base(1)+32'h7400,7,2,1,483,0);
		@(negedge aclk); hold_r=4'b0011; interleave_mode=1;
		/* First beats select M0<-S0 and M1<-S1. Each target then switches
		 * owner. Grants held for whole bursts would form a response deadlock. */
		send_ar(0,5,base(0)+32'h7400,7,2,1,0);
		send_ar(1,5,base(0)+32'h7440,7,2,1,0);
		send_ar(1,6,base(1)+32'h7440,7,2,1,0);
		send_ar(0,6,base(1)+32'h7400,7,2,1,0);
		tick(20); @(negedge aclk); hold_r=0; drain_all();
		@(negedge aclk); interleave_mode=0;
		$display("TEST contention, stalls, byte strobes, legal burst forms");
		@(negedge aclk); stalls=1; backpressure=1;
		fork
			write_read(0,4,base(2)+32'h2000,15,2,1,500);
			write_read(1,4,base(2)+32'h2100,15,2,1,501);
			write_read(2,4,base(2)+32'h2200,15,2,1,502);
			write_read(3,4,base(2)+32'h2300,15,2,1,503);
		join
		write_read(0,3,base(0)+32'h3000,15,2,0,510);
		write_read(1,3,base(1)+32'h303c,15,2,2,511);
		write_read(2,3,base(2)+32'h3101,7,1,1,512);
		write_read(3,3,base(3)+32'h3203,7,0,1,513);
		write_read(0,3,base(0)+32'h4000,255,2,1,514);
		write_read(1,3,base(1)+32'h4406,3,1,2,515);
		fork random_traffic(0); random_traffic(1); random_traffic(2); random_traffic(3); join
		drain_all();

		$display("TEST owner table holds through long competing bursts and stalls");
		owner_stalls_before=ownership[1].check_owner.stalled_cycles;
		fork
			write_read(0,4,base(1)+32'hb000,63,2,1,900);
			write_read(1,4,base(1)+32'hb100,63,2,1,901);
			write_read(2,4,base(1)+32'hb200,63,2,1,902);
			write_read(3,4,base(1)+32'hb300,63,2,1,903);
		join
		drain_all();
		if (ownership[1].check_owner.stalled_cycles<=owner_stalls_before)
			$fatal(1,"Owner-stall scenario was not observed");
		$display("OWNER CHECK target=1 allocations=%0d completed=%0d stalled_cycles=%0d",
			ownership[1].check_owner.allocations, ownership[1].check_owner.completed,
			ownership[1].check_owner.stalled_cycles);
		$display("TEST unmapped DECERR burst and downstream response forwarding");
		saved_aw=down_aw[0]+down_aw[1]+down_aw[2]+down_aw[3]; saved_ar=down_ar[0]+down_ar[1]+down_ar[2]+down_ar[3];
		write_tx(0,15,32'h40000000,7,2,1,600,3); read_tx(0,15,32'h40000000,7,2,1,3);
		if(saved_aw!=down_aw[0]+down_aw[1]+down_aw[2]+down_aw[3] || saved_ar!=down_ar[0]+down_ar[1]+down_ar[2]+down_ar[3]) $fatal(1,"Unmapped request leaked to a target");
		@(negedge aclk); response_code[3]=2;
		write_tx(3,12,base(3)+32'h5000,3,2,1,610,2); read_tx(3,12,base(3)+32'h5000,3,2,1,2);
		/* EXOKAY forwarding uses a matching exclusive-read/write sequence.
		 * The subordinate model supplies programmed responses, not a monitor. */
		@(negedge aclk); response_code[3]=1; exclusive_mode=1;
		read_tx(3,13,base(3)+32'h5100,3,2,1,1);
		write_tx(3,13,base(3)+32'h5100,3,2,1,611,1); read_tx(3,13,base(3)+32'h5100,3,2,1,1);
		@(negedge aclk); response_code=0; exclusive_mode=0;

		$display("TEST mapped-to-DECERR same-ID ordering");
		@(negedge aclk); hold_b=1; hold_r=1;
		send_aw(2,14,32'h5200,3,2,1,0); send_w(2,32'h5200,3,2,1,615); tick(20);
		send_ar(2,14,32'h5200,3,2,1,0); tick(20);
		saved_b=bhead[2][14]; saved_r=rhead[2][14];
		fork
			begin send_aw(2,14,32'h40001000,3,2,1,3); send_w(2,32'h40001000,3,2,1,616); end
			begin send_ar(2,14,32'h40001000,3,2,1,3); end
			begin
				tick(30);
				if(bhead[2][14]!=saved_b || rhead[2][14]!=saved_r) $fatal(1,"DECERR overtook mapped same-ID transaction");
				@(negedge aclk); hold_b=0; hold_r=0;
			end
		join
		drain_all();
		$display("TEST DECERR-to-mapped ordering and no B before final W");
		saved_aw=down_aw[1];
		send_aw(2,14,32'h40002000,3,2,1,3);
		fork
			begin send_aw(2,14,base(1)+32'h5400,3,2,1,0); end
			begin
				tick(30);
				if(m_bvalid[2]) $fatal(1,"DECERR BVALID preceded final W transfer");
				if(down_aw[1]!=saved_aw) $fatal(1,"Mapped AW overtook same-ID DECERR");
				send_w(2,32'h40002000,3,2,1,617);
			end
		join
		send_w(2,base(1)+32'h5400,3,2,1,618); drain_all();
		@(negedge aclk); force_rstall=4'b0100;
		saved_ar=down_ar[1]; send_ar(2,14,32'h40002000,3,2,1,3);
		fork
			begin send_ar(2,14,base(1)+32'h5400,3,2,1,0); end
			begin
				tick(30); if(down_ar[1]!=saved_ar) $fatal(1,"Mapped AR overtook stalled same-ID DECERR");
				@(negedge aclk); force_rstall=0;
			end
		join
		drain_all();
		$display("TEST repeated DECERR writes while BREADY is stalled");
		@(negedge aclk); force_bstall=4'b0100;
		saved_b=bhead[2][12]+bhead[2][13];
		send_aw(2,12,32'h40003000,3,2,1,3); send_w(2,32'h40003000,3,2,1,640);
		fork
			begin
				send_aw(2,13,32'h40003100,3,2,1,3); send_w(2,32'h40003100,3,2,1,641);
				send_aw(2,12,32'h40003200,3,2,1,3); send_w(2,32'h40003200,3,2,1,642);
				send_aw(2,13,32'h40003300,3,2,1,3); send_w(2,32'h40003300,3,2,1,643);
			end
			begin
				tick(80);
				if(!m_bvalid[2] || bhead[2][12]+bhead[2][13]!=saved_b) $fatal(1,"DECERR response was lost or consumed during B stall");
				@(negedge aclk); force_bstall=0;
			end
		join
		drain_all();
		if(bhead[2][12]+bhead[2][13]!=saved_b+4) $fatal(1,"DECERR B backpressure dropped a completion");
		$display("TEST reset with transactions in flight, then recovery");
		@(negedge aclk); hold_b=15; hold_r=15;
		send_aw(0,14,32'h6000,3,2,1,0); send_w(0,32'h6000,3,2,1,620); tick(20);
		send_ar(0,14,32'h6000,3,2,1,0); tick(20);
		if(live_w[0]==0 || live_r[0]==0) $fatal(1,"No in-flight reset scenario");
		@(negedge aclk); aresetn=0; m_awvalid=0; m_wvalid=0; m_arvalid=0;
		tick(6); @(negedge aclk); hold_b=0; hold_r=0; aresetn=1;
		tick(40); if((|m_bvalid)||(|m_rvalid)) $fatal(1,"Stale response after reset");
		write_read(0,1,32'h7000,7,2,1,630); drain_all();
		if(early_w_cycles==0) $fatal(1,"W-before-AW not exercised");
		if(aw_waits_for_w==0) $fatal(1,"Target waiting for WVALID before AWREADY not exercised");
		if(peak_w[0]<4 || peak_r[0]<4) $fatal(1,"Outstanding metric failed");
		$display("REGRESSION PASS seed=%0d writes=%0d reads=%0d read_beats=%0d MAX_PARALLEL_W=%0d MAX_PARALLEL_R=%0d peak_master0_W=%0d peak_master0_R=%0d RW_overlap=%0d early_W_cycles=%0d interleaved_R_switches=%0d",seed,writes_checked,reads_checked,read_beats_checked,max_w_lanes,max_r_lanes,peak_w[0],peak_r[0],rw_overlap,early_w_cycles,interleaved_reads);
		$finish;
	end
	initial begin #5000000; $fatal(1,"Global simulation watchdog expired"); end
endmodule



