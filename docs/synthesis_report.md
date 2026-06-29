# Synthesis & Implementation Report

Generated with a non-project Vivado batch flow (`synth_design` -> `opt_design`
-> `place_design` -> `route_design`) run directly against the current
`src/*.v` and `constraints/Nexys-A7-100T-Master.xdc`, targeting the Nexys
A7-100T's `xc7a100tcsg324-1` part in Vivado 2021.2. Top module: `pong_ball`.

*(This supersedes the reports under the local `pong_paddles.xpr` Vivado
project, which still target the old paddles-only `pong_paddles` top module
from before ball physics and `new_game` were added.)*

## Resource Utilization (post-route)

| Resource         | Used | Available | Utilization |
|------------------|-----:|----------:|-------------:|
| Slice LUTs       |  340 |    63,400 |        0.54% |
| Slice Registers  |  178 |   126,800 |        0.14% |
| Block RAM tiles  |    0 |       135 |        0.00% |
| DSP48 slices     |    0 |       240 |        0.00% |
| Bonded IOB       |   21 |       210 |       10.00% |

No BRAM or DSP is used — the whole design (clock divider, four debouncer
FSMs, VGA timing, paddle/ball rendering) is plain combinational/register
logic. Routing closed cleanly: 542/542 routable nets fully routed, 0 routing
errors (`pong_ball_route_status.rpt`).

## Timing Closure

| Metric        |    Value | Endpoints failing |
|---------------|---------:|-------------------:|
| Clock         | `sys_clk_pin`, 100 MHz (10.000 ns) | |
| WNS (setup)   | +8.341 ns |  0 / 2  |
| TNS (setup)   |  0.000 ns |  0 / 2  |
| WHS (hold)    | +0.290 ns |  0 / 2  |
| THS (hold)    |  0.000 ns |  0 / 2  |

**Caveat: this number does not cover most of the design.** `check_timing`
reports 482 unconstrained internal endpoints and 176 register pins with no
declared clock. The XDC only has a `create_clock` on the 100 MHz board
oscillator — it never declares the 25 MHz `pixel_clk` produced by
`clk_gen_25MHz`'s divide-by-4 counter as a generated clock. So the "2
endpoints" timed above are just the divider's own counter register; every
flip-flop in `sync_debouncer` (x4) and `vga_sync` — effectively the entire
design — runs on `pixel_clk` and currently gets **zero** static timing
analysis coverage. The behavioral simulations elsewhere in this repo confirm
functional correctness, but they don't substitute for STA against real
silicon delays.

This is fixable with one constraint:
```
create_generated_clock -name pixel_clk -source [get_pins pixel_clock/clk_100MHz] \
    -divide_by 4 [get_pins pixel_clock/counter_reg[1]/Q]
```
Worth adding before relying on a future "timing met" result for this design.

## Power (post-route, vectorless estimate)

| | |
|---|---:|
| Total on-chip power | 0.102 W |
| Dynamic              | 0.005 W |
| Device static        | 0.097 W |

Vectorless estimate ("Low" confidence — no switching activity file was
supplied); useful as a rough sanity check, not a signoff number.

## Raw reports

Full Vivado output for each command is under [`reports/`](reports/):
`pong_ball_utilization_synth.rpt`, `pong_ball_utilization_routed.rpt`,
`pong_ball_timing_summary_routed.rpt`, `pong_ball_power_routed.rpt`,
`pong_ball_route_status.rpt`.
