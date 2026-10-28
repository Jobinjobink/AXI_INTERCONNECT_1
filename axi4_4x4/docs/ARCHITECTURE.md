# Architecture walkthrough

## Four independent destination paths

Each master can reach each enabled target. Arbitration is local to a destination, so M0 to S0, M1 to S1, M2 to S2 and M3 to S3 can all advance concurrently. When masters select the same target they share that target's bandwidth. Read and write resources are separate: delayed B does not inherently stop reads, and stalled R does not inherently stop writes.

```text
                 Read fabric: AR arbitration and R routing
M0 ----\                                                     /---- S0
M1 -----+----- per-master admission / per-target arbitration --+---- S1
M2 -----+----- tagged IDs / ordered response routing ----------+---- S2
M3 ----/                                                     \---- S3
                 Write fabric: AW arbitration, W steering, B routing
```

The SystemVerilog wrapper presents the Mini-SoC ports and configuration. Vendor `axi_crossbar` instantiates separate `axi_crossbar_rd` and `axi_crossbar_wr` engines. Their admission control, arbitration and register slices implement switching. See [VENDOR_PATCHES.md](VENDOR_PATCHES.md) for local corrections to ordering and error completion.

Crossbar does not mean infinite queues or absence of head-of-line blocking. One master's earliest blocked W burst can delay its later writes, and an active ID associated with one target can prevent that ID switching targets. Other independent routes can continue.

## IDs and response selection

Downstream requests carry `{master_index[1:0], original_id[ID_WIDTH-1:0]}`. M0 ID 3 and M1 ID 3 are therefore different downstream streams. Every target must preserve the full widened ID and return it on BID/RID. Discarding the upper two bits breaks routing.

The return path uses those bits to select the requesting master and restores the original ID. A master's single B/R interfaces arbitrate responses from its targets. Different-ID completions may arrive out of order. Read response arbitration releases selection after each accepted beat, allowing legal different-ID interleaving and preventing crossed-target cyclic waits. Selection and payload remain stable while backpressured, and transaction credits retire only on the final accepted beat. Endpoints remain responsible for legal same-ID ordering and response IDs.

## Threads and ordering

`THREADS` bounds active distinct IDs per master per direction. Repeated operations with one ID share a thread but consume separate transaction credits, so four threads do not mean only four transactions. Read and write thread state is independent.

An active ID is pinned to a destination until that stream drains internally. A second request with that ID can use the same destination while credits remain. Switching it to another destination stalls until safe; no cross-target response reorder RAM is required. The patched local error path participates in ordering rather than bypassing mapped threads. Different IDs and different masters can progress independently.

Equal AWID and ARID do not create a fence between writes and reads. If a read depends on a write, wait for B before issuing AR. The fabric cannot guarantee that a concurrent read observes an unfinished write.

## Outstanding capacity and pipeline boundaries

`ACCEPT` limits internal admission credits for each master and direction. `ISSUE` limits internal issue credits toward each target and direction; all masters share that target's limit. `THREADS` additionally limits distinct active IDs. Actual acceptance depends on destination conflicts, channel stalls and endpoint readiness.

These are internal accounting boundaries. A B response or final R beat may release a credit when accepted into an upstream response register, before the external master asserts READY. Such a transaction remains externally outstanding. Forward channel registers similarly separate internal issue from external target address acceptance. Scoreboards must use actual handshakes at one consistent boundary; a naive assertion `external_outstanding <= ACCEPT` can be wrong without register capacity allowances.

Defaults do not promise eight addresses accepted in eight consecutive cycles. Address-control state machines and pipeline stages introduce latency and bubbles. Saturation tests must count credits and distinguish throughput from capacity.

## AW/W independence and ownership

AXI4 has no WID. A master's W bursts follow its AW order, and each target sees W bursts in its arbitrated AW order. The core records the destination and ownership needed to route untagged data. Four instances of the synthesizable `axi_write_owner_table` hold the target owner/valid entries; source route state remains in the write engine. See [OWNER_TABLE.md](OWNER_TABLE.md) for the complete table and transition rules. WDATA cannot identify a target.

WVALID may precede AWVALID. The fabric can backpressure early W until address information establishes routing; the master retains VALID and payload until acceptance. A source must not wait for READY before asserting VALID. Once routing exists, downstream AW and W progress independently. A legal target may wait for WVALID before accepting AW, so tying W progress to AWREADY would create a deadlock.

Write bursts cannot interleave even when IDs differ. Do not insert ad hoc AW queues inside the routing hierarchy: master W order and target W ownership must remain coordinated. Endpoint faults such as missing WLAST, wrong RID/BID or changing a stalled payload have no automatic cancellation/recovery path.

## Burst contract and errors

The interconnect transports legal FIXED, INCR and WRAP metadata. Targets interpret addresses, byte lanes and strobes. Narrow/unaligned transfers require both legal AXI geometry and supporting endpoints. No byte-lane realignment or width conversion occurs.

Sources must satisfy burst length, SIZE, WRAP geometry, LAST and the 4 KB rule. Illegal 4 KB crossings are protocol violations, not requests for automatic splitting or DECERR repair. Decode selects a target from the first address. Aligned regions are at least 4 KB, so a legal burst stays in one mapped region.

Unmapped addresses, disabled connections and prohibited nonsecure accesses select local DECERR. A rejected write must still supply its full legal W burst; one B follows completion. Error reads return the requested number of beats. Mapped target errors pass back unchanged. The validation report identifies the cases actually exercised, including local error behavior.

## Arbitration, reset and implementation

Round robin handles contention. QOS passes as metadata and does not affect priority. Fairness assumes eventual endpoint progress; indefinite target backpressure precludes a bounded latency guarantee.

The top inverts `aresetn` into the core's synchronous high reset. Hold reset across clock edges and release it synchronously. Reset the entire connected transaction domain together. Pending state is discarded; writes already accepted by real targets are not rolled back. Reset does not generate cancellation responses.

Four independently routed writes and four independently routed reads can each transfer a beat per participating target per cycle under suitable steady-state readiness. Measured transaction latency, area and clock frequency depend on the configuration and implementation flow. Simulation alone establishes no physical timing claim.
