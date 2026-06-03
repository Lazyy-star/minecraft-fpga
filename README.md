# Minisys FmcPGA Minecraft TFT

本项目是一个面向 Minisys FPGA 开发板的 FmcPGA Minecraft-like 体素渲染器移植工程，目标器件为 `XC7A100T-FGG484-1`。工程保留原始 FmcPGA 的 VHDL 渲染核心，并在其外层增加 Verilog 板级顶层、TFT 显示适配和源码级 IP 替代模块，用于在 Minisys 的 800x480 TFT 接口上显示 320x240 的 FmcPGA 渲染画面。

Vivado 生成目录不提交到仓库；请使用 `scripts/` 下的 Tcl 脚本重新创建工程。

## 快速复现

克隆仓库后，在 Vivado 2018.3 Tcl Console 中进入仓库根目录，再执行工程创建和构建脚本：

```powershell
git clone https://github.com/Lazyy-star/minecraft-fpga.git
cd minecraft-fpga
```

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/create_fmcpga_tft_project.tcl
source scripts/run_fmcpga_tft_build.tcl
```

仓库已经包含构建所需的 RTL、VHDL、约束、MEM 初始化文件、原始 COE/纹理资源和 Vivado Tcl 脚本；不需要提交或下载 Vivado 生成的工程目录。

## 技术栈与硬件

- HDL：Verilog、VHDL 2008
- 工具链：Vivado 2018.3
- 开发板：Minisys，`xc7a100tfgg484-1`
- 主时钟：`clk_100m`，100 MHz
- 显示接口：800x480 TFT，RGB323 输出
- 渲染帧缓冲：320x240，RGB444
- 渲染管线时钟：约 7.48 MHz；TFT 像素时钟独立保持约 33.33 MHz
- 资源初始化：由 COE 转换为 MEM，再通过 `$readmemh` 初始化 RAM/ROM
- 辅助脚本：Tcl、PowerShell

## 总体架构

工程采用混合语言分层架构：

```text
Minisys 时钟/按键/拨码/引脚
  -> rtl/top/minisys_fmcpga_tft_top.v
  -> rtl/tft/ TFT 时钟与 800x480 时序
  -> rtl/vhdl/fmcpga_core_flat.vhd
  -> vendor/FmcPGA/ 原始 VHDL 渲染、控制、地图、纹理管线
  -> display_buffers 生成 320x240 RGB444 帧缓冲
  -> rtl/adapter/fmcpga_tft_read_mapper.v
  -> rtl/adapter/fmcpga_rgb444_to_rgb323.v
  -> TFT_R/G/B、TFT_CLK、TFT_DE、TFT_HSYNC、TFT_VSYNC 输出
```

`minisys_fmcpga_tft_top` 是正式板级顶层。它接收 Minisys 的 100 MHz 时钟、按键和拨码开关，生成 TFT 像素时钟与同步信号，实例化 FmcPGA 核心，并把核心输出的 RGB444 帧缓冲转换为 TFT RGB323 信号。

`fmcpga_core_flat` 是 VHDL 核心封装层。原始 FmcPGA 顶层使用了 VHDL record 等不便于直接从 Verilog 连接的类型，因此本项目提供扁平化 wrapper，只向 Verilog 顶层暴露普通 `std_logic` / `std_logic_vector` 端口。它内部连接原 FmcPGA 的渲染管线、玩家状态更新、地图修改、纹理读取和双缓冲显示 RAM。

## 目录结构

```text
rtl/top/
  Minisys 板级顶层。正式顶层为 minisys_fmcpga_tft_top.v，
  显示链路 smoke test 顶层为 fmcpga_frame_test_top.v。

rtl/tft/
  TFT 像素时钟和 800x480 时序发生器。

rtl/adapter/
  320x240 FmcPGA 帧缓冲到 800x480 TFT 的读地址映射，
  以及 RGB444 到 RGB323 的颜色转换。

rtl/audio/
  A19 蜂鸣器方波音频，包含原创背景旋律和放置/挖掘交互音效。

rtl/vhdl/
  FmcPGA 核心扁平化 VHDL wrapper。

rtl/ip_replacements/
  用源码形式替代原 Vivado IP 的模块，包括 PLL、RAM、ROM 和 divider。

vendor/FmcPGA/
  导入的原始 FmcPGA VHDL 源码、纹理、地图、COE 资源和原约束。

mem/
  从 COE 转换得到的 MEM 初始化文件。

constraints/
  Minisys 引脚约束和时钟约束。

scripts/
  Vivado 工程创建、构建、资源转换和静态检查脚本。

docs/
  迁移设计说明、构建说明、实施计划和记录。
```

## 入口文件

正式工程入口：

```text
rtl/top/minisys_fmcpga_tft_top.v
scripts/create_fmcpga_tft_project.tcl
```

显示链路 smoke test 入口：

```text
rtl/top/fmcpga_frame_test_top.v
scripts/create_fmcpga_tft_smoke_project.tcl
```

## 显示数据流

FmcPGA 渲染核心输出 320x240 RGB444 帧缓冲。Minisys TFT 可视区为 800x480，`fmcpga_tft_read_mapper` 将源帧 2 倍放大到 640x480，并水平居中显示，左右各留 80 像素黑边：

```text
if 80 <= pix_x < 720 and 0 <= pix_y < 480:
    src_x = (pix_x - 80) >> 1
    src_y = (240 - 1) - (pix_y >> 1)
    read_addr = src_y * 320 + src_x
else:
    output black
```

颜色适配由 `fmcpga_rgb444_to_rgb323` 完成：

```text
TFT_R_O = rgb444[11:9]
TFT_G_O = rgb444[7:6]
TFT_B_O = rgb444[3:1]
```

## 控制映射

- `S1` / `btn_up`：向右移动
- `S2` / `btn_down`：向左移动
- `S3` / `btn_left`：向前移动
- `S4` / `btn_right`：向后移动
- `S5` / `btn_action`：执行一次动作
- `S6` / `btn_reset`：复位
- `SW[4:0]`：选择方块 ID，推荐范围 `0` 到 `23`
- `SW[5]`：动作模式，`0` 表示放置所选方块，`1` 表示挖掘准星选中的方块
- `SW[6]`：视角模式，`0` 为移动模式，`1` 为旋转视角模式
- `SW[7]`：背景音乐静音，`0` 播放，`1` 静音

`S5` 每次按下只触发一次动作。挖掘不会因为 `SW[5]` 保持为高而连续执行。

在 `SW[6] = 1` 时，S1/S2 控制左右转向，S3/S4 控制上下视角；S5、`SW[4:0]` 和 `SW[5]` 的方块交互功能保持不变。画面右下角会绘制一个手持方块 HUD，颜色随当前 `SW[4:0]` 选择的方块变化。

## 蜂鸣器音频

Minisys 实验板的蜂鸣器连接到 FPGA 的 A19 管脚，本项目顶层端口为 `BUZZER_O`。`rtl/audio/buzzer_audio.v` 使用 `clk_100m` 产生方波音频：

- 背景音乐：原创的慢速方波旋律，气质上参考 Minecraft 的舒缓环境音乐，但不直接复刻原曲。
- 交互音效：S5 触发时播放短音效，放置方块为上行音，挖掘方块为下行音；音效优先级高于背景音乐。
- 静音控制：`SW[7] = 1` 时关闭背景音乐，但交互音效仍会播放。

## IP 替代与资源

本工程使用源码级 Verilog 模块替代原始 Vivado IP，模块名保持与原 FmcPGA IP 实例名一致，便于 VHDL 核心继续实例化：

```text
clk_ppl_generator
display_ram
map_ram
texture_rom
txt_idx_map_rom
divider_gen
```

运行时没有传统软件意义上的数据库、后端服务或网络外部服务。核心数据来自 FPGA 片上 RAM/ROM：

- 地图数据：`mem/map_test.mem`
- 纹理数据：`mem/textures.mem`
- 方块到纹理索引映射：`mem/txt_idx_map.mem`

这些 MEM 文件由 `vendor/FmcPGA/res/coe/` 下的 COE 资源转换得到。需要重新生成时执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/convert_coe_to_mem.ps1
```

## 构建

在 Vivado 2018.3 Tcl Console 中执行：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/create_fmcpga_tft_project.tcl
source scripts/run_fmcpga_tft_build.tcl
```

也可以手动分步运行：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/create_fmcpga_tft_project.tcl
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1
wait_on_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

生成 bitstream 的预期路径：

```text
vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

## Smoke Test

如果只想先验证 TFT 时序、颜色输出和 320x240 到 800x480 的映射链路，可创建 smoke test 工程：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/create_fmcpga_tft_smoke_project.tcl
launch_runs synth_1
wait_on_run synth_1
```

## 烧录开发板

### 临时烧录到 FPGA

这种方式通过 JTAG 把 `.bit` 下载到 FPGA 配置 SRAM，适合调试；板子断电后配置会丢失。

在 Vivado 2018.3 Tcl Console 中执行：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/program_fmcpga_tft.tcl
```

等价的手动命令如下：

```tcl
open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE {vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
```

### 持久烧录到 SPI Flash

这种方式会先把 bitstream 转成 `.mcs` 配置文件，再写入 Minisys 板载 SPI Flash。写入成功后，把 Minisys 编程跳线设置为上电从 SPI Flash 启动，之后每次打开板子都会自动加载本项目，不需要重新综合或重新 JTAG 烧录。

先确保已经完成构建并生成 bitstream：

```text
vivado_fmcpga_tft/fmcpga_minisys_tft.runs/impl_1/minisys_fmcpga_tft_top.bit
```

然后在 Vivado 2018.3 Tcl Console 中执行：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/program_fmcpga_tft_flash.tcl
```

当前开发板经 Vivado 实测识别为 `n25q64-3.3v`，在 Vivado 2018.3 中对应 `n25q64-3.3v-spi-x1_x2_x4`。若 Vivado 中的 Flash part 名称仍需手动指定，可以在 `source` 前设置 part 和容量：

```tcl
set minisys_cfgmem_part_name n25q64-3.3v-spi-x1_x2_x4
set minisys_cfgmem_size_mbit 64
source scripts/program_fmcpga_tft_flash.tcl
```

如果 Vivado 报告找不到该 Flash part，可先查询本机 Vivado 2018.3 支持的候选名称：

```tcl
get_cfgmem_parts *n25q*
```

写入完成后执行硬件验证：

1. 关闭开发板电源。
2. 按 Minisys 硬件手册把编程跳线设置为从 SPI Flash 启动。
3. 重新上电。
4. 不执行 Vivado 烧录命令，确认 TFT 直接显示本项目画面。

若上电后没有反应，可以先只校验 Flash 内容是否仍与生成的 `.mcs` 一致。该命令会临时配置 FPGA 用于访问 SPI Flash，但不会擦除或重写 Flash：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/verify_fmcpga_tft_flash.tcl
```

如果 Verify 通过但上电仍无画面，请断电、确认跳线已经设置为从 SPI Flash 启动、重新上电，然后只读取 FPGA 启动状态：

```tcl
cd <minecraft-fpga 仓库根目录>
source scripts/check_fmcpga_tft_boot_status.tcl
```

## 检查脚本

仓库提供若干 PowerShell 检查脚本，用于快速确认文件、控制映射和显示链路是否符合当前移植方案：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_sources.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_control_mapping.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_display_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_requested_adjustments.ps1
```

## 关键文件

- `rtl/top/minisys_fmcpga_tft_top.v`：正式 Minisys 顶层
- `rtl/top/fmcpga_frame_test_top.v`：TFT 显示链路 smoke test 顶层
- `rtl/vhdl/fmcpga_core_flat.vhd`：FmcPGA 核心扁平化 wrapper
- `rtl/tft/tft_clock_gen.v`：TFT 像素时钟
- `rtl/tft/tft_timing.v`：800x480 TFT 时序
- `rtl/adapter/fmcpga_tft_read_mapper.v`：帧缓冲读地址映射
- `rtl/adapter/fmcpga_rgb444_to_rgb323.v`：颜色格式转换
- `rtl/adapter/fmcpga_hand_overlay.v`：手持方块 HUD 叠加
- `rtl/audio/buzzer_audio.v`：蜂鸣器背景音乐与交互音效
- `rtl/ip_replacements/`：Vivado IP 源码替代模块
- `constraints/minisys_fmcpga_tft.xdc`：Minisys 约束
- `scripts/create_fmcpga_tft_project.tcl`：正式工程创建脚本
- `scripts/run_fmcpga_tft_build.tcl`：构建与报告生成脚本
- `docs/build-notes/fmcpga-minisys-tft.md`：构建与硬件验证说明
- `docs/superpowers/specs/2026-04-29-fmcpga-minisys-tft-design.md`：迁移设计说明

## 许可证说明

原始 FmcPGA 项目使用 GPL 许可证。本仓库在 `vendor/FmcPGA/` 中包含导入的 FmcPGA 源码与资源；发布或再分发时请保留并遵守上游许可证。
