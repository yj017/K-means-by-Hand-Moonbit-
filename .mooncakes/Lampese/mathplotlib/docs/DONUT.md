# 环形图

`Figure::donut` 与 `Axes::donut` 接收原始值，返回每片的占比。它们复用饼图的分类、颜色循环和交互提示。

```moonbit
let fig = @mathplotlib.figure(width=480, height=320)
let fractions = try! fig.donut(
  [12.0, 8.0, 5.0],
  labels=["开发", "设计", "其他"],
  colors=["#407da0", "#e2634e", "#88a878"],
  start_angle=90.0,
  inner_radius=0.55,
)
let drawing = try! fig.to_drawing()
```

`inner_radius` 是内半径与外半径之比，默认 `0.55`，合法范围为有限的 `[0, 1)`。
`0` 画实心饼；越接近 `1`，圆环越薄。角度以度为单位，从正 X 方向逆时针增加。
空数组、负值、非有限值、零总和、总和溢出、标签/颜色长度不匹配和非法半径通过 `DataError::InvalidPie` 报错。

SVG 使用真实的内外弧，中心孔会透出下方已经绘制的图形。单片完整圆环也保留孔。
Figure 本身仍有白色画布背景；要展示孔的透明性，可以先画有色背景区域，再画圆环。
旧的 `pie` 调用及其 SVG 不变。

命中范围是同次绘制生成的环扇区。内外圆周和扇区边界可命中，孔内和外圆外不命中；
相邻扇区共边时，后绘制的扇区优先。零值切片不画也不命中，其他切片保留原始数组索引。
`clear()` 后重建图形会生成新一帧；已保存的 Drawing 仍是原来的不可变快照。

Rabbita 默认提示直接显示分类、原始值和占比。`HitKind` 与 `ContainerKind` 都保持 `Pie`，
调用方已有的饼图提示格式器可以复用。自定义提示仍通过 `view(..., tooltip=info => ...)` 访问元数据。

新增 `Artist::Donut(values, labels, colors, start_angle, inner_radius)` 与
`HitShape::AnnularSector(cx, cy, inner, outer, start, sweep)` 变体；对这些枚举做穷尽匹配的代码需要补分支。
`AnnularSector` 的半径是绘图坐标中的绝对长度，角度遵循数学逆时针方向，屏幕 Y 方向相反。

```moonbit
match target.shape {
  AnnularSector(cx, cy, inner, outer, start, sweep) => {
    // inner/outer 是此次绘制的真实半径；sweep >= 360 表示完整圆环。
    // 分类、值和占比请读取 target.info。
  }
  _ => ()
}
```
