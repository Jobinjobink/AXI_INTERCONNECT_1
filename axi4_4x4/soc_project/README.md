# Mini-SoC integration

This directory preserves the earlier Mini-SoC's common/rtl, axi/rtl,
soc_top/rtl, tb, and scripts organization. It contains an executable
integration of the 4x4 fabric into the existing request/response struct style.

- soc_axi4_subsystem has named CPU, NPU, GPU, DMA master ports and native
  ten-bit-ID DDR, SRAM, APB-bridge and accelerator target ports.
- soc_axi4_legacy_subsystem adds four tested ID preservation adapters for
  existing eight-bit-ID targets, with one outstanding transaction per direction
  at each legacy target.
- common/rtl/axi_pkg.sv preserves the previous eight-bit-ID master structs and
  helper functions, and adds separate widened target types.
- axi/rtl/axi4_struct_crossbar.sv explicitly maps every channel and field.

Run from the archive root:

    python soc_project/scripts/run.py
    python soc_project/scripts/run.py --direct-backend --tool-dir <Icarus-root> --yosys-dir <OSS-CAD-Suite-root>

The supplied filelist.f is also resolved from the archive root. With
--yosys-dir, the runner performs generic synthesis and structural checks.
Without it, synthesis is explicitly marked not run in the summary. The
--compile-only option does not claim behavioral validation.

Read [the integration guide](../docs/SOC_INTEGRATION.md) before connecting
existing endpoints. This is the complete fabric integration boundary, not a
replacement bootable CPU, DDR PHY, SRAM implementation, peripheral subsystem
or accelerator. The previous seven-target address map requires remapping.
