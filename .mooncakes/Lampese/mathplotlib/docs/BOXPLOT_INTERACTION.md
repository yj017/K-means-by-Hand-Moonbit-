# 箱线图交互

`Figure::boxplot` / `Axes::boxplot` 保留已有绘图入口、Tukey 统计规则与静态 SVG。
导出 `to_drawing()` 后，箱体、须、端帽和离群点都具有对应的交互元数据；横向与纵向使用同一组统计值。

```moonbit
let fig = @mathplotlib.figure(width=480, height=320)
let stats = fig.boxplot(
  [[1.0, 2.0, 3.0, 4.0, 5.0, 20.0], [2.0, 3.0, 4.0]],
  label="延迟",
)
let drawing = fig.to_drawing()
```

命中结果的 `HitKind` 是 `BoxPlot`，`HitInfo.box` 提供只读 `BoxInfo`：

- `group_index`：本次 `boxplot` 输入的原始零基组索引，尺度筛选不会重新编号。
- `q1`、`median`、`q3`：下四分位数、中位数、上四分位数。
- `lower_whisker`、`upper_whisker`：实际须端点，未被当前视图截断。
- `part`：`Box`、`LowerWhisker`、`UpperWhisker`、`LowerCap`、`UpperCap` 或 `Outlier(value)`。

`HitPoint.point_index` 同样保留原始组索引；多个部件可属于同一组。
`Outlier(value)` 携带真实离群值，且 `HitInfo.value` 为该离群值；箱体的 `value` 为中位数，须与端帽为相应须端点。
统计数据在绘图时取自已有 `BoxStats`，Drawing 只保存标量，不引用输入数组或离群点数组。

箱体整个可见矩形可悬停和点击。须与端帽复用线段距离命中，离群点复用点距离命中；
距离容差以调用方的 CSS 像素为单位。被面板裁掉的线段不产生视图外的吸附范围，
离群点中心须位于当前面板中。图例覆盖、留白、CSS 缩放和多图状态遵循统一规则。
非线性轴沿用现有绘制筛选：Q1 或 Q3 不在尺度合法域时，整组不绘制也不命中。
须、端帽和离群点只为实际绘制的有限几何生成命中，不推算未显示的部件。
零高度的常量箱通过实际绘制的中位数线交互；零长度的须不产生虚构命中区域。
箱体面积优先于同位置的线段；完全重合的常量组部件可显示同一组统计。

Rabbita 默认提示显示从 1 开始的组号、中位数、Q1、Q3 和须范围，命中离群点时再显示离群值。
调用方可通过现有 `tooltip` 回调把 `group_index` 映射到中文组名、添加单位或调整格式：

```moonbit
// 在现有 view(..., tooltip=info => ...) 回调内：
if info.box is Some(summary) {
  // summary.median 已是本帧统计结果，界面不需要再计算分位数。
}
```

同色系列通过真实 artist 身份保留 `label`。清空并重建 Axes 后，新 Drawing 读取新统计；
已经保存的旧 Drawing 仍是独立快照。

新增 `HitKind::BoxPlot`、`BoxInfo`、`BoxPart` 与 `HitInfo.box`；
调用方若穷尽匹配 `HitKind`，需要增加箱线分支。`BoxPart::Outlier` 的参数是原始数值。

后画在填充区域上的须、端帽与离群点，仍可按真实几何读取对应箱线组及部位；
后画的填充区域保持对底层箱线的遮挡。零距离共享边界沿用实际目标顺序。
