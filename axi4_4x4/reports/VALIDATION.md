# Executed validation — corrected release, 28 October 2026

The final combined run completed with **PASS**. The tested source hashes match the packaged RTL, testbenches, filelists and scripts. `all_summary.json` records actual commands, exit codes, durations, source hashes and UTC timestamps; `soc_detail_summary.json` records the child integration flow. `validated_sources.sha256` is the tested-source snapshot. Historical pre-fix failures are explicitly isolated under `audit_evidence/`.

## Core simulation

| Run | Writes | Reads | Read beats checked | Peak simultaneous W/R lanes | M0 peak outstanding W/R | Observed target-1 owner stall cycles |
|---|---:|---:|---:|---|---|---:|
| seed_1 | 127 | 128 | 1199 | 4/4 | 8/8 | 604 |
| seed_42 | 127 | 128 | 1193 | 4/4 | 8/8 | 601 |
| seed_2026 | 127 | 128 | 1186 | 4/4 | 8/8 | 623 |
| breg_1 | 127 | 128 | 1193 | 4/4 | 8/8 | 611 |
| breg_2 | 127 | 128 | 1193 | 4/4 | 8/8 | 611 |

Default B-bypass runs use seeds 1, 42 and 2026. Simple and skid B-input slices use seed 42 with the target BID deliberately cleared whenever BVALID is low. Each run exits zero and prints `REGRESSION PASS`; the same-ID and per-ID scoreboards check returned IDs, data, responses and LAST. Both error and permitted address-map configurations are exercised. Read/write channels advance independently.

The main run checks four different target paths in parallel, colliding source IDs, early W, eight outstanding same-ID transactions, destination pinning, out-of-order different-ID responses, crossed/interleaved reads, contention, narrow/unaligned legal accesses, zero and sparse strobes, FIXED/INCR/WRAP, 256-beat INCR, DECERR/SLVERR/EXOKAY forwarding, delayed error W, response backpressure and reset during traffic. The EXOKAY case checks forwarding only; there is no system exclusive monitor.

The added owner phase sends four competing 64-beat bursts with repeated ten-cycle target-W stalls. Four internal owner observers check allocation history, source selection, AWLEN/WLAST and release only on an accepted final beat. Independent data scoreboards verify the outcome. Targets also hold AWREADY low until WVALID, and an explicit assertion checks that reset release leaves all VALID controls known. The common write helper launches AW and W independently; some directed scenario sequences deliberately serialize those events, so this is not exhaustive source-timing/VIP validation.

## Other executed checks

| Check | Result |
|---|---|
| Core default, 40-bit-address/64-bit-data/8-bit-ID, and small-capacity configurations | Clean preprocessing and elaboration; wider/small configurations are compile-only |
| Relocated map, disabled region, independent connection masks, secure filtering | PASS; rejected traffic checked not to leak to real targets |
| Owner-table unit | PASS: allocate, hold, release, simultaneous-control priority, reset and recovery |
| Owner-checker controls | Legal trace PASS; two deliberately invalid traces failed with the expected diagnostics |
| AXI protocol-checker controls | Legal early-W PASS; five violations rejected with expected messages and nonzero exits |
| Native and legacy Mini-SoC struct systems | PASS across all 16 routes in each system: 32 writes, 32 reads, 128 beats per direction across both systems |
| Legacy-ID adapter | PASS: 41 concurrent R/W burst pairs, every source-ID bit and route owner, stalls, SLVERR and reset recovery |
| Core generic synthesis | PASS: slang elaboration, process lowering/optimization, `check -assert`, netlist generation; zero structural problems |
| Legacy-integrated SoC generic synthesis | PASS with zero structural problems; includes the native fabric and all four ID adapters |
| Dependency and provenance audit | PASS: all original 65 hash entries; complete final core/SoC source closure; six-file vendor patch replayed against pinned upstream |
| Audit utility controls | Nine positive/negative controls passed; these are utility checks, not HDL tests |

The seven negative simulation cases are expected failures proving checker activity. They are not accepted DUT failures. Missing tools, missing PASS markers and nonzero ordinary command exits fail the runner and replace a stale success summary with FAIL.

## Clean archive check

A fresh extraction passed all packaged SHA-256 checks, vendor integrity and dependency scanning, then clean compilation of all three core configurations and both SoC tops. The extracted sources matched the successful combined run. `package_validation.json` records these checks. The final ZIP is CRC-checked and its members are verified against `SHA256SUMS`; the accompanying `.zip.sha256` verifies the archive itself.

## Tools and reproduction

Executed on Windows with Python 3.12.14, Icarus/VVP 12.0 devel `s20150603-1539-g2693dd32b`, and Yosys 0.69+158 (`a1a0ad7d4-dirty`) with slang. Tools are external prerequisites and are not bundled.

```text
python scripts/run.py all --direct-backend --tool-dir <Icarus-root> --yosys-dir <OSS-CAD-Suite-root>
python scripts/audit_sources.py --skip-package --original-zip <uploaded-zip> --upstream-dir <pinned-checkout>
```

The Windows Icarus driver pipeline had failed in the earlier environment; separate preprocessing and backend invocation is the documented workaround. Both stages must exit zero and produce a fresh image. On an ordinary working Icarus installation omit `--direct-backend`. Questa's example script has not been executed.

Both synthesis logs retain one constant-shift warning in the vendor thread-priority expression: the thread-zero earlier-thread mask shifts by its width and evaluates to zero as intended. This is an acknowledged warning, not a zero-warning claim. Generic cell statistics are implementation-independent intermediate cells, not mapped gate/LUT area or a frequency result.

## Unverified behavior and integration limits

- No formal proof, UVM coverage closure, exhaustive arbitration/fairness proof, or exhaustive register/parameter matrix.
- No technology mapping, place and route, timing closure, physical area/power, DFT, CDC or complete-SoC reset-domain signoff.
- CPU/DMA/GPU/NPU implementations, DDR controller/PHY, SRAM, APB bridge and accelerator endpoints remain external. The 4x4 struct integration is not a boot-tested reconstruction of the earlier 4x7 SoC.
- Legacy target adapters allow only one read and one write outstanding per endpoint, require unlocked traffic (AxLOCK=0), and do not convert bursts, widths or AXI4 into AXI-Lite/APB. Their ID reconstruction is valid only under the documented compliant-endpoint contract.
- No coherence, AXI5 atomics, global exclusive monitor, 4-KB burst splitting, timeout cancellation or malformed-transaction recovery. Reset discards pending state; it does not roll back accepted target writes.
- Behavioral tests use the 32-bit default data path and 8-bit-ID SoC integration. The standalone 64-bit data configuration is elaboration-only.

This is a tested crossbar IP/integration deliverable, not silicon signoff or AXI certification. See `docs/VERIFICATION_PLAN.md` for the remaining coverage work.
