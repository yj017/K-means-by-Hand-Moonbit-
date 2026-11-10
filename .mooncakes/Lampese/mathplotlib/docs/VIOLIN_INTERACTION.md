# 小提琴图交互

`violinplot` 与预计算 `violin` 保持现有参数和静态 SVG，同时提供 body、均值、中位数、极值、范围线与分位线的 typed hover/click 信息。
统计直接来自原 `ViolinStats`，UI 不重新计算 KDE、均值或分位数。

```mbt nocheck
let fig = @mathplotlib.figure(width=640, height=360)
let stats = try! fig.violinplot(
  [[1.0, 2.0, 3.0, 4.0, 8.0]],
  points=17,
  showmeans=true,
  showmedians=true,
  quantiles=[[0.25, 0.75]],
  label="Distribution",
)
let frame = try! fig.to_drawing()
// 与 frame 同一快照的 hit_test / hit_test_client 结果交给 hit_info。
let hit = frame.hit_test(320.0, 180.0)
```

`HitKind::Violin` 对应可选 `HitInfo.violin`，类型由 facade 再导出为 `ViolinInfo` / `ViolinPart`。
`ViolinInfo` 只包含 `group_index`、`position`、`horizontal`、`mean`、`median`、`minimum`、`maximum` 和 `part`，没有可变数组。
`group_index` 是原 stats 数组中的零基组索引，空组不会压缩后面组的索引。series 根据原 artist 身份保留，与颜色无关。

`ViolinPart` 表示实际可见部件：

| 部件 | 元数据与 `HitInfo.value` |
| --- | --- |
| `Body(index, coordinate, density)` | 原 KDE 数组下标、原采样坐标和原始估计密度；value 是 coordinate |
| `Mean` / `Median` | 原均值 / 中位数 |
| `Minimum` / `Maximum` | 原最小值 / 最大值 |
| `Range` | 原 minimum..maximum 范围线；value 和 data 锚点使用 median，默认提示显示完整范围 |
| `Quantile(index, value)` | 原 quantiles 数组下标和实际分位值 |

KDE 采样是估计密度上的采样点，**不是原始观测点**。density 是 `stats.vals()[index]`，
没有按最大密度归一化，也不是百分比或概率质量。body 的 coordinate 对应 `stats.coords()[index]`。
分位概率没有保存在既有 stats 中，因此默认提示使用分位序号和实际值，不猜测 Q25/Q75。
Range 的 median 是摘要锚点，不代表在鼠标处新增了观测或重新插值了统计值。

`HitPoint.point_index` 用固定语义槽区分可能完全重合的部位。每原组预留
`min(coords.length, vals.length) + 5 + quantiles.length` 个槽，再以前面所有原组的槽数为偏移。
前 n 个是 KDE 样本，接着是 Mean、Median、Minimum、Maximum、Range，最后为原顺序的 quantiles。
隐藏/缺失部件仍预留槽。请用 `ViolinInfo.group_index` 识别原组，使用 Body / Quantile 中的下标识别其原采样项；
不要把 point_index 当成组索引。一个样本可以有多个可见几何片段和锚点，均保留相同语义槽。

body 命中由同次实际 polygon 上下边界构建，沿 KDE 主方向按相邻原样本的屏幕中点分半，选择最近的真实 KDE 采样。
不使用外接矩形，不从颜色或宽度反推密度。非线性轴也在屏幕空间分半；中点边界归到后一个原样本。
横向图主方向为 X，竖向图为 Y。Both/Low/High 沿用源数据轴方向；反向轴不会把 Low/High 改成固定屏幕方向。

summary 和可见 body 轮廓复用真实线段，按 CSS 像素半径判断，并可以伸出局部 body。
后画的统计线在实际命中处可以覆盖先画的 body、柱或其他填充区域；后画的区域仍遮住先画的统计线。
Violin 重合部件以实际后画的部位打破等距离命中；不同部位的独立槽保证 `hit_test → hit_info → tooltip` 不串信息。
不在 body 外增加全图 KDE 吸附，现有折线/误差棒 XNearest 原中心语义保持。

默认 Rabbita 提示显示 Group、Mean、Median、Range；body 另显示 KDE coordinate / Density，分位线另显示序号和实际值。
现有自定义 `tooltip` 回调可直接读上述只读元数据；`violin=None` 的手工输入安全退回 Value。

边界规则：

- raw NaN/Inf 仍由既有统计计算过滤；全空或全非有限组没有 body 或 NaN 摘要命中，原组索引保留。
- 常量组的 KDE 坐标原本就展开到原值 ±0.5，通常仍有 body 面积。零长度 Range 不产生虚假点。
- 公共 width/widths 非正值仍按原 API 报错。零宽描边不留线段命中，可见填充独立保留。
- facecolor、linecolor、fill-opacity 分别决定可见 body、轮廓和 summary；已知完全透明样式不产生幽灵目标。
  未识别的 CSS paint 继续按现有统计图的保守规则处理。
- 原 renderer 要求 body 的所有上下顶点均在两轴有效域内，否则整个 body 不写出。交互保留这个限制，不擅自补画局部 polygon。
  各个合法 summary 仍独立保留；例如 Logit 上常量 0.5 的 KDE 端点为 0/1，body 不画，但合法的 0.5 摘要可画。
- 非单调、重复主坐标或非法的预计算 body 不建立误导性区域目标，静态输出保留，实际合法 summary 仍可交互。
- 面板裁剪、图例排除、多图、CSS 缩放、letterbox 和重建沿用 Drawing 规则；旧 Drawing 的统计标量不随后续输入修改。

新增枚举变体后，穷尽匹配 `HitKind` 的调用方需要增加 `Violin` 分支。
