# Uploaded archive, dependency and ownership audit

Audit finalized: 27 October 2026; upstream comparison performed 26 October 2026. The input was `axi4_4x4_crossbar_complete.zip`, SHA-256 `531a405ab48a729d661f2c56c76cceb82c62b7eab5471c3d8243b291ed0e89b0`. All 65 entries in its `SHA256SUMS` matched the uploaded bytes. A matching checksum proves archive consistency, not hardware correctness.

## What was already complete

The uploaded standalone crossbar already contained its entire vendor module dependency closure: eight vendor modules plus the project wrapper. There was no missing `axi_register.v`, RAM, FIFO, mux or demux module needed by that top. `axi_register_rd.v` and `axi_register_wr.v` are instantiated directly. Adding unrelated upstream files would not fix a missing SoC integration.

The archive included self-checking traffic, target models, passive protocol monitors, configuration tests, checker negative tests, build scripts, a synthesis script, licenses, architecture/integration guidance, and prior validation logs. Those logs were treated as historical evidence until rerun. The uploaded artifact did not contain the older `soc_project` struct-based integration, endpoint ID adaptation, or a named standalone owner-table module. The corrected deliverable supplies those integration sources and the explicit owner-table dependency.

## Pinned vendor provenance and dependency table

The reference is [Alex Forencich/verilog-axi at commit 516bd5dadc3365b7f9e225d2af8fe0b8d804fe53](https://github.com/alexforencich/verilog-axi/tree/516bd5dadc3365b7f9e225d2af8fe0b8d804fe53). All eight RTL files, COPYING and README were fetched at that exact revision for comparison. The repository's own notice says it is deprecated in favor of its successor; this deliverable preserves the requested pinned reference and its MIT notices. It does not claim upstream maintenance of local patches.

| Module/file | Required children | Audit disposition |
|---|---|---|
| `axi4_interconnect_4x4.sv` | `axi_crossbar` | Original packed Mini-SoC ports retained; four sources and two-bit source-routing tag reviewed |
| `axi_crossbar.v` | `axi_crossbar_wr`, `axi_crossbar_rd` | Added missing downstream register-type parameter forwarding |
| `axi_crossbar_wr.v` | `axi_crossbar_addr`, `arbiter`, `axi_register_wr`, `axi_write_owner_table` | Retained prior error/W fixes; corrected buffered B tag boundary; explicit owner storage dependency added |
| `axi_crossbar_rd.v` | `axi_crossbar_addr`, `arbiter`, `axi_register_rd` | Prior source-qualified R routing and per-beat arbitration patches retained |
| `axi_crossbar_addr.v` | None | Prior decode-error destination/credit patch retained |
| `axi_register_wr.v` | None | Added explicit combinational reset evaluation for AW/W/B simple and skid slices |
| `axi_register_rd.v` | None | Added explicit combinational reset evaluation for AR/R simple and skid slices |
| `arbiter.v` | `priority_encoder` | Unmodified upstream text; round-robin/blocking grants |
| `priority_encoder.v` | None | Unmodified upstream text |
| `axi_write_owner_table.sv` | None | Project-owned synthesizable entry, instantiated once per target |
| `COPYING`, `UPSTREAM_README.md` | None | Unmodified upstream text; original notices retained |

The original vendor patch replayed successfully against the pinned upstream and reconstructed the original uploaded vendor files. The regenerated `docs/vendor_fixes.patch` reconstructs the final six modified vendor files. Patch replay compares LF-normalized text; `VENDOR_MANIFEST.json` separately checks exact packaged bytes and exact fetched upstream hashes. The custom owner-table source is a project dependency, not an upstream file disguised as vendor code.

## Defects found and addressed

1. **Buffered B response tag came from the wrong boundary.** The write engine used external target BID to select a source while BVALID/payload could already reside in a target-side register. A legal target can change idle BID after its response is accepted. With a simple B slice this redirected a response to the wrong master. The selector now uses `int_m_axi_bid`. The before-fix failure is preserved in `reports/audit_evidence/b_slice_before_fix.log`; the testbench now clears idle BID and includes buffered-B variants.
2. **Five downstream slice parameters were ignored.** `axi_crossbar.v` declared but did not forward `M_AW_REG_TYPE`, `M_W_REG_TYPE`, `M_B_REG_TYPE`, `M_AR_REG_TYPE`, `M_R_REG_TYPE`. All are now forwarded. Defaults match both engines exactly: AW=1, W=2, B=0, AR=1, R=0. Default pipeline behavior is unchanged.
3. **SoC integration was left to the reader.** The original documentation acknowledged the old eight-bit-ID structs were incompatible with widened IDs. The corrected package adds struct mapping and an explicit bounded ID adapter in the preserved Mini-SoC directory layout. See the SoC integration documentation and validation report for its supported profile and limitations.
4. **Owner state was embedded rather than visible as the requested module.** The real target W-owner registers now reside in `axi_write_owner_table.sv`, with the existing source route state and grant sequencing preserved. Ownership is verified at the internal interface where the registers apply.

5. **Reset release with initially-low READY exposed unknown next-state valid bits.** In the event-driven simulator, an `always @*` block could remain unevaluated when all of its initialized inputs stayed unchanged through reset. The first post-reset clock then captured unknown `valid_next` bits. All ten simple/skid channel combinational blocks in the read/write register modules now reference reset and explicitly clear their next-valid state during reset. This preserves synchronous registered reset behavior and leaves normal next-state equations unchanged. A legal target waiting for WVALID before AWREADY exposed the issue; the strengthened regression now includes that target behavior. The pre-fix trace is retained as `reports/audit_evidence/reset_before_fix.log`.

The retained decode-error ordering, final-W-before-error-B, source WREADY gating, and R interleaving patches were reviewed in their actual code paths and their rationale is documented in `VENDOR_PATCHES.md`. No claim of exhaustive formal proof is made.

## Hardware owner table

| Table/state | Physical owner | Index/key | Contents | Allocation | Retirement |
|---|---|---|---|---|---|
| Target W-owner entry | `axi_crossbar_wr.m_ifaces[t].owner_table_inst` | Target 0..3 | Valid + two-bit source master | Target AW arbitration grant, before AWREADY if needed | Internal WVALID && WREADY && WLAST |
| Source W route | `axi_crossbar_wr.s_ifaces[m]` | Source 0..3 | Target select, valid, local-error drop bit | Accepted write-route command from address decoder | That source's internal accepted WLAST |
| Write ID/destination table | Write engine's `axi_crossbar_addr` instances | Source + active AWID thread | ID, destination/region or error sink, count | Internal write admission | Accepted internal B completion |
| Read ID/destination table | Read engine's `axi_crossbar_addr` instances | Source + active ARID thread | ID, destination/region or error sink, count | Internal read admission | Accepted internal RLAST completion |
| Target issue counter | Read/write `m_ifaces[t]` | Target + direction | Admitted transaction count | Internal address handshake | B or final R handshake |
| Return owner | Widened BID/RID tag | Upper two ID bits | Original source master | Added on outgoing AW/AR | Removed on B/R routing |

CPU=0, DMA=1, GPU=2, NPU=3. The owner entry is held through backpressure and all beats of one W burst. The entry may release before the external endpoint consumes a buffered final W beat; channel registers preserve the order at that boundary. W ownership ends at WLAST, while the transaction can remain outstanding awaiting B. Four target owner entries can be valid simultaneously for four different sources. The implementation does not add a global one-master-at-a-time lock or use WDATA as an address.

## Maintenance ownership table

These are responsibility roles, not assignments to named people.

| Area | Source/ownership role | Maintenance responsibility |
|---|---|---|
| Vendor baseline | Alex Forencich/verilog-axi, MIT | Preserve original notices and pinned provenance |
| Local vendor fixes | Mini-SoC integration maintainer | Review/retest patches on any upstream update; refresh hashes and patch replay |
| Wrapper and owner table | Mini-SoC RTL maintainer | Port compatibility, reset contract, routing/ownership behavior |
| `soc_project/common`, `axi`, `soc_top` | SoC integration maintainer | Struct widths, map, endpoint profile and ID preservation |
| Testbenches/checkers | Verification maintainer | Scoreboards, legal stimulus, negative controls and regression coverage |
| Scripts/manifests/reports | Build/release maintainer | Reproducible commands, fail-closed results and artifact integrity |
| External DDR/SRAM/APB/accelerator IP | Endpoint integrator | Actual endpoint protocol support, timing, resets and implementation signoff |

## Reproduce the audit

Run from the extracted project root:

```text
python scripts/audit_sources.py
python scripts/audit_sources.py --upstream-dir <checkout-at-pinned-commit>
python scripts/audit_sources.py --original-zip <original-upload.zip>
```

The default invocation checks packaged hashes, vendor hashes, all source lists and conservative named-module/package dependency scans and include-path checks. `--skip-package` is for an editing worktree whose release hashes have not yet been refreshed. `--report path.json` optionally saves its result. The scanner is not a SystemVerilog parser: it deliberately does not claim parameter legality, full type checking or timing/protocol correctness. Actual elaboration, simulation and synthesis are the relevant checks for those areas; see `reports/VALIDATION.md` for what ran and what remains unverified.

## Uploaded-file inventory

Every uploaded file is listed below. All 65 hashed members passed byte-integrity checking; the SHA256SUMS file itself was validated by checking those entries; dispositions distinguish source review from historical run evidence.

| Uploaded path | Role and audit disposition |
|---|---|
| `.gitignore` | Project metadata; inspected for packaging relevance |
| `LICENSE` | Project MIT license retained; vendor notices independently preserved |
| `Makefile` | Build inputs and source closure reviewed; relevant execution tracked in final report |
| `README.md` | Entry-point claims checked against package contents; completion/limitations updated |
| `SHA256SUMS` | All 65 entries checked against original ZIP contents; new release hashes regenerated |
| `VENDOR_MANIFEST.json` | Exact vendor hashes verified; expanded with upstream hashes and custom dependency |
| `constraints/axi4_interconnect_example.sdc` | Example clock constraint only; no target timing result implied |
| `docs/ARCHITECTURE.md` | Integration/architecture/verification claims compared with shipped RTL; updated where needed |
| `docs/INTEGRATION.md` | Integration/architecture/verification claims compared with shipped RTL; updated where needed |
| `docs/VENDOR_PATCHES.md` | Integration/architecture/verification claims compared with shipped RTL; updated where needed |
| `docs/VERIFICATION_PLAN.md` | Integration/architecture/verification claims compared with shipped RTL; updated where needed |
| `docs/vendor_fixes.patch` | Integration/architecture/verification claims compared with shipped RTL; updated where needed |
| `filelist.f` | Build inputs and source closure reviewed; relevant execution tracked in final report |
| `reports/VALIDATION.md` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_legal.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_negative_1.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_negative_2.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_negative_3.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_negative_4.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/checker_negative_5.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_checker.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_checker.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_checker.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_config.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_config.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_config.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_default.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_default.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_default.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_small.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_small.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_small.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_summary.json` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_testbench.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_testbench.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_testbench.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_wide.backend.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_wide.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/compile_wide.preprocess.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/config.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/simulation_seed_1.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/simulation_seed_2026.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/simulation_seed_42.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/synth_summary.json` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/synthesis.log` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/test_summary.json` | Historical validation evidence; integrity checked, final claims require new execution |
| `reports/validated_sources.sha256` | Historical validation evidence; integrity checked, final claims require new execution |
| `rtl/axi4_interconnect_4x4.sv` | Wrapper interface, parameters, reset and crossbar mapping reviewed |
| `rtl/vendor/verilog_axi/COPYING` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/UPSTREAM_README.md` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/arbiter.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_crossbar.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_crossbar_addr.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_crossbar_rd.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_crossbar_wr.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_register_rd.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/axi_register_wr.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `rtl/vendor/verilog_axi/priority_encoder.v` | Pinned vendor provenance and transitive dependency review; see table above |
| `scripts/questa.do` | Build inputs and source closure reviewed; relevant execution tracked in final report |
| `scripts/run.py` | Build inputs and source closure reviewed; relevant execution tracked in final report |
| `scripts/synth.ys` | Build inputs and source closure reviewed; relevant execution tracked in final report |
| `tb/axi4_protocol_checker.sv` | Verification source reviewed; rerun results and additional cases documented separately |
| `tb/axi4_test_slave.sv` | Verification source reviewed; rerun results and additional cases documented separately |
| `tb/tb_axi4_interconnect.sv` | Verification source reviewed; rerun results and additional cases documented separately |
| `tb/tb_checker_negative.sv` | Verification source reviewed; rerun results and additional cases documented separately |
| `tb/tb_config.sv` | Verification source reviewed; rerun results and additional cases documented separately |
