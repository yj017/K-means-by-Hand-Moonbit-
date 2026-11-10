# 误差棒交互

已有 `Figure::errorbar` 与 `Axes::errorbar` 现在同时提供中心、实际误差线和端帽的
hover/click。数据输入仍是原有的对称 `xerr` / `yerr` 数组，没有新增配置要求。

```moonbit
let fig = @mathplotlib.figure(width=640, height=360)
fig.errorbar(
  [1.0, 2.0, 3.0],
  [4.0, 6.0, 5.0],
  xerr=[0.2, 0.1, 0.3],
  yerr=[1.0, 0.5, 0.8],
  label="Measured",
)
let frame = fig.to_drawing()
```

命中误差线或端帽返回原始采样点的同一个 `HitPoint`，其 `point_index`、
`data_x`、`data_y` 不会变成生成端点的序号或坐标。对应 `HitInfo` 包含：

- `kind = ErrorBar`，`series` 为原系列名，`value` 为原样本的 y 值。
- `error : ErrorInfo?`，实际误差棒采样点为 `Some`。
- `ErrorInfo.x_range` 为 `(x - xerr, x + xerr)`，`y_range` 同理。

未提供的方向与零误差均返回退化范围，例如 `(x, x)`。它们没有额外误差线，
仍可命中原中心。非有限样本跳过，后续点保留原始下标。
误差数值必须有限且非负，非空数组长度必须与样本数相同；对有限样本计算出的
范围若溢出，附加图形之前抛出 `DataError::InvalidErrorBar`。

`HitInfo`、`ErrorInfo` 与命中几何均是只读值，Drawing 不暴露可变几何数组。
旧帧保留当时的原值和范围。清空对应 Axes 后重建系列，新帧提示会读取新范围；
即便样本中心没有移动，也不会继续使用旧帧的误差数据。

Rabbita 默认浮层显示系列、x/y 和两个误差范围。已有 `tooltip` 回调可读取
`info.error`，自行格式化单位、上下界或中文标签；`tooltip_visible` 与样式设置继续适用。

`Nearest` 按中心或误差线的最近距离命中；线段先裁剪到当前面板，距离半径使用
`hit_radius` 指定的 CSS 像素。缩放、letterbox 和图例遮挡使用现有规则。
`XNearest` 把误差棒与折线同等处理，按真实样本中心的横轴位置选择；
误差端点不参与横轴吸附，也不会跨到另一个面板。附近的普通散点仍有既有优先级。

范围始终是原数据范围，不随反向轴、视口裁剪或非线性变换改变。非线性绘制沿用
已有规则：某方向两端都处于轴的有效域内时才画该方向的误差线；
未绘制的线段没有命中目标。中心在视口外但误差线进入视口时，可命中可见部分；
返回的 `screen_x/y` 仍指向真实样本中心。

公开 `HitShape` 新增 `Segment(x0, y0, x1, y1)`，端点为 SVG 内在坐标，
命中时使用有限线段投影，包含端点，退化线段按单点处理。
调用方若穷尽匹配 `HitKind` / `HitShape`，请补上 `ErrorBar` / `Segment` 分支。
旧图类、旧 `HitPoint` 与 `Interaction` 形状保持不变，`HitInfo.error` 默认为 `None`。

## 与填充图叠加

后画的误差中心、臂或端帽在实际命中半径内，可以覆盖下层柱或置信带的提示；
后画的填充区域仍遮挡底层误差棒。没有命中上层统计几何的位置继续读取区域本身。
`XNearest` 的真实几何命中只激活对应误差系列，最终仍按该系列原采样中心的 x 选择，
不会把长横臂的最近端点当成样本。图例遮挡、面板边界与 CSS 像素半径仍适用。
