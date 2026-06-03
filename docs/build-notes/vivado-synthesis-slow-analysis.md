# Vivado 综合与实现耗时原因分析

本文记录 Minisys FmcPGA Minecraft TFT 工程在 Vivado 2018.3 中综合、实现和生成 bitstream 耗时较长的排查结论，可作为课程报告中“问题分析”和“未来改进”部分的参考。

## 1. 总体结论

本工程构建耗时较长不是单一原因造成的，而是由构建流程、设计规模和 HDL 写法共同叠加导致。

主要原因包括：

1. 当前 Tcl 构建流程偏向全量重建，无法充分复用 Vivado 中间结果。
2. 项目本身实现了类 Minecraft 体素渲染管线，包含地图 RAM、纹理 ROM、帧缓冲、几何计算、射线步进和颜色混合，资源规模较大。
3. 核心 HDL 中存在组合除法、宽整数运算、长组合路径、异步 reset 等对 FPGA 综合和时序收敛不友好的结构。
4. 日志显示耗时不只发生在 `synth_design`，还明显分布在 `place_design`、`route_design` 和 `write_bitstream` 阶段。

因此，报告中不应简单写成“Vivado 综合慢”，更准确的表述是：本项目全流程构建慢，综合和实现阶段都存在耗时。

## 2. 构建流程导致全量重建

当前脚本为了保证工程可复现，使用 Tcl 从源码重建 Vivado 工程。这对提交仓库和换机器复现是有利的，但日常调试时会牺牲增量构建速度。

关键证据：

- `scripts/create_fmcpga_tft_project.tcl` 中使用 `create_project ... -force`，会强制创建或覆盖 Vivado 工程目录。
- `scripts/build_fmcpga_tft_multicore.tcl` 中执行 `reset_run synth_1` 和 `reset_run impl_1`，会清空已有综合和实现结果。
- README 的手动构建流程也包含 `reset_run synth_1` 和 `reset_run impl_1`。
- 当前工程没有配置 `incremental_checkpoint`、`read_checkpoint` 或自动增量实现流程。

这意味着每次按完整脚本构建时，Vivado 很难复用已有 `.runs`、`.cache`、`.Xil` 和 DCP 中间结果，实际效果接近全量构建。

报告可写：

> 为保证工程可复现，当前构建脚本使用 `create_project -force` 和 `reset_run` 从头构建工程。这种方式可靠但牺牲了 Vivado 的增量编译能力，导致每次修改后都需要重新综合和实现，是构建耗时较长的重要原因。

## 3. 实测耗时分布

从当前成功构建的 Vivado 日志看，各阶段耗时如下：

| 阶段 | 约耗时 | 说明 |
| --- | ---: | --- |
| `synth_design` | 2 分 53 秒 | 综合阶段，含 RTL elaboration、跨层优化、technology mapping |
| `opt_design` | 30 秒 | 实现前逻辑优化 |
| `place_design` | 1 分 46 秒 | 布局阶段 |
| `route_design` | 2 分 27 秒 | 布线阶段 |
| `write_bitstream` | 29 秒 | bitstream 生成 |

由此可见，耗时并不只集中在综合阶段。实现阶段，尤其是布局和布线，也占用了明显时间。

报告可写：

> Vivado 日志显示，`synth_design` 约耗时 2 分 53 秒，而布局和布线合计也超过 4 分钟。因此后续优化不能只关注综合，还需要降低布局布线压力和时序收敛难度。

## 4. 设计资源规模较大

资源报告显示，本工程不是简单的控制逻辑，而是一个较完整的渲染系统。综合后资源使用情况大致如下：

| 资源 | 使用量 | 占比 |
| --- | ---: | ---: |
| Slice LUTs | 约 27,592 / 63,400 | 43.52% |
| Block RAM Tile | 约 76.5 / 135 | 56.67% |
| DSP | 约 52 / 240 | 21.67% |

BRAM 使用超过一半，主要来自地图 RAM、纹理 ROM 和双帧缓冲。LUT 和 DSP 使用也较高，说明设计中有较多组合逻辑和算术运算。

报告可写：

> 工程中包含地图存储、纹理存储、双帧缓冲、坐标变换、射线步进、颜色混合等模块，导致 LUT、BRAM 和 DSP 均有明显占用。资源规模较大使 Vivado 在综合、布局、布线和时序优化阶段需要处理更复杂的网表。

## 5. HDL 结构与写法造成综合压力

### 5.1 组合除法器

`rtl/ip_replacements/divider_gen.v` 中使用组合 `/` 和 `%` 实现除法和取余。该模块在 `pipeline_process.vhd` 中被实例化 6 次，用于射线步进相关计算。

组合除法会让综合器推断较复杂的组合逻辑或 DSP/LUT 结构，通常比流水化 Divider IP 更难优化，也更容易拉长关键路径。

报告可写：

> 当前工程用组合 `/` 和 `%` 替代原 Vivado Divider IP，并在核心流水线中实例化多个除法器。这种写法功能上可综合，但硬件代价较高，会增加综合和时序优化压力。

### 5.2 宽整数与 record 运算

`vendor/FmcPGA/src/hdl/general/types.vhd` 中定义了 `vec3i_t`、`color_t` 等 record 类型，并重载了加减乘除、长度计算、叉乘和颜色混合函数。

这些表达方式接近软件中的向量和颜色对象，代码可读性较好，但综合时会展开为大量乘法器、加法器、比较器和除法器。若位宽没有精细约束，综合器需要推断更宽的硬件结构。

报告可写：

> FmcPGA 核心为了表达三维坐标和颜色计算，使用了 VHDL record、integer 和重载运算。该写法便于描述算法，但会把高层几何运算直接展开为硬件算术网络，增加综合复杂度。

### 5.3 长组合路径

实现后的 timing 报告中，存在逻辑层数达到 161 级的关键路径，包含大量 `CARRY4`、LUT 和 DSP48E1。长组合路径会使 Vivado 在综合优化、布局和布线阶段做更多尝试，以满足时序约束。

报告可写：

> 关键路径中存在 161 级逻辑，说明部分计算链路较长。长组合路径不仅影响最高频率，也会增加 Vivado 的逻辑重构、布局和布线搜索成本。

### 5.4 查表逻辑未充分 ROM 化

`angle_to_coord.vhd` 中角度到坐标的近似计算使用较长的条件选择链，而不是明确的 ROM 查表结构。此类写法会生成比较器和多路选择器链，可能增加综合优化时间和组合路径深度。

报告可写：

> 部分近似函数使用长条件链实现。未来可考虑改为 ROM 查表或 Block RAM/Distributed ROM，以减少比较器和多路选择器链。

### 5.5 异步 reset 影响 DSP/BRAM 优化

Vivado DRC 和 methodology 报告提示：

- DSP 输入/输出寄存器流水不足。
- 部分 RAMB36/RAMB18 输入由带异步 reset 的寄存器驱动。
- 异步 reset 可能阻止寄存器被吸收到 DSP 或 BRAM 内部，降低优化空间。

报告可写：

> 当前设计中存在较多异步 reset 相关 warning。异步 reset 虽然便于初始化状态，但会限制 DSP/BRAM 内部寄存器吸收和流水优化，进而增加时序收敛难度。

## 6. 关于“vibe coding 导致 HDL 能力不足”的分析

老师提到“vibe coding 硬件描述语言能力差”可能导致综合慢，这个说法需要分开看。

### 6.1 成立的部分

如果这里的 “vibe coding” 指的是用偏软件思维描述硬件，那么本工程中确实有一些证据：

- 使用组合 `/` 和 `%` 实现除法器，而不是使用流水化 Divider IP 或多周期除法器。
- 使用泛化 `integer`、record 和重载运算表达空间几何，位宽和流水阶段控制不够硬件化。
- 长条件选择链没有改成 ROM 查表。
- 异步 reset 较多，影响 DSP/BRAM packing 和时序优化。
- 一些计算链路较长，说明流水切分还可以继续细化。

这些问题确实体现了 HDL 设计中“功能优先、硬件代价意识不足”的特点。

### 6.2 不应简单归因的部分

但不能简单说“因为用了 AI/vibe coding，所以综合慢”。本项目本身是实时体素渲染器，功能天然复杂。即使完全由人工编写，只要实现地图、纹理、视角坐标、射线步进、颜色混合和 TFT 输出，也会产生较大的资源占用和构建耗时。

混合语言、VHDL 2008 和扁平 wrapper 也不是主要问题。当前日志显示 VHDL 和 Verilog 模块绑定正常，真正资源消耗最大的部分仍然是 FmcPGA 核心渲染管线。

报告建议写法：

> 综合慢不能简单归因于 AI 生成代码，但本工程确实暴露出一些偏软件化的 HDL 表达方式。未来需要从“能综合”进一步转向“适合 FPGA 综合”，重点优化除法器、位宽、流水、查表和 reset 策略。

## 7. 未来改进方向

后续可以从以下方向优化：

1. 日常调试时避免每次 `create_project -force`，已有工程存在时优先 `open_project`。
2. 非必要时不要执行 `reset_run synth_1` 和 `reset_run impl_1`。
3. 引入 Vivado checkpoint 或 incremental implementation。
4. 默认构建脚本设置 `set_param general.maxThreads`，并区分全量构建和增量构建。
5. 将组合 `divider_gen` 替换为 Vivado Divider Generator IP 或多周期流水除法器。
6. 将 `angle_to_coord` 等长条件链改成 ROM 查表。
7. 收紧 `integer` 运算位宽，使用明确的 `signed/unsigned` 定点宽度。
8. 给 DSP 相关乘法输入/输出增加流水寄存器。
9. 尽量使用同步 reset，减少异步 reset 对 DSP/BRAM 优化的影响。
10. 将 `pipeline_process` 继续拆分，明确每一级流水边界，降低单模块综合和时序优化压力。

## 8. 可用于报告的简短总结

本项目综合和实现耗时较长，主要原因是构建流程每次偏全量重建，Vivado 无法充分复用中间结果；同时项目本身实现了较复杂的体素渲染管线，LUT、BRAM、DSP 使用率较高。HDL 中还存在组合除法、宽整数 record 运算、长组合路径、异步 reset 等对 FPGA 综合不够友好的写法。未来可通过增量构建、流水化除法器、ROM 查表、位宽收敛、同步 reset 和模块拆分等方式改进。
