# Minisys Flash Programming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent SPI Flash programming flow so the Minisys board can boot this bitstream after power cycling.

**Architecture:** Keep the existing SRAM/JTAG `.bit` programming flow unchanged for fast debugging. Add one dedicated Vivado Tcl script that converts the existing `.bit` into an `.mcs` file and writes it into the board SPI Flash, plus README instructions for build, flash programming, and jumper/power-cycle verification.

**Tech Stack:** Vivado 2018.3 Tcl, Xilinx 7-series configuration memory flow, Minisys `xc7a100tfgg484-1`.

---

### Task 1: Add Flash Programming Script

**Files:**
- Create: `scripts/program_fmcpga_tft_flash.tcl`

- [ ] **Step 1: Create a Tcl script that validates the bitstream and emits an MCS file**

The script should:
- Use `vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit`.
- Write `vivado_fmcpga_tft/flash/minisys_fmcpga_tft_top.mcs`.
- Default to `n25q64-3.3v-spi-x1_x2_x4`, matching the Flash part detected by Vivado on the Minisys board.
- Accept optional arguments for cfgmem part and size.

- [ ] **Step 2: Add hardware connection and cfgmem programming**

The script should:
- Open the hardware server and first available target.
- Select the first hardware FPGA device.
- Create a hardware cfgmem object using a Vivado cfgmem part.
- Program and verify the MCS file into Flash.

- [ ] **Step 3: Keep the existing SRAM programming script unchanged**

Do not modify `scripts/program_fmcpga_tft.tcl`; it remains the fast temporary programming path.

### Task 2: Document the Persistent Boot Flow

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rename the current programming section as temporary SRAM programming**

Clarify that `program_hw_devices` is volatile and disappears after power-off.

- [ ] **Step 2: Add persistent SPI Flash programming commands**

Document:

```tcl
cd C:/Users/32915/Desktop/shudiankeshe
source scripts/program_fmcpga_tft_flash.tcl
```

Also document the optional override form:

```tcl
set minisys_cfgmem_part_name n25q64-3.3v-spi-x1_x2_x4
set minisys_cfgmem_size_mbit 64
source scripts/program_fmcpga_tft_flash.tcl
```

- [ ] **Step 3: Add hardware verification steps**

Tell the user to set the Minisys programming jumper to boot from SPI Flash, power cycle the board, and check that the TFT project starts without re-running Vivado programming.

### Task 3: Verify Static Consistency

**Files:**
- Test: `scripts/program_fmcpga_tft_flash.tcl`
- Test: `README.md`

- [ ] **Step 1: Check changed files**

Run:

```powershell
git diff -- scripts/program_fmcpga_tft_flash.tcl README.md docs/superpowers/plans/2026-05-13-minisys-flash-programming.md
```

Expected: The diff only adds the Flash programming script, README instructions, and this implementation plan.

- [ ] **Step 2: Search for the new command names**

Run:

```powershell
rg -n "program_fmcpga_tft_flash|write_cfgmem|program_hw_cfgmem|SPI Flash" scripts README.md
```

Expected: The new script and README mention the persistent Flash flow.
