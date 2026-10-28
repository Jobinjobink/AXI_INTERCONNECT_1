# Verification plan and UVM handoff

## Evidence versus planned work

The supplied self-checking SystemVerilog regression tests this wrapper, pinned dependency and local patches. Its result establishes only executed cases. `reports/VALIDATION.md` is the source of actual commands and results. This document is an extension plan, not a coverage-closure claim.

Build scoreboards from external handshakes. Upstream AW creates a descriptor containing master, ID, address, length, size, burst and attributes. W bursts associate with AW descriptors in master order; there is no WID. AR creates a read descriptor keyed by master and ID. Completion is accepted B or final accepted R. Compare independent expectations with slave traffic and memory bytes, rather than derive expected behavior from internal ownership state.

## Directed matrix

| Area | Stimulus | Required evidence |
|---|---|---|
| All routes | Every master reads/writes every target | All 16 routes in both directions |
| Parallelism | Four masters use four different slaves | Sampled four accepted W beats and four accepted R beats in a cycle |
| Independence | Block one target/channel while other routes run | Unrelated completion; stalled payload stable |
| Contention | All masters repeatedly select one target | Round-robin service; no lost/duplicated request |
| Outstanding reads | Several ARs precede final R completions | More than one active read with matching IDs/data |
| Outstanding writes | Several AW/W bursts precede B | More than one write awaiting B; correct W ownership |
| Owner table | Four 64-beat writers contend with W stalls | Real owner entry remains stable until accepted internal WLAST; readback matches |
| Buffered B routing | B register types 0/1/2; idle external BID is zeroed | Buffered ID, payload and VALID route to the same master |
| ID collisions | Four masters use identical original IDs | Distinct widened IDs and correct return routing |
| Same-ID same target | Repeated queued ID | Ordered responses |
| Same-ID new target | Delay old target and offer new destination | Destination reassignment waits safely |
| Different IDs | Different targets respond in reverse latency order | Legal out-of-order completion |
| Early W | WVALID before AWVALID, held under stalls | Eventual completion without lost beats |
| AW/W independence | Target model enables `WAIT_AW_FOR_W=1` | Main regression completes with AWREADY withheld until WVALID |
| Capacity | Suppress completions and fill threads/credits | Correct backpressure and recovery |
| Errors | Decode, connectivity, security, target errors | Correct ID, response, beat count and isolation |
| Reset | Reset at address/data/response phases | State clears and fresh traffic succeeds |

Exercise all 24 one-to-one master/target permutations. Measure concurrency from sampled VALID && READY, not overlapping VALID pulses or four sequential task completions. Read arbitration between targets releases its grant on each accepted beat. Check legal different-ID interleaving, stable selection under backpressure and transaction-credit retirement only on accepted RLAST.

## Burst and data matrix

Cover FIXED lengths 1/16, INCR 1/2/16/256 and WRAP 2/4/8/16. Use WRAP starts inside the window, legal unaligned FIXED/INCR starts, supported narrow sizes, relevant lanes, sparse strobes and zero strobes. Check written and untouched bytes with an independent expected memory.

Place legal bursts at the end of a 4 KB page and at every region boundary. An access ending exactly at a boundary can be legal; one extending into the next page is not. Negative assertion tests must demonstrate detection of illegal crossings, WRAP geometry, reserved BURST, invalid SIZE and LAST errors without implying the DUT repairs malformed traffic.

For DECERR, provide the complete W burst and require exactly one B after it; check all R beats through LAST. Include long error reads, response backpressure and delayed data on rejected writes. Missing WLAST or incorrect response ID is an endpoint fault; recovery is not promised.

## Ordering corners

Mix mapped and unmapped operations using the same ID, both mapped-first and error-first. Delay mapped responses while local errors are ready. Repeat with disabled connections and secure filtering. Verify per-ID B and R ordering. These tests directly exercise the local vendor corrections and should remain permanent regression cases.

Run equal IDs in simultaneous read/write traffic without inventing cross-direction ordering. For dependent read-after-write tests, wait for B before AR. Let different targets complete different-ID reads in reverse order and check routing. Add target-generated legal different-ID response interleaving, including crossed-target traffic to opposite masters. Check that the returned master tag qualifies RVALID and that per-beat arbitration permits progress without misrouting; preserve ordering within each ID.

## Assertions and accounting

The shipped passive checker monitors VALID/payload stability during stalls, address/burst geometry including the 4 KB rule, AW/W beat association and LAST, and accepted request/response ID accounting. WSTRB is part of the checked stable W payload. Functional write/readback comparisons exercise masks and untouched bytes; the checker does not establish every WSTRB lane-legality rule for every size and alignment. Add complete legal-lane checks as further verification. Internal invariants such as one-hot ownership can supplement, but cannot replace, independent functional checking.

Count acceptance and completion at the same boundary. Internal credits can retire into response registers before external READY; external outstanding assertions must account for those registers. Add watchdogs with explicit endpoint-progress assumptions. Coordinated reset abandons scoreboard transactions and does not roll back writes already accepted by real memory.

## UVM organization and closure

Use four active master agents and four active slave responder agents, each with a monitor. Generate AW and W from independently timed processes. Keep response backpressure independent from request generation. A virtual sequencer coordinates contention, saturation, ordering and reset scenarios.

Separate protocol checks from functional memory/ordering scoreboards. Derive expected address map, connectivity and security from independent environment configuration. Cover master x target x direction; burst x length x size; outstanding depth x active IDs; contention x grant; stall length per channel; early W; AW waiting for W; same-ID destination changes; different-ID out-of-order completion; four-way accepted data concurrency; errors; and reset phase.

Extend to reproducible randomized seeds and several width/ID/credit configurations. Add formal ownership/accounting safety properties, lint, target synthesis/timing, reset/CDC checks in the SoC and protocol VIP if available. Preserve seeds, waveforms, tool versions and parameter overrides. Passing simulations are evidence for tested behavior, not a substitute for measured coverage or physical signoff.


## Explicit owner-table verification

The synthesizable `axi_write_owner_table` is connected in the actual write
fabric with one entry per target. `tb_owner_table` checks its transition
contract. The main regression instantiates four `axi4_owner_checker`
observers at the pre-output-register W mux boundary. They check the owner
against allocation history, AWLEN against accepted W beats, and release
against accepted WLAST. See `OWNER_TABLE.md` for the state map and why this
boundary differs from external target handshakes.

`tb_owner_checker_negative` CASE 0 is a legal stalled two-beat burst; CASE 1
changes the live owner; CASE 2 releases without an accepted final beat. The
runner must require both a nonzero status and the expected failure reason
for the deliberate violations. Counted stalls in the contention test prevent
a nominal stall scenario from silently passing without actually exercising
the owner hold condition.

Internal observations supplement the external protocol and functional
scoreboards. They do not replace independent data/address/ID comparisons or
establish fairness under indefinite backpressure. Current execution status
belongs in the validation report; formal ownership proof and complete
parameter/configuration coverage remain further work.

## Directed stimulus limitations

Some convenience tasks in `tb_axi4_interconnect.sv` send AW to completion and
then call the W sender. They are bounded directed-test scheduling helpers,
not a reusable AXI manager implementation or protocol VIP. In this tested
configuration the target AW register can accept the address independently;
the target's later wait for WVALID therefore does not imply that every
source-channel timing combination has been covered. Dedicated early-W and
opposite-destination tests launch address and data from separate processes.

Production managers and general-purpose BFMs must not make AWVALID or WVALID
depend on AWREADY or WREADY. See the write-transaction dependency rules in
[Arm IHI 0022H](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf).
Future closure should use fully independent AW/W generators across every
register-slice configuration, include long address stalls and independently
varying data availability, and cover all supported parameter combinations.
The current passes do not certify the test driver as an AXI-compliant master.
