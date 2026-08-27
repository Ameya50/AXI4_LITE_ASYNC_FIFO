# AXI4-Lite Bidirectional Async-FIFO Bridge — RTL to Signoff

![Process](https://img.shields.io/badge/Process-gpdk045%2045nm-blue) ![Timing](https://img.shields.io/badge/Timing-Setup%20%2B2.633ns%20%2F%20Hold%20%2B0.049ns-brightgreen) ![DRC](https://img.shields.io/badge/DRC%2FConnectivity-0%20Violations-brightgreen) ![Coverage](https://img.shields.io/badge/Functional%20Coverage-93.82%25-yellow)

A bidirectional AXI4-Lite ↔ dual-clock FIFO bridge driving a peripheral, carried through **RTL → Genus synthesis (3 strategies) → Innovus place-and-route → Tempus STA signoff → Voltus power signoff**, with every raw report and screenshot checked into this repository rather than just summarized.

- **Design:** `axi4_lite_bidir_system_top` — asynchronous AXI4-Lite bridge (Gray-code dual-clock FIFOs) + peripheral
- **Process:** gpdk045 / gsclib045, 45 nm CMOS, VDD 1.08 V
- **Clocks:** `s_axi_aclk` @ 125 MHz, `p_clk` @ 100 MHz — fully asynchronous, CDC-bridged
- **Result:** clean timing (Setup WNS +2.633 ns, Hold WNS +0.049 ns), zero DRC/connectivity/antenna violations, independently cross-checked in Tempus (6 ps setup divergence) and Voltus (activity-based power signoff)

Full parameter list (area, timing, power, VDD, parasitics — everything, in one place): **[SPECIFICATIONS.md](SPECIFICATIONS.md)**

## Repository Layout

Each stage of the flow lives in its own tree — nothing is mixed together:

```
rtl/                    5 Verilog source + testbench files
synthesis/              Genus — 3 independent strategies, each with its own area/power/timing reports
  gate_level_views/     generic -> tech-mapped -> optimized gate count screenshots
  normal/               default synthesis (the netlist actually taken to P&R — see Finding below)
  area_optimized/       area-effort synthesis experiment
  power_optimized/      power-effort synthesis experiment (clock-gated)
physical_design/        Innovus place-and-route
  layout_views/         floorplan -> pins -> PDN -> placement -> CTS -> routing -> final, in flow order
  verification/         verify_drc / verify_connectivity / verify_antenna screenshots (all clean)
  reports/              setup/hold timing, power, floorplan area, die/core box
signoff/
  tempus/                independent STA re-verification of the post-route netlist
  voltus/                independent power signoff using real simulated switching activity
simulation/
  schematics/            Verdi schematic traces (top level down to async_fifo internals)
  waveforms/             full-run and zoomed-in AXI transaction waveforms
  coverage/              URG dashboard + Verdi hierarchical coverage
```

## 1. Design Overview

`axi4_lite_bidir_system_top` wires two blocks together:

1. **`axi4_lite_bidir_fifo_bridge`** — implements the AXI4-Lite write and read FSMs, latches whichever of AW/W arrives first (or both together), and pushes/pops two independent Gray-code-pointer async FIFOs (`async_fifo.v`) to cross between `s_axi_aclk` and `p_clk`.
2. **`peripheral`** (`dsp_coprocessor_peripheral.v`) — a simple ready/valid consumer+producer standing in for a real DSP block: it pops a word, applies a trivial transform (`(sample << 1) + const`), and pushes the result back through the second FIFO.

See [`simulation/schematics/`](simulation/schematics) for the traced Verdi schematics of every level of this hierarchy, and [`simulation/waveforms/`](simulation/waveforms) for a full simulation run plus a zoomed-in single-transaction view.

Verification is a coverage-driven testbench (`tb_axi4_lite_coverage_verilog.v`) exercising address-decode DECERR paths, empty-read SLVERR, write-FSM skew orderings, FIFO full/empty boundaries, an async-reset-mid-FSM corner case, and a pointer-wraparound sweep. Final scores: **93.82% overall**, 100% FSM, 99.53% toggle — see [`simulation/coverage/`](simulation/coverage) and [§7 of SPECIFICATIONS.md](SPECIFICATIONS.md#7-functional-verification-simulation).

## 2. Comparison 1 — Synthesis Strategies vs. Post-Route (Innovus) Reality

Three independent Genus synthesis runs were generated ([`synthesis/`](synthesis)):

| Metric | Normal | Area-optimized | Power-optimized | Post-Route (Innovus) |
|---|---:|---:|---:|---:|
| Cell count | 2,240 | 2,281 | 2,241 | 3,085 (incl. CTS/hold-fix cells) |
| Total area (µm²) | 15,164.5 | 15,368.3 (**+1.3%**) | **12,237.4 (−19.3%)** | 17,406.8 (core, includes routing margin) |
| Total power (mW) | 1.800 | 1.889 (**+4.9%**) | **0.370 (−79.5%)** | 1.871 (vectorless) |
| Setup slack (best group shown) | +2.418 ns | +2.513 ns | +3.283 ns | **+2.633 ns** |

**Reading this table:**
- The **power-optimized** run is dramatically cheaper on both area (−19.3%) and power (−79.5%) than the normal run. Its timing report shows `cg_enable_group_*` path groups, confirming Genus inserted **clock gating** — that single structural change accounts for most of the power win (clock-network + sequential switching power collapses when idle registers aren't toggling their clock pin every cycle).
- The **area-optimized** run is, counterintuitively, *larger and higher-power* than the plain "normal" run (+1.3% area, +4.9% power). Area-effort in Genus optimizes cell/net area under the existing timing constraint — it does not automatically reduce power, and here it selected slightly different (larger-drive) cells to hit timing margin, which cost both area and power.
- **Setup slack looks like it improves through the list (2.42 → 2.51 → 3.28 ns)** — but these numbers are **not from the same path group** (`in2reg` vs `s_axi_aclk` view) and use Genus's pre-route wireload-based timing model, not real extracted parasitics. They are directional synthesis-stage estimates, not signoff numbers.

### Finding: which synthesis run was actually taken to P&R?

The area/power numbers make this identifiable without needing a build log. Post-route Innovus power (**1.871 mW**) sits close to the **normal** run's synthesis-stage power (1.800 mW) — a plausible ~4% increase from real parasitics and clock-tree buffering. It is nowhere near the power-optimized run's 0.370 mW (which would imply a >5× jump from clock-gating being physically undone, which didn't happen — the post-route netlist shows no `cg_enable` structures). **The "normal" Genus netlist is the one that was carried into `physical_design/`**; area-optimized and power-optimized are exploratory synthesis experiments captured here for comparison, not alternate P&R flows.

## 3. Comparison 2 — Tempus Signoff Timing vs. Innovus Implementation Timing

Both engines analyze the **same post-route netlist and the same extracted SPEF** — Tempus is a true independent cross-check, not a re-run with different inputs.

| Metric | Innovus (`timeDesign -postRoute`) | Tempus (signoff STA) | Divergence |
|---|---:|---:|---:|
| Setup WNS | +2.633 ns | +2.627 ns | **6 ps** |
| Setup TNS | 0.000 ns | 0.000 ns | — |
| Setup violating endpoints | 0 / 3,639 | 0 / 3,639 | — |
| Hold WNS | +0.049 ns | 0.000 ns | **49 ps** |
| Hold TNS | 0.000 ns | 0.000 ns | — |
| Hold violating endpoints | 0 / 3,639 | 0 / 3,639 | — |
| Critical path | I/O (`in2reg`) | I/O (`in2reg`) | agrees |
| `min_pulse_width` margin | not checked by `timeDesign` | +3.243 ns, 0 fails | Tempus-only check |

**Reading this:** a 6 ps setup / 49 ps hold divergence between two independent STA engines reading identical parasitics is a tight correlation — well within normal engine-to-engine numerical noise (rounding, corner interpolation, CPPR handling). Both agree on zero violations and on the critical path's identity and category. Tempus additionally ran the `min_pulse_width` clock-tree check that Innovus's `timeDesign` summary doesn't surface by default, and it passed with +3.243 ns of margin. Raw reports: [`physical_design/reports/setup_timing.rpt`](physical_design/reports/setup_timing.rpt), [`hold_timing.rpt`](physical_design/reports/hold_timing.rpt), [`signoff/tempus/timing_summary.rpt`](signoff/tempus/timing_summary.rpt).

## 4. Comparison 3 — Voltus Signoff Power vs. Innovus Implementation Power

*(Voltus is a power/rail-analysis tool, not a timing engine — the comparable signoff metric between it and Innovus is power, so that is what's compared here; both used the identical post-route netlist, SPEF, and 1.08 V rail.)*

| Metric | Innovus (vectorless / default activity) | Voltus (real SAIF activity from testbench) | Delta |
|---|---:|---:|---:|
| Total Power | 1.871 mW | **1.402 mW** | **−25.1%** |
| Internal Power | 1.517 mW | 1.163 mW | −23.3% |
| Switching Power | 0.353 mW | 0.238 mW | −32.6% |
| Leakage Power | 0.505 µW | 0.505 µW | **0% (identical)** |
| Clock network power | 0.2656 mW | 0.2656 mW | **0% (identical)** |
| Sequential logic power | 1.457 mW | 1.104 mW | −24.2% |
| Combinational logic power | 0.1484 mW | 0.0317 mW | **−78.6%** |

**Reading this — why the numbers differ, and why some are exactly identical:**
- **Leakage and clock-network power are identical to 4+ significant figures** between the two tools. Neither depends on data-switching activity — leakage is a function of the library's characterized device data and VDD alone, and the clock tree toggles deterministically every cycle regardless of what data is flowing — so two independent power engines reading the same SPEF necessarily agree on both, which is a useful sanity check that both runs are reading the same parasitics correctly.
- **Combinational logic power differs by −78.6%** — this is the headline finding. Innovus's inline power estimate during implementation is **vectorless** (a default/statistical toggle-rate assumption applied uniformly to all combinational nets). Voltus's estimate is driven by **`../sim/activity.saif`**, real switching activity captured from the coverage testbench. The vectorless assumption significantly overstates how often combinational logic actually toggles in this design (much of it sits idle between AXI transactions), so the real-activity number is the more trustworthy one for a true power budget.
- **Sequential and total power drop by ~24–25%** for the same underlying reason, just diluted by the fact that flip-flops still toggle their clock pin every cycle even when their data doesn't change.

**Net conclusion:** report the **Voltus, activity-based 1.402 mW** as the power signoff number, not the Innovus vectorless 1.871 mW — it's derived from real functional-coverage stimulus rather than a default toggle-rate assumption. Raw reports: [`physical_design/reports/power.rpt`](physical_design/reports/power.rpt), [`signoff/voltus/power.rpt`](signoff/voltus/power.rpt).

## 5. Full Specification Tree

Every parameter referenced above — plus VDD, parasitics, cell counts, die/core geometry, and physical-verification results — is consolidated in one place: **[SPECIFICATIONS.md](SPECIFICATIONS.md)**.

## Author

Ameya S Moghe — M.Tech VLSI and Nanoelectronics, IIT Guwahati
