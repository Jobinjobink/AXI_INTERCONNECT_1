# Example only: replace periods and I/O budgets with your SoC constraints.
create_clock -name aclk -period 10.000 [get_ports aclk]
# All connected AXI endpoints must share this clock and synchronous reset.
# No false paths are added automatically. Apply target-specific I/O delays,
# reset constraints, clock uncertainty and load/drive models at integration.