# Specifications

Every parameter below is pulled directly from the raw tool reports in this repository (not re-typed from memory). Where a source file disagreed with another, both values are shown rather than silently picking one — see the footnotes.

## 1. Design Identity

| Parameter | Value | Source |
|---|---|---|
| Design (top) | `axi4_lite_bidir_system_top` | all reports |
| Sub-blocks | `axi4_lite_bidir_fifo_bridge`, `async_fifo` ×2, `peripheral` | [`rtl/`](rtl) |
| Process / Library | gpdk045bc (timing), gsclib045 (physical), 45 nm CMOS | [`synthesis/normal/area.rpt`](synthesis/normal/area.rpt) |
| VDD | **1.08 V** | [`physical_design/reports/power.rpt`](physical_design/reports/power.rpt), [`signoff/voltus/power.rpt`](signoff/voltus/power.rpt) |
| Clock domains | 2, fully asynchronous, bridged by Gray-code dual-clock FIFOs | RTL |
| `s_axi_aclk` | 125 MHz (8 ns period) | confirmed via 8000 ps phase-shift in every timing report + 250 MHz toggle rate in power reports |
| `p_clk` | 100 MHz (10 ns period) | confirmed via 200 MHz toggle rate in power reports |

## 2. Area

| Parameter | Normal Synth. | Area-opt Synth. | Power-opt Synth. | Post-Route (Innovus) |
|---|---|---|---|---|
| Cell count | 2,240 | 2,281 | 2,241 | 3,085 total instances¹ |
| Cell area (µm²) | 12,160.725 | 12,289.702 | 10,005.877 | 17,369.060 (std cells) |
| Net area (µm²) | 3,003.769 | 3,078.572 | 2,231.532 | — |
| **Total area (µm²)** | **15,164.494** | **15,368.273** | **12,237.409** | 17,406.774 (core) |
| Die area | — | — | — | **162.2 × 163.97 µm (26,595.93 µm²)** |
| Core box | — | — | — | (15.0, 16.15) → (147.2, 147.82) |
| Number of cell rows | — | — | — | 77 |
| Core density (std cells + macros) | — | — | — | 99.783% |
| Core density (subtracting physical/filler cells) | — | — | — | **79.796%** |
| Chip density (subtracting physical cells) | — | — | — | 52.226% |

¹ 3,085 is the total post-route instance count (functional cells + clock-tree buffers/inverters + hold-fix buffers inserted during CTS and optimization — see [§6](#6-notable-finding-which-synthesis-run-was-actually-taken-to-p-and-r)). The Innovus power report explicitly logs **0 dedicated filler/decap cells**, so the "79.796% / 99.783%-with-fillers" density pair reported by `timeDesign` reflects two different density *definitions* (physical-cell-subtracted vs. not), not a filler-insertion step.

## 3. Timing

| Metric | Genus (Normal) | Genus (Area-opt) | Genus (Power-opt) | **Innovus (post-route)** | **Tempus (signoff)** |
|---|---|---|---|---|---|
| Setup WNS | +2.418 ns (example path) | +2.513 ns (`in2reg`) | +3.283 ns (`s_axi_aclk`) | **+2.633 ns** | **+2.627 ns** |
| Setup TNS | — | 0.000 | 0.000 | 0.000 | 0.000 |
| Hold WNS | — | — | — | **+0.049 ns** | **0.000 ns** |
| Hold TNS | — | — | — | 0.000 | 0.000 |
| Setup violating paths | — | 0 | 0 | 0 / 3,639 | 0 |
| Hold violating paths | — | — | — | 0 / 3,639 | 0 |
| Critical path type | — | — | — | I/O (`in2reg`) | I/O (`in2reg`) |
| `min_pulse_width` (endpoints) margin | — | — | — | — | +3.243 ns, 0 fails |

Setup/hold divergence between Innovus and Tempus: **6 ps** (setup), **49 ps** (hold) — both re-derive timing from the *same* post-route netlist + SPEF, so this is the expected engine-to-engine noise floor, not a real timing gap. Full detail: [§8](#8-comparison-2-tempus-signoff-timing-vs-innovus-implementation-timing).

## 4. Power

| Metric | Genus Normal | Genus Area-opt | Genus Power-opt | **Innovus (vectorless)** | **Voltus (activity-based)** |
|---|---|---|---|---|---|
| Total Power | 1.800 mW | 1.889 mW | 0.370 mW | **1.871 mW** | **1.402 mW** |
| Internal Power | 1.450 mW (80.56%) | 1.480 mW (78.36%) | 0.255 mW (68.93%) | 1.517 mW (81.09%) | 1.163 mW (82.96%) |
| Switching Power | 0.349 mW (19.42%) | 0.408 mW (21.62%) | 0.114 mW (30.97%) | 0.353 mW (18.88%) | 0.238 mW (17.00%) |
| Leakage Power | 0.43 µW (0.02%) | 0.44 µW (0.02%) | 0.37 µW (0.10%) | **0.505 µW** | **0.505 µW** (identical — leakage is activity-independent) |
| Clock network power | — | — | — | 0.2656 mW (14.2%) | 0.2656 mW (18.95%, identical mW value) |
| `p_clk` domain power | — | — | — | 0.1164 mW | 0.1164 mW |
| `s_axi_aclk` domain power | — | — | — | 0.1492 mW | 0.1492 mW |
| Sequential logic power | — | — | — | 1.457 mW (77.87%) | 1.104 mW (78.79%) |
| Combinational logic power | — | — | — | 0.1484 mW (7.93%) | 0.0317 mW (2.26%) |
| Activity source | vectorless / default | vectorless / default | vectorless / default | vectorless / default | **real SAIF from `tb_axi4_lite_coverage_verilog`** |

Full discussion: [§9](#9-comparison-3-voltus-signoff-power-vs-innovus-implementation-power).

## 5. Parasitics (identical between Tempus and Voltus — same SPEF)

| Parameter | Value |
|---|---|
| Total nets | 3,199 |
| Annotated | 3,194 (99.84%) |
| Not annotated | 5 (0.16%) — floating/no-load nets, never timed |
| Real, complete nets | 3,194 (100.00%) |
| Annotated resistance | 214.4120 KΩ (58,579 R elements) |
| Annotated capacitance | 9.5544 pF (59,477 C elements) |
| Annotated coupling (X) capacitance | 0.6587 pF (8,828 Xcap elements) |

## 6. Physical Verification (all clean)

| Check | Tool | Result |
|---|---|---|
| `verify_drc` | Innovus | 0 violations across all 4 sub-areas |
| `verify_connectivity -all` | Innovus | 0 violations, 0 warnings |
| `verify_antenna` | Innovus | 0 violations |
| Routing overflow | Innovus | 0.00% H / 0.00% V |

## 7. Code Coverage

| Metric | Score |
|---|---|
| Overall coverage score | 93.82% |
| Line coverage | 95.20% |
| Condition coverage | 79.20% |
| Toggle coverage | 99.53% |
| FSM coverage | 100.00% |
| Branch coverage | 95.16% |
| `u_bridge` sub-block score | 94.99% |
| `u_peripheral` sub-block score | 95.14% |
