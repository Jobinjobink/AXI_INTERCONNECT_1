# Write owner table

## Real RTL, one entry for each target

`rtl/axi_write_owner_table.sv` is synthesizable and is part of `filelist.f`.
It preserves the older Mini-SoC module's `MW`, `clk`, `rst_n`, `allocate`,
`release_owner`, `master`, `valid`, and `owner` interface. The crossbar uses
four instances; these replace the original vendor owner/valid registers.
They are the state that actually selects write data, not an unused example
or a second set of routing registers.

| Table row | Default target | Valid and owner register location | Owner codes |
|---|---|---|---|
| 0 | DDR controller AXI port | `crossbar.axi_crossbar_wr_inst.m_ifaces[0].owner_table_inst` | 0 CPU, 1 DMA, 2 GPU, 3 NPU |
| 1 | SRAM AXI port | `crossbar.axi_crossbar_wr_inst.m_ifaces[1].owner_table_inst` | 0 CPU, 1 DMA, 2 GPU, 3 NPU |
| 2 | AXI-to-APB bridge AXI port | `crossbar.axi_crossbar_wr_inst.m_ifaces[2].owner_table_inst` | 0 CPU, 1 DMA, 2 GPU, 3 NPU |
| 3 | Accelerator AXI port | `crossbar.axi_crossbar_wr_inst.m_ifaces[3].owner_table_inst` | 0 CPU, 1 DMA, 2 GPU, 3 NPU |

Paths above start at an `axi4_interconnect_4x4` instance. Add the instance
prefix when viewing a waveform. In the supplied main testbench the prefix
is `tb_axi4_interconnect.dut`. `owner_valid[3:0]` and
`owner_master[3:0][1:0]` in that testbench provide a compact table view.
Invalid rows retain an old owner value; ignore the owner field unless valid
is one. Reset clears both valid and owner synchronously.

Four valid rows can name four different masters at the same time. This is
what permits four independent write paths. When masters contend for one
target, that target's row belongs to only one master until the burst's final
accepted data beat. The read fabric is separate and is not locked by this
write table.

## Entry interface and transitions

| Signal | Meaning |
|---|---|
| `master[MW-1:0]` | Master index to latch on allocation; `MW=2` for four masters |
| `allocate` | Capture a newly selected AW arbitration grant |
| `release_owner` | The selected W path accepts its final beat: WVALID and WREADY and WLAST |
| `valid` | The entry owns a write-data burst |
| `owner[MW-1:0]` | The master whose WDATA/WSTRB/WLAST the target uses |
| `rst_n` | Synchronous active-low reset; reset has priority over both controls |

| Current state | Event | Next state |
|---|---|---|
| Invalid | Allocate master M | Valid, owner M |
| Valid | No accepted WLAST | Hold valid and owner, including all stalls |
| Valid | Accepted WLAST | Invalid |
| Either | Reset | Invalid, owner zero |
| Either | Allocate and release together | Allocation wins in the primitive |

The primitive deliberately contains no arbiter or FIFO. Its caller must not
assert allocate over a live burst. The crossbar enforces that restriction and
uses the existing `w_select_new_reg` flag to prevent allocating the same AW
grant twice. It keeps the existing combinational `w_select_valid_next`
admission gating. The standalone unit test checks the primitive's defined
simultaneous allocate/release priority; the integrated checker rejects live
burst overwrite by the crossbar caller.

Allocation is based on the AW grant, **not downstream AWREADY**. AXI permits
a target to wait for WVALID before it accepts AW. A fabric that waits for
AWREADY before permitting WVALID can deadlock. AW register storage and the
arbiter retain the address while W progresses. The same grant cannot be
reused after an early completed W burst while its AW remains pending.

## Three different kinds of ownership

The design does not use one global table for every purpose:

1. **Per-target W owner entries** select a source for untagged write data.
   They release at accepted internal WLAST. This is the new explicit
   `axi_write_owner_table` module described above.
2. **Per-master W destination state** in the vendor `s_ifaces` remembers
   where that master's next burst goes. Its `w_select_reg`,
   `w_select_valid_reg`, and `w_drop_reg` preserve master AW/W order and
   consume rejected write bursts locally.
3. **Per-ID transaction/thread state** in `axi_crossbar_addr` tracks active
   IDs, their destination, and outstanding counts. It prevents a same-ID
   stream from changing targets until safe. B returns and final R returns
   retire transaction credits; WLAST alone does not retire a write response.

BID/RID include the source master tag, so responses can route after the W
owner entry is free. Holding a W owner until B would unnecessarily serialize
the target. Conversely, freeing a transaction credit at WLAST would be too
early because the B response is still outstanding.

## Boundary and pipeline details

The table observes the vendor's W mux **before the target output register**.
An accepted internal final beat may be buffered and not yet accepted at the
external slave port. The output register preserves that beat and its order
while the table is released. Therefore external `s_wlast` alone is not the
release signal, and table occupancy is not an external outstanding counter.
The same distinction applies to address and response register slices.

Reset discards in-flight owner and transaction state. Reset the whole AXI
domain together; it is not a transaction-cancellation mechanism and does not
roll back writes already accepted by memory.

## Verification and limits

`tb_owner_table.sv` tests allocation, hold while requests change, release,
simultaneous controls, reset priority, and recovery. The main regression's
four `axi4_owner_checker` instances independently remember allocation history,
require the owner to stay unchanged, count accepted W beats against the
allocated AWLEN, check WLAST, and require release only on accepted WLAST.
A long-burst contention phase exercises all four masters sharing one target.

The target model's `WAIT_AW_FOR_W` option holds AWREADY until WVALID, testing
that ownership allocation does not create an AW/W dependency deadlock. The
main regression enables this option. External protocol monitors and the
memory/ID scoreboard remain the independent checks of complete traffic;
internal owner assertions alone cannot prove correct address decode or data
routing.

`tb_owner_checker_negative.sv` includes a legal stalled burst and deliberate
owner changes and premature release. Expected failure messages and nonzero
simulation exits are checked by the runner. Refer to `reports/VALIDATION.md`
and the current JSON summaries for which runs actually passed; source code
or a listed test case by itself is not execution evidence.

The observer is simulation-only and uses internal hierarchy. It is not
synthesizable debug hardware, an AXI certification suite, a formal proof,
a programmable owner table, or a CSR interface. Exporting debug state into a
real SoC requires a deliberate interface and timing review. Fairness requires
endpoint progress; a target stalled forever retains its current burst.

Some regression helper tasks serialize upstream AW and W, while the dedicated
early-data and overlap cases use separate processes. Consequently, enabling
`WAIT_AW_FOR_W` demonstrates progress for the exercised buffered configuration;
it does not establish all source timing combinations or every register-slice
configuration. See `VERIFICATION_PLAN.md` for the directed-driver limitation.
