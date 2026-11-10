# 面积、置信带和堆叠面积的交互

`fill_between`、`fill_betweenx` 和 `stackplot` 使用现有静态入口。调用 `to_drawing()` 后，
Rabbita 可以在实际填充内部响应 hover/click，无需命中边界顶点。
静态 SVG 输出保持不变。

## 取得原始采样信息

```mbt nocheck
let fig = @mathplotlib.figure(width=640, height=360)
try! fig.fill_between(
  [0.0, 2.0, 10.0],
  [1.0, 2.0, 4.0],
  [5.0, 8.0, 6.0],
  label="预测区间",
)
let frame = try! fig.to_drawing()
let point = frame.points()[1] // 事件中的 HitPoint 也可以直接用于查询。
let info = frame.hit_info(point).unwrap()
// info.kind == Area；info.band 为 Some(BandInfo)。
```

`BandInfo` 是只读数值，包含：

| 字段 | 含义 |
|---|---|
| `lower` | 原始采样位置上的第一条边界 |
| `upper` | 原始采样位置上的第二条边界 |
| `horizontal` | `fill_betweenx` 为 true，沿 y 方向选择采样点 |
| `stacked` | 堆叠面积为 true，其 `HitInfo.value` 是原输入系列值 |

字段名沿用上下界习惯，但保留调用时的方向；传入 left=7、right=2，不会把它们排序。
`point.point_index` 保留原始输入索引，包括 NaN、mask 断段之后的索引。
`point.data_x/data_y` 是第二条边界的实际原采样点；默认提示使用主方向上的采样位置和两条边界。
普通带的 `info.value` 是第二条边界值；堆叠面积则是对应系列的原始输入值。
堆叠的上下界复用实际绘制前已计算的基线和累积值，支持 `zero`、`sym`、`wiggle` 和 `weighted_wiggle`。
不通过累积上下界相减反推原系列值，因此不会把浮点相减误差当成输入数据。

Rabbita 的 `tooltip` 回调可直接读取 `info.band`，补充单位、日期与中文格式；
现有 `tooltip_visible`、`tooltip_class` 和 CSS 自定义属性继续有效。
默认堆叠提示额外显示原始 `Value`。

## 几何与选择规则

- 命中的是同次真实 SVG 填充断段的内部，使用不可变的 `Quadrilateral` 几何；没有从 SVG 字符串反推坐标。
- 沿主方向选择屏幕距离最近的实际采样点，不对数据做插值。相邻样本的归属分界在实际屏幕中点，
  对数轴和反向轴也遵循同一规则。
- 相邻样本的共享分界及重叠区域由后绘制目标优先。一个样本可能对应相邻区间的多个四边形，
  因此 `targets()` 数量可以多于 `points()`；`hit_info(point)` 返回相同的样本元数据。
- NaN、mask 和非法对数点切开填充；缺失段不桥接，单个有效点不生成填充目标。
- 面板裁剪、图内 SVG 图例遮挡、多面板、CSS 缩放和 letterbox 沿用 Drawing 的统一处理。
  带端点可能位于视口外，仍可从被裁剪后可见的内部选择该原始样本。
- Drawing 保留独立快照。清空、替换数据或重绘后，新图使用新元数据；已有 Drawing 不随调用方输入数组变化。

本次覆盖每个连续有效断段上严格单调的采样位置，允许递增或递减、不等步长及交叉边界。
非单调或重复采样位置可能改变完整多边形的绕行语义，暂不生成交互目标，静态 SVG 照常输出。
零面积填充、`none` 和 `transparent` 不生成可交互目标；一般多边形和 `stairs(fill=true)` 不在本次语义范围内。
新增 `Area` 和 `Quadrilateral` 枚举变体后，穷尽匹配 `HitKind` / `HitShape` 的调用方需要增加对应分支。
