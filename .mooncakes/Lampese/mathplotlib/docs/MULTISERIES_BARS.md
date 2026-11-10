# 多系列分类柱图

`Figure` 和 `Axes` 都提供 `grouped_bar`（分组）与 `stacked_bar`（堆叠）。
`series` 按系列组织，每个内层数组按 `categories` 顺序提供数值。

```moonbit
let fig = @mathplotlib.figure(width=640, height=360)
fig.grouped_bar(
  ["North", "South", "West"],
  [[3.0, 5.0, 4.0], [4.0, 2.0, 6.0]],
  labels=["2025", "2026"],
  colors=["#5e91a8", "#dc9c65"],
  width=0.8,
  gap=0.1,
)
let snapshot = fig.to_drawing()
```

分组柱的 `width` 是一组在分类轴上占据的跨度，以分类间距 1 为单位。
该跨度均分为系列槽位，`gap` 指每个槽位留空的比例，合法范围为 `[0, 1)`。
柱子在槽位中居中；`gap=0` 时相邻柱贴合。默认柱宽按实际数据坐标绘制，
窄柱不会为了显示而强制增宽成一个像素。`width` 必须为正且有限。

```moonbit
fig.axes().clear()
fig.stacked_bar(
  ["North", "South"],
  [[4.0, -2.0], [3.0, -5.0], [-1.0, 6.0]],
  labels=["A", "B", "C"],
  horizontal=true,
  baseline=0.0,
)
```

两种入口均支持 `horizontal=true`；分类将位于 y 轴，数值位于 x 轴。
`baseline` 默认为 0。堆叠图在每个分类内分别累计正值和负值，二者从同一个
`baseline` 开始。自动范围包含实际柱宽、非零起点及累计终点。

`labels`、`colors` 可省略；提供时长度必须等于系列数，未指定颜色时使用现有颜色循环。
每个系列保留独立的图例和 Bar 容器。重建隐藏系列时，清空对应 Axes 并使用保留的
标签和颜色重新调用；新 Drawing 只含当前系列，旧 Drawing 仍是独立快照。

每个内层数组长度必须等于分类数。尺寸不符抛出 `DataError::LengthMismatch`；
非法宽度、间隔、基线、无限值或累计溢出抛出 `DataError::InvalidStatistics`，
输入检查在附加图形前完成。`NaN` 作为缺失值跳过，不推进堆叠累计；零值不产生可命中区域。

交互直接复用 Rabbita 的柱图提示：整段矩形可 hover/click，`HitInfo` 提供系列名、
类别和**该段原始值**。例如第二段从 4 堆到 7，`info.value` 为 3，
`info.point.data_y` 为实际顶点 7；横向图对应 `data_x`。
CSS 缩放、留白、面板裁剪和 SVG 图例遮挡规则与普通柱一致。

Log 与 Logit 视图会裁剪真实矩形。Logit 上从 0 到 1 的柱段能覆盖有效概率区间，
即使两个端点都处于尺度边界；自动范围会选择严格位于 `(0, 1)` 内的有限视图。
反向坐标轴与横向柱遵循同样的规则，完全位于有效域外的柱段不绘制也不命中。

底层 `Artist::BarSegments(Array[BarSegment], Bool, Style)` 使用显式位置、宽度和基线。
`Bool` 指横向；`BarSegment` 是只读值，通过 `bar_segment(position, value, baseline=..., width=..., category=...)`
构造。现有 `Artist::Bar`、`Artist::BarH` 与原有 `bar` / `barh` 的默认行为保持不变。
调用方若穷尽匹配 `Artist`，需补上 `BarSegments` 分支，或按需求保留默认分支。
