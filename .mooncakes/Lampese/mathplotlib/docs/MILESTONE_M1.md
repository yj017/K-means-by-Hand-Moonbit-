# M1：基础二维 SVG 可用版

验收日期：2026-10-24。**已完成验收，可作为首次可用里程碑。**

## 本轮交付

- 修复默认 `which="both"` 时 `grid(axis="x"/"y")` 抛出 InvalidTicks 的问题。
- 修复柱状图自动范围漏算柱宽导致越框；水平柱同样修复，单柱宽度固定在数据坐标中。
- 增加 `LegendPosition::{UpperRight, UpperLeft, LowerRight, LowerLeft}` 与 Axes/Figure 的位置读写。
- 增加 `cmd/gallery` 折线、散点、分类柱状图组合；默认范围与刻度保留自动计算。
- 将现行计划收束为能力目标；原长迁移计划与执行历史保存在 archive/。

## 可复现的三个示例

在仓库根目录执行：

```sh
moon install
moon run cmd/main --target native > minimal.svg
moon run cmd/preview --target native > two-series.svg
moon run cmd/gallery --target native > gallery.svg
```

- `cmd/main`：最小折线。
- `cmd/preview`：双折线、散点、显式范围与刻度、图例。
- `cmd/gallery`：独立三面板、默认范围与刻度、分类标签、y 方向网格、左上角自动图例。

打开 SVG 即可查看。仓库中的 PNG 是由外部 SVG 工具生成的展示图，不是新增 PNG 输出后端。

## 新增易用性接口

```moonbit nocheck
let fig = @mathplotlib.figure()
fig.set_legend_position(@mathplotlib.LegendPosition::LowerLeft)
// 每个子图也可独立调用 axes.set_legend_position(...)
```

新建与完整 clear 后默认为 UpperRight。`clear_legend()` 恢复原有自动条目行为并保留位置。
显式图例条目、自动标签和已有 legend API 均沿用原行为。

## 验证记录

全部检查在本轮最终源码上通过：

| 检查 | 结果 |
| --- | --- |
| `moon check --target all` | wasm / wasm-gc / js / native 通过；7 条既有 Ref 弃用警告，0 error，无新增警告 |
| 相关回归（命令如下） | 四目标各 **353/353**；覆盖整个 SVG 后端与相关 Scene/root 工作流 |
| `moon info && moon fmt` | 通过；4 份接口仅新增图例类型/位置读写和 IR 可选参数，未删除旧入口 |
| 柱宽私有修复接口检查 | 全部 42 份生成接口与已审查版本逐字相同 |
| 三个示例 `moon run ... --target native` | 全部 exit 0，stdout 为可解析 SVG |
| `cmd/preview` 输出 | 与原 `assets/two-series.svg` 逐字相同 |
| 新 Gallery | 1200×420 SVG；2 条折线、7 个散点、4 根柱；标题/分类/轴标签完整；数据几何均在各自面板内 |
| 实际视觉检查 | 2400×840 PNG 预览通过，柱子不再越框遮刻度，面板/图例/标签显示清楚 |

```sh
moon test backend/svg \
  scene/figure_test.mbt scene/category_test.mbt \
  scene/statistics_test.mbt scene/image_test.mbt scene/date_test.mbt \
  scene/autoscale_state_wbtest.mbt scene/grid_axis_regression_test.mbt \
  scene/legend_position_test.mbt scene/legend_position_wbtest.mbt \
  tests/api/readme_examples_test.mbt tests/api/usability_test.mbt --target all
```

新增 14 个回归。grid 的真实调用在修复前会失败；柱宽修复前的首4个回归全部失败，
修复后连同其余相关测试通过。未修改旧测试预期或上游参考数据来让测试通过。
本轮针对变更选择回归，没有把历史两万余项全套重跑称为当前结果。

[实际 SVG](../assets/gallery.svg) · [示例源码](../cmd/gallery/main.mbt) · [PNG 展示预览](../assets/gallery.png)

本地详细日志在 `.moonagent/checkpoints/M1-2026-10-24/`，重现结果以本页公开命令为准。

## 实用边界与下一目标

M1 验收覆盖本页的代表性流程和相关输入；不意味着任意参数、图表组合都无问题。
图例暂为固定宽度、每行固定高度，长标签和非常小的画布仍需调用者合理安排布局。
SVG 字体由查看器提供，完整文字测量与自动避让尚未提供。

M1 本身只验收静态 SVG。后续独立切片 [Rabbita 可交互 DOM（G2.1）](RABBITA_DOM.md)
现已交付，不追溯计入 M1；独立 PNG/PDF、3D 或完整 TeX 排版后端仍未提供。
