# Mini-SoC AXI4 4 x 4 crossbar

A synthesizable AXI4 interconnect for four masters (CPU, DMA, GPU and NPU) and four independently accessible targets. Four masters can transfer to four different slaves concurrently. Read and write fabrics progress independently, with multiple transactions outstanding and arbitration local to each target.

The commented SystemVerilog top integrates the MIT-licensed [Alex Forencich crossbar](https://github.com/alexforencich/verilog-axi), pinned at `516bd5dadc3365b7f9e225d2af8fe0b8d804fe53`, with local correctness patches. Original vendor headers are retained. This is an integration and patched dependency, not a claim that vendor switching logic was newly written for this project. Upstream marks `verilog-axi` deprecated in favor of its successor; pinning provides reproducibility, not a maintenance guarantee. See [the patch notes](docs/VENDOR_PATCHES.md).

## Start here

1. Read [the architecture](docs/ARCHITECTURE.md) for IDs, ownership and outstanding capacity.
2. Read [the integration guide](docs/INTEGRATION.md) for ports, parameters and reset.
3. Inspect `rtl/axi4_interconnect_4x4.sv`, then the vendor read/write engines and address admission module.
4. Run the regression and read `reports/VALIDATION.md` for actual executed results.
5. Read the [hardware owner table](docs/OWNER_TABLE.md), [module responsibility table](docs/MODULE_OWNERS.md), and [archive/dependency audit](docs/AUDIT_VENDOR.md).
6. Use the [Mini-SoC struct integration](docs/SOC_INTEGRATION.md) under `soc_project/`.
7. Use [the verification plan](docs/VERIFICATION_PLAN.md) for further UVM and signoff work.

## Default configuration

| Property | Default |
|---|---|
| Top | `axi4_interconnect_4x4` |
| Interfaces | Four master-facing `m_*`, four slave-facing `s_*` |
| Address / data | `ADDR_WIDTH=32`, `DATA_WIDTH=32` |
| Upstream / downstream ID | `ID_WIDTH=4` / `ID_WIDTH+2=6` |
| Active IDs per master | `THREADS=4`, separately for reads and writes |
| Admission credits per master | `ACCEPT=8`, separately for reads and writes |
| Issue credits per target | `ISSUE=8`, separately for reads and writes |
| Arbitration | Round robin; QOS metadata forwarded |
| Bursts | Legal FIXED, INCR, WRAP; no burst splitting |
| Decode miss / blocked connection | Local DECERR completion |
| Clock / reset | Single `aclk`; synchronous active-low `aresetn` |

Internal credits and external outstanding counts are not identical: register slices may retain a completed response after an internal credit returns. The architecture guide explains this boundary.

## Default address map

| Target | Intended external endpoint | Inclusive byte range | Size |
|---|---|---|---|
| S0 | DDR controller AXI port | `0000_0000` .. `0FFF_FFFF` | 256 MiB |
| S1 | SRAM AXI port | `1000_0000` .. `1000_FFFF` | 64 KiB |
| S2 | AXI-to-APB bridge AXI port | `2000_0000` .. `2000_FFFF` | 64 KiB |
| S3 | Accelerator AXI port | `3000_0000` .. `3000_FFFF` | 64 KiB |

Addresses pass through unchanged. These are external AXI ports; DDR PHY, SRAM, APB bridge and accelerator implementations are not included. S2 does not expose APB wires. The supplied SoC integration maps named CPU/NPU/GPU/DMA request/response structs into these ports and provides either native 10-bit target IDs or an optional bounded adapter for legacy 8-bit-ID AXI targets.

## Run and reuse

From the extracted project directory, with Python 3 and the runner's simulator available:

```text
python scripts/run.py test
```

The default regression uses seeds 1, 42 and 2026. On the Windows host used here, run the clean separate-stage build mode:

```text
python scripts/run.py test --direct-backend --tool-dir <Icarus-root>
python scripts/run.py synth --tool-dir <OSS-CAD-Suite-root>
```

To check the SoC integration and both native and legacy-ID wrappers, including synthesis:

```text
python scripts/run.py soc --direct-backend --tool-dir <Icarus-root> --yosys-dir <OSS-CAD-Suite-root>
python scripts/run.py all --direct-backend --tool-dir <Icarus-root> --yosys-dir <OSS-CAD-Suite-root>
```

On hosts where the ordinary Icarus launcher works, omit `--direct-backend`. The SoC runner uses explicit channel structs to avoid known nested-struct expression limitations in the tested Icarus build. Native SystemVerilog sources remain the implementation source of truth.

Python 3.9+ and external Icarus binaries are required. Synthesis requires Yosys with slang. `make test`/`make synth` are optional shortcuts; `scripts/questa.do` is a separate simulator example. `constraints/axi4_interconnect_example.sdc` contains an example clock, not a timing guarantee.

The runner help describes supported tool options. Missing tools are setup failures, not test passes. `reports/VALIDATION.md` records the tools, commands, cases and results actually executed. Vendor history does not replace testing this wrapper and its local changes.

```text
rtl/axi4_interconnect_4x4.sv     Commented Mini-SoC wrapper
rtl/axi_write_owner_table.sv    Actual per-target write-owner entry (four instances)
rtl/vendor/verilog_axi/         Pinned crossbar and dependencies
soc_project/                   common/rtl, axi/rtl, soc_top/rtl struct integration
tb/                            Self-checking verification
scripts/                       Build/regression entry points
docs/                          Architecture, integration, patches, test plan
reports/                       Actual validation evidence
filelist.f                     Synthesizable compile order
```

Retain the dependency set and license notices when copying the IP. Use the synthesizable filelist for implementation; testbench models and protocol assertions are verification sources.

This deliverable is not silicon signoff, a guaranteed clock frequency or AXI certification. No CDC, width conversion, coherence, ATOP/AXI5, timeout cancellation or system exclusive monitor is supplied. Legal AXI sources, correct targets and coordinated reset are required. The older complete Mini-SoC has a different 4x7 topology. Its directory style and source-side struct layout are retained in the supplied integration layer; its entire processor/peripheral system has not been rebuilt or signed off. Use `soc_axi4_subsystem` for full widened target IDs, or `soc_axi4_legacy_subsystem` for one read and one write outstanding per legacy target. The legacy adapter preserves route IDs but does not convert AXI4 bursts into AXI-Lite/APB transfers.

## What this correction adds

The uploaded ZIP's eight vendor RTL dependencies were already present. This revision fixes ignored target register settings, buffered write-response routing, and reset-event simulation behavior; adds the requested real owner-table module, SoC struct wiring and legacy ID preservation; and expands the tests and audit evidence. All modifications and limits are in [the vendor patch notes](docs/VENDOR_PATCHES.md) and [validation report](reports/VALIDATION.md).

## Integrity and packaging

```text
python scripts/audit_sources.py
python scripts/run.py audit
python scripts/package.py --output ../axi4_4x4_crossbar_corrected.zip
```

The first command checks the delivered package's SHA-256 hashes without modifying files. `run.py audit` checks source dependencies and vendor hashes while allowing reports to change. Running tests regenerates reports, so release package hashes naturally become stale afterward; regenerate them with `package.py`. The ZIP excludes generated simulators, netlists, caches and waveforms. No external download is needed to compile the supplied source; simulator/synthesis installations are prerequisites.

