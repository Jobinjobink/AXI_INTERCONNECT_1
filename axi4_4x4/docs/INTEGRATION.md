# Integration guide

## Interface naming and packing

`m_*` faces an external AXI master; `s_*` faces an external AXI slave. These names preserve the previous standalone Mini-SoC AXI project. Internally the vendor uses the opposite perspective: its `s_axi_*` ports are crossbar inputs, and its `m_axi_*` ports are crossbar outputs.

| Wrapper ports | Vendor ports | Connected component |
|---|---|---|
| `m_*[0]` .. `m_*[3]` | `s_axi_*` elements 0 .. 3 | CPU, DMA, GPU, NPU |
| `s_*[0]` .. `s_*[3]` | `m_axi_*` elements 0 .. 3 | DDR, SRAM, APB bridge, accelerator |

Payloads use packed arrays, for example `logic [3:0][ADDR_WIDTH-1:0] m_awaddr`. Element zero occupies the least-significant field. `m_awaddr[2]` is GPU's whole address, not address bit two. Handshake fields are four-bit vectors. Port count is fixed at four.

Every transfer occurs on a rising `aclk` edge with VALID and READY high. A source retains VALID and every payload field while stalled. Payload with VALID low has no transaction meaning.

## Port groups

Widths below are per port. Upstream ID width is ID_WIDTH; downstream ID width is ID_WIDTH+2.

| Channel | Fields | Widths | Master-facing direction | Slave-facing direction |
|---|---|---|---|---|
| AW | `awid` | upstream/downstream ID | input | output |
| AW | `awaddr`, `awlen`, `awsize`, `awburst` | ADDR_WIDTH, 8, 3, 2 | input | output |
| AW | `awlock`, `awcache`, `awprot`, `awqos`, `awregion` | 1, 4, 3, 4, 4 | input | output |
| AW | `awvalid` / `awready` | 1 / 1 | input / output | output / input |
| W | `wdata`, `wstrb`, `wlast` | DATA_WIDTH, DATA_WIDTH/8, 1 | input | output |
| W | `wvalid` / `wready` | 1 / 1 | input / output | output / input |
| B | `bid`, `bresp` | upstream/downstream ID, 2 | output | input |
| B | `bvalid` / `bready` | 1 / 1 | output / input | input / output |
| AR | `arid` | upstream/downstream ID | input | output |
| AR | `araddr`, `arlen`, `arsize`, `arburst` | ADDR_WIDTH, 8, 3, 2 | input | output |
| AR | `arlock`, `arcache`, `arprot`, `arqos`, `arregion` | 1, 4, 3, 4, 4 | input | output |
| AR | `arvalid` / `arready` | 1 / 1 | input / output | output / input |
| R | `rid`, `rdata`, `rresp`, `rlast` | upstream/downstream ID, DATA_WIDTH, 2, 1 | output | input |
| R | `rvalid` / `rready` | 1 / 1 | output / input | input / output |

AxLEN encodes beats minus one. AxSIZE is log2(bytes per transfer). AxBURST is 00 FIXED, 01 INCR, 10 WRAP; 11 is reserved. Responses are 00 OKAY, 01 EXOKAY, 10 SLVERR, 11 DECERR. Each WSTRB bit controls its corresponding eight-bit data lane. No lane shifting occurs.

Input AWREGION/ARREGION are retained for source compatibility but ignored. Downstream region is generated from decode; with one region per target it is zero. QOS is forwarded but does not select arbitration priority. USER extensions are not exposed. Cache/protection metadata passes through; configured protection filtering can reject requests before forwarding.

## Parameters and address map

| Parameter | Default | Meaning |
|---|---|---|
| `ADDR_WIDTH` | 32 | Address bits; wrapper requires at least 32 |
| `DATA_WIDTH` | 32 | Data bits; valid AXI byte-strobe geometry required |
| `ID_WIDTH` | 4 | Original upstream ID bits preserved |
| `THREADS` | 4 | Active unique IDs per master per direction |
| `ACCEPT` | 8 | Internal admission credits per master per direction |
| `ISSUE` | 8 | Internal issue credits per target per direction |
| `M_BASE_ADDR` | Four packed bases | ADDR_WIDTH bits per target, target zero least significant |
| `M_ADDR_WIDTH` | `{32'd16,32'd16,32'd16,32'd28}` | 32-bit log2 region-size field per target |
| `CONNECT_READ` | `16'hffff` | Target-major 4 x 4 read enables |
| `CONNECT_WRITE` | `16'hffff` | Target-major 4 x 4 write enables |
| `SECURE` | `4'b0000` | One secure-only filter enable per target |

Require ACCEPT >= THREADS >= 1 and ISSUE >= 1. Use the top declarations and elaboration checks as the authority for supported values. Revalidate every configuration used in a real design; a default-configuration pass does not establish all parameter combinations.

```systemverilog
// Default 32-bit concatenation order: S3, S2, S1, S0.
.M_BASE_ADDR({32'h3000_0000,32'h2000_0000,32'h1000_0000,32'h0000_0000}),
.M_ADDR_WIDTH({32'd16,32'd16,32'd16,32'd28})
```

A nonzero width defines an aligned power-of-two aperture. Vendor decode supports 12 through ADDR_WIDTH bits; zero disables a region. Regions must not overlap; bases must be multiples of their size. The vendor all-zero M_BASE_ADDR convention requests automatic address allocation, not four explicit identical zero bases.

Connectivity bit `[target*4 + master]` permits that route. Clearing bit 11 of CONNECT_WRITE prevents master 3 writing target 2. Disabled traffic receives DECERR. `SECURE[target]=1` rejects nonsecure traffic, `AxPROT[1]=1`. This filter requires trusted input attributes and is not a complete system security architecture.

## Clock, reset and endpoints

All ports use one `aclk` domain. Assert `aresetn=0` across clock edges and release it synchronously. This top inverts reset into the vendor synchronous active-high reset. Do not rely on clearing between edges, or issue transfers during reset. Reset every endpoint sharing outstanding transactions together.

Targets must preserve the full widened ID and support the offered burst/size profile or return legal errors. An AXI-Lite-only APB bridge is not directly compatible with arbitrary AXI4 bursts and IDs. LOCK is transported; exclusives require appropriate target support and monitors. The fabric contains no global exclusive monitor, coherence or atomic-operation extension.

## Relationship to the previous SoC

The older standalone project uses similar packed ports, but its serialized implementation and capacity differ. Replace its source list deliberately; compile only one implementation of the top module.

The older `soc_project/common/rtl/axi_pkg.sv` uses fixed eight-bit-ID request/response structs and a narrower supported endpoint profile. Those slave-side IDs cannot directly hold an eight-bit master ID plus two routing bits. This ZIP now supplies explicit signal mapping, distinct 10-bit target request/response types, and an optional single-slot legacy ID adapter with tests. See [SOC_INTEGRATION.md](SOC_INTEGRATION.md). It preserves the old source structs while keeping all two routing bits at the crossbar boundary. The old 4x7 system topology and address map still require deliberate migration to this 4x4 fabric; do not replace the complete old SoC top blindly.

Use the synthesizable filelist in order. Supply device-appropriate clock, I/O and reset constraints, and inspect lint, inferred storage, fanout and synthesis warnings. Place-and-route timing, reset/CDC analysis, power, DFT and integration verification remain separate signoff work. Simulation responders and assertions do not belong in synthesis.
