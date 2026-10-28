# Integration into the user's Mini-SoC structure

## What is preserved

The prior local soc_project uses common/rtl/axi_pkg.sv, axi/rtl/,
soc_top/rtl/, subsystem filelists, and packed AXI channel structs.
The supplied integration keeps this directory organization and preserves the
existing addr_t, w_t, b_t, r_t, req_t, rsp_t layout and helper
functions. Its master address/data/ID widths remain 32/32/8.

The old soc_top.sv instantiates a **4x7** fabric, with CPU/NPU/GPU/DMA as
master array entries 0/1/2/3, and seven separate ROM/SRAM/peripheral/control/DDR
targets. A 4x4 fabric cannot preserve that topology by changing only a module
name. This archive supplies new named integration tops and a four-target map.
It does not overwrite the earlier project or copy its unrelated CPU, DMA,
GPU, NPU, DDR, APB or physical I/O implementations.

## Source tree and build order

| File | Function |
|---|---|
| soc_project/common/rtl/axi_pkg.sv | Existing 8-bit source structs plus distinct 10-bit target structs |
| soc_project/common/rtl/soc_address_map_pkg.sv | Four-target map and original master-order constants |
| soc_project/axi/rtl/axi4_struct_crossbar.sv | Explicit struct/channel mapping into the packed-port crossbar |
| soc_project/axi/rtl/axi4_legacy_id_adapter.sv | Optional one-slot-per-direction adapter to 8-bit target IDs |
| soc_project/soc_top/rtl/soc_axi4_subsystem.sv | Native 10-bit-target integration boundary |
| soc_project/soc_top/rtl/soc_axi4_legacy_subsystem.sv | Fabric plus four legacy target adapters |
| soc_project/tb/ | End-to-end and legacy-adapter self-checking benches |
| soc_project/filelist.f | Complete synthesizable source list, interpreted from archive root |
| soc_project/scripts/run.py | Compile, simulate and optionally synthesize |
| soc_project/scripts/synth.ys | Slang/Yosys elaboration, optimization and structural checks |

Compile only the supplied common/rtl/axi_pkg.sv as the definition of
axi_pkg. Do not also compile the old project's second axi/rtl/axi_pkg.sv
or its old fabric top. New types add fields; existing source-side structs
are unchanged. Data/address widths in this Mini-SoC profile are fixed; the
standalone packed-port core remains parameterized.

The explicit channel aliases in axi4_struct_crossbar.sv avoid a nested
packed-struct member expression issue in the tested Icarus compiler. They
are wires and introduce no extra state or latency.

## Master mapping and owner identities

Named ports retain the old SoC declaration order. The internal crossbar's
packed lane order is the standalone core's CPU/DMA/GPU/NPU convention.

| External source | Previous array index | Core lane / owner | Target ID |
|---|---:|---:|---|
| CPU | 0 | 0 | {2'b00, cpu_id[7:0]} |
| NPU | 1 | 3 | {2'b11, npu_id[7:0]} |
| GPU | 2 | 2 | {2'b10, gpu_id[7:0]} |
| DMA | 3 | 1 | {2'b01, dma_id[7:0]} |

The route mask parameters use **core lane order**, not old array order.
For example, CONNECT_WRITE[target*4+3] controls NPU writes.
Responses restore all eight original ID bits. No source ID bit is reused
as the route index.

The physical write owner table remains in the core; see the architecture
and ownership documentation. The optional legacy adapters have two further
ownership slots per target:

| Slot | Allocate | Stored owner information | Retire |
|---|---|---|---|
| Write | Wide-side AW handshake | Entire AW descriptor including 10-bit ID | Wide-side B handshake |
| Read | Wide-side AR handshake | Entire AR descriptor including 10-bit ID | Wide-side final R handshake |

These response ownership slots have different lifetimes from the core's
W owner, which is released on accepted WLAST.

## Native target integration

Use soc_axi4_subsystem when endpoints can preserve ten-bit IDs.
target_req_t has AW/AR fields with a 10-bit ID and a four-bit region.
target_rsp_t returns 10-bit BID/RID. Other channel widths match the old
source-side structs. No USER extensions are added.

All five channels are mapped explicitly. AW/AR region inputs are absent in
the old source struct and tied to zero; the core generates downstream
region zero because each target has one region. Cache, protection, QoS,
lock, lengths, sizes, strobes and LAST are forwarded. The core uses round
robin arbitration; QoS is metadata only.

The named targets are DDR, SRAM, AXI-to-APB bridge and accelerator. Their
default apertures are respectively 0x00000000..0x0fffffff,
0x10000000..0x1000ffff, 0x20000000..0x2000ffff, and
0x30000000..0x3000ffff. APB wires are not exposed: an actual full-AXI
bridge must connect at apb_req/apb_rsp.

To preserve the old master array wiring at a new top-level boundary:

    soc_axi4_subsystem fabric (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(masters[0]), .cpu_rsp(master_rsp[0]),
        .npu_req(masters[1]), .npu_rsp(master_rsp[1]),
        .gpu_req(masters[2]), .gpu_rsp(master_rsp[2]),
        .dma_req(masters[3]), .dma_rsp(master_rsp[3]),
        .ddr_req(ddr_req), .ddr_rsp(ddr_rsp),
        .sram_req(sram_req), .sram_rsp(sram_rsp),
        .apb_req(apb_req), .apb_rsp(apb_rsp),
        .accel_req(accel_req), .accel_rsp(accel_rsp)
    );

The target variables above must be axi_pkg::target_req_t/target_rsp_t.
Review endpoint address decoders and software maps; the old DDR, ROM and
multiple accelerator-control locations are not implicitly remapped.

## Legacy target integration

Use soc_axi4_legacy_subsystem if an existing endpoint uses the original
eight-bit req_t/rsp_t. Each axi4_legacy_id_adapter captures an AW and
an AR independently, passes the low ID bits to the legacy target, and
restores the complete saved 10-bit ID on B/R. This is safe for response
routing because the adapter permits only one transaction per direction
at its legacy target. Simply truncating IDs without these slots is unsafe.

AW buffering is independent of target AWREADY. W is enabled after the
wide-side address is captured, even if the legacy target waits for WVALID
before asserting AWREADY. B cannot retire ownership until the address and
last write data beat have both completed. Backpressure retains ownership
through the final response handshake.

The native crossbar retains its multiple-outstanding design. The legacy
option serializes each target to one write and one read, independently.
Different targets can still operate concurrently. Throughput and available
outstanding capacity are lower than the native-target option.

This adapter does **not** convert burst/size profiles, split bursts, provide
an exclusive monitor, or repair invalid endpoint responses. Use unlocked
traffic (AxLOCK=0) with the legacy option: discarding route bits at the
legacy endpoint can alias its exclusive reservation identity across sources.
Existing Mini-SoC endpoints may restrict traffic to aligned 32-bit beats;
their existing legality checks still apply. The retained axi_pkg::legal
helper expresses the previous endpoint profile, not a new restriction in
the native fabric.

## Reset and validation

Both integration tops and the adapter use the fabric's clock and synchronous
active-low reset. Reset all connected endpoints together. Reset discards
pending ownership; it neither rolls back accepted writes nor returns
cancellation responses.

Executed validation is recorded in reports/soc_detail_summary.json,
reports/tb_soc_axi4_subsystem.log, reports/tb_legacy_id_adapter.log,
and reports/soc_synthesis.log.

- Native and legacy systems each exercise every master-to-target path using
  four-beat INCR writes and reads, colliding source IDs, stalls and response
  backpressure. Across both systems: 32 writes, 32 reads, 128 data beats
  checked per direction. Tests check metadata, routed target IDs and
  returned source IDs/data.
- The adapter unit test runs 41 concurrent read/write burst pairs. Walking
  source-ID bits plus zero/all-ones exercise all eight ID bits across all
  four route owners. It checks target AW withholding until WVALID,
  backpressure, SLVERR forwarding, slot serialization, reset in flight and
  recovery.
- Both integration tops compile cleanly. The legacy-integrated top passes
  generic slang/Yosys synthesis and check -assert with zero structural
  problems. Generic cell counts are tool-dependent and are not device area.
  Slang reports one existing vendor warning for shifting a four-bit thread
  priority mask right by four at thread zero. That constant case evaluates
  to zero, the intended empty mask of earlier threads. It is not a failed
  structural check; the full warning remains in the synthesis log.
- The integration benches hold target admission decisions across sampling
  edges, avoiding race conditions in reused verification-model queue logic.

These integration tests do not establish full-SoC execution, firmware boot,
DDR calibration, APB peripheral behavior, endpoint-specific burst support,
exclusives, formal protocol proof, CDC, reset-domain safety, or physical timing.
No UVM/coverage closure or technology mapping was run. The standalone core's
broader regression is recorded separately in the main validation report.

