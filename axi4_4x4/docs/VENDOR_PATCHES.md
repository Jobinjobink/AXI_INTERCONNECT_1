# Local vendor corrections

Baseline: `alexforencich/verilog-axi`, commit `516bd5dadc3365b7f9e225d2af8fe0b8d804fe53` (MIT). All original copyright/license headers remain. `vendor_fixes.patch` records the exact local changes. `VENDOR_MANIFEST.json` records packaged file hashes.

## Decode-error ID ordering and credits

The baseline address decoder bypasses normal thread admission for an unmapped, disconnected or nonsecure-to-secure request. Its local error completion still reaches the completion interface. This can let a DECERR response overtake an earlier same-ID mapped transaction, and can decrement accounting for a request that was never counted.

`axi_crossbar_addr.v` now tracks decode error as a virtual destination bit per thread. Both successful and error requests allocate normal admission credits; an active ID can move between a mapped target and the error sink only after its older transactions drain. Error completions return the credit normally. Different IDs retain independent routing.

## Decode-error write response dependency

The baseline write error responder creates B from the address error command before the associated W burst necessarily finishes. `axi_crossbar_wr.v` now stores a pending error ID and asserts error BVALID only after the discarded WLAST handshake. The error WC (write-routing) command and RC (response) command are admitted atomically while both the W owner and error response slot are free. This prevents a second error W burst draining while an earlier B is blocked, and prevents its final W beat being lost before its response command is captured.

## Write-data ownership

Source WREADY is explicitly qualified by the source write-route-valid flag. A destination that is ready for this source cannot consume early W data before the source-side AW route command has been installed.

## Regression coverage

The self-checking testbench exercises mapped-to-error and error-to-mapped same-ID ordering for reads/writes, delayed error W data, multiple errors under blocked BREADY, and WVALID before AWVALID. Passive checkers reject B before the matching AW and complete W burst. See the executed results in `reports/VALIDATION.md`; the patch is not a formal proof or an assertion about all upstream configurations.
## Read interleaving and progress

`axi_crossbar_rd.v` qualifies the selected RVALID with the destination master tag, rather than exposing the target's raw RVALID to every master retaining a grant. This prevents a slave's interleaved beat from being consumed by the wrong master. The ready route uses the ID from the same internal register boundary as the data.

The return arbiter releases its grant on every accepted R beat. It still holds selection under backpressure. Holding a grant through RLAST could create a cyclic wait when two targets emit interleaved beats for opposite masters. Per-beat arbitration permits forward progress, while completion credits are still returned only for accepted RLAST beats. The testbench includes a two-target crossed interleaving scenario and counts interleaved ID switches.

## Explicit write-owner table

The target-side `w_select_reg` / `w_select_valid_reg` storage in `axi_crossbar_wr.v` is factored into four instances of the project module `rtl/axi_write_owner_table.sv`. This keeps the Mini-SoC's named owner-table structure while using the existing crossbar arbitration. Allocation occurs from the AW grant, without waiting for AWREADY; release occurs on the internal accepted WLAST. The source destination/drop state, grant-new tracking, and target next-state dependency remain in the write engine. All source lists include this additional project dependency. The owner table is not an eight-entry transaction FIFO: B routing and outstanding accounting remain in the tagged-ID and thread/count structures.

## Buffered write-response routing

The B response selector now reads the source-master tag from `int_m_axi_bid`, the same register boundary as `int_m_axi_bvalid` and response payload. Previously it read the external target BID, which can change after the response enters an input register. This was invisible with the default bypass B slice but misrouted responses with a simple/skid slice. A reproduction with a simple B slice and legal idle-BID clearing failed with `Unexpected B master=0 ID=1`; the same regression passed after the repair. The original failure log is retained in `reports/audit_evidence/b_slice_before_fix.log` and is deliberately a failure example, not a final validation result.

## Register-type parameter forwarding

`axi_crossbar.v` now passes `M_AW_REG_TYPE`, `M_W_REG_TYPE`, `M_B_REG_TYPE`, `M_AR_REG_TYPE` and `M_R_REG_TYPE` to its read/write engines. They were declared at the parent but ignored. The parent and engine defaults agree (AW=1, W=2, B=0, AR=1, R=0), so the default pipeline is unchanged. Regression variants exercise B input types 1 and 2; this is not exhaustive verification of every register-type combination.

## Reproducing vendor changes

`VENDOR_MANIFEST.json` records exact packaged hashes and pinned upstream hashes, the six changed vendor files, and the custom owner-table dependency. `vendor_fixes.patch` is regenerated from the pinned upstream to the final vendor source as LF-normalized text. Run `python scripts/audit_sources.py --upstream-dir <pinned-upstream-checkout>` to verify upstream hashes and replay every hunk without fuzzy matching. The script also checks all listed source paths and conservative module closure; compilation/elaboration remains the authoritative HDL dependency check.

## Reset release with READY held low

All ten simple/skid channel combinational next-state blocks in `axi_register_rd.v` and `axi_register_wr.v` now reference `rst` and force their next-valid bits to zero while reset is active. With READY and the other initialized inputs remaining unchanged, an event-driven simulator could otherwise leave an `always @*` block unevaluated until the first post-reset clock, which copied unknown next-state valid bits. Referencing reset guarantees recomputation on reset transitions. Registered outputs still reset synchronously; normal next-state equations and data-path behavior are unchanged. The strengthened target model can wait for WVALID before asserting AWREADY, exposing the formerly hidden initialization case. The pre-fix trace in `reports/audit_evidence/reset_before_fix.log` is historical failure evidence, not a final regression result.
