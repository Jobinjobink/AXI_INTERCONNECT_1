`timescale 1ns/1ps
package axi_pkg;
	localparam int unsigned ADDR_W=32, DATA_W=32, ID_W=8;
	localparam logic [1:0] OKAY=0, EXOKAY=1, SLVERR=2, DECERR=3;
	typedef struct packed {
		logic [7:0] id; logic [31:0] addr; logic [7:0] len;
		logic [2:0] size; logic [1:0] burst; logic lock;
		logic [3:0] cache; logic [2:0] prot; logic [3:0] qos;
	} addr_t;
	typedef struct packed {logic [31:0] data; logic [3:0] strb; logic last;} w_t;
	typedef struct packed {logic [7:0] id; logic [1:0] resp;} b_t;
	typedef struct packed {logic [7:0] id; logic [31:0] data; logic [1:0] resp; logic last;} r_t;
	typedef struct packed {
		addr_t aw; logic awvalid; w_t w; logic wvalid; logic bready;
		addr_t ar; logic arvalid; logic rready;
	} req_t;
	typedef struct packed {
		logic awready,wready; b_t b; logic bvalid;
		logic arready; r_t r; logic rvalid;
	} rsp_t;
	function automatic logic [31:0] merge_bytes(input logic [31:0] a,b,input logic [3:0] s);
		for(int i=0;i<4;i++) merge_bytes[i*8+:8]=s[i]?b[i*8+:8]:a[i*8+:8];
	endfunction
	// Scalar arguments are compatible with older synthesis frontends.
	function automatic logic [31:0] next_addr(input logic [7:0] length,input logic [2:0] size,input logic [1:0] burst,input logic [31:0] current);
		case(burst)
			0: next_addr=current;
			// Preserve the wrap-window base and advance one aligned beat inside it.
			2: next_addr=(current & ~(((32'd1+length)<<size)-32'd1)) |
				(((current & ~((32'd1<<size)-32'd1))+(32'd1<<size)) & (((32'd1+length)<<size)-32'd1));
			default: next_addr=(current & ~((32'd1<<size)-32'd1))+(32'd1<<size);
		endcase
	endfunction
	// This SoC's slaves accept aligned 32-bit beats, including byte strobes.
	function automatic logic legal(input logic [31:0] address,input logic [7:0] length,input logic [2:0] size,input logic [1:0] burst,input logic locked);
		legal=size==2 && address[1:0]==0 && !locked && burst!=3 &&
			(burst!=1 || ({1'b0,address[11:0]}+((13'(length)+13'd1)<<2))<=13'd4096) &&
			(burst!=0 || length<=15) &&
			(burst!=2 || length==1 || length==3 || length==7 || length==15);
	endfunction

    // Target-side types preserve the two crossbar route bits in addition to
    // the original eight-bit source ID. Never connect these by truncation.
    localparam int TARGET_ID_W=ID_W+2;
    typedef struct packed {
        logic [9:0] id; logic [31:0] addr; logic [7:0] len;
        logic [2:0] size; logic [1:0] burst; logic lock;
        logic [3:0] cache; logic [2:0] prot; logic [3:0] qos;
        logic [3:0] region;
    } target_addr_t;
    typedef struct packed {logic [9:0] id; logic [1:0] resp;} target_b_t;
    typedef struct packed {logic [9:0] id; logic [31:0] data; logic [1:0] resp; logic last;} target_r_t;
    typedef struct packed {
        target_addr_t aw; logic awvalid; w_t w; logic wvalid; logic bready;
        target_addr_t ar; logic arvalid; logic rready;
    } target_req_t;
    typedef struct packed {
        logic awready,wready; target_b_t b; logic bvalid;
        logic arready; target_r_t r; logic rvalid;
    } target_rsp_t;
endpackage

