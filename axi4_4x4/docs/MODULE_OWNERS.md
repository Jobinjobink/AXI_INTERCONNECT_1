# Module ownership and maintenance table

These are responsibility roles, not assignments to named people. The integrator chooses the actual team owners. The **hardware write-owner table** is described separately in [OWNER_TABLE.md](OWNER_TABLE.md).

| Component | Source / responsibility | Changes in this delivery | Maintenance owner role |
|---|---|---|---|
| `axi4_interconnect_4x4` | Mini-SoC packed-port wrapper | Preserved port naming, IDs and map | Interconnect integrator |
| `axi_write_owner_table` | Local synthesizable owner storage | Explicit target write owner, integrated in vendor write path | Interconnect RTL maintainer |
| `axi_crossbar` | Alex Forencich, MIT | Pinned top-level read/write composition | Vendor integration maintainer |
| `axi_crossbar_addr` | Vendor plus documented local patches | Per-ID admission and DECERR ordering | Vendor integration maintainer |
| `axi_crossbar_rd` | Vendor plus documented local patches | Response selection and interleaving | Vendor integration maintainer |
| `axi_crossbar_wr` | Vendor plus documented local patches | Write steering, owner table, error completion | Vendor integration maintainer |
| `axi_register_rd`, `axi_register_wr` | Alex Forencich, MIT | Elastic channel registers | Vendor integration maintainer |
| `arbiter`, `priority_encoder` | Alex Forencich, MIT | Arbitration primitives | Vendor integration maintainer |
| `soc_project/` | Local struct integration in the earlier folder style | Widened target ID types and explicit signal mapping | SoC integration maintainer |
| `tb/` | Local self-checking tests and protocol monitors | Owner-table and regression checks | Verification maintainer |
| `scripts/`, filelists | Local build, audit and packaging | Reproducible checks and failure reporting | Build/release maintainer |
| Constraints | Example only | Real technology constraints remain integrator work | Physical implementation owner |
| CPU/DMA/GPU/NPU, DDR, SRAM, APB bridge, accelerator | External endpoints | Interface contracts documented; not implementations in this IP ZIP | Respective endpoint owners |

Keep local patches and their tests together. When updating the pinned vendor revision, review the complete patch, replay it against that exact revision, rerun simulation and synthesis, and update both manifests. Upstream attribution does not imply that upstream maintains these local changes.
