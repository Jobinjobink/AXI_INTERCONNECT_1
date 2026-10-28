# Mini-SoC common types

Compile rtl/axi_pkg.sv before the fabric adapter. The original eight-bit-ID
master structs and helper functions are preserved. Ten-bit target types are
separate, so route bits cannot be silently lost through source-type reuse.
Compile the one package listed in the root-relative integration filelist.
