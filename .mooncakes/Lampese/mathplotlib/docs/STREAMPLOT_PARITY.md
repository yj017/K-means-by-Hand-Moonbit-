# streamplot 兼容性核对

上游基线是 Matplotlib v3.11.2 的 `lib/matplotlib/streamplot.py`。

当前实现已经完成这一轮的输入和轨迹控制切片：

| 项目 | 当前行为 | 验证 |
| --- | --- | --- |
| 网格 | x/y 严格递增且等间距，允许浮点误差 | `scene/streamplot_test.mbt` |
| 二维坐标 | `streamplot_mesh` 接受 meshgrid 风格 x/y，并验证 x 行、y 列一致 | `streamplot_mesh accepts...` |
| 起点 | `start_points` 非空时只从显式起点积分，并拒绝越界/非有限点 | `streamplot honors explicit seeds...` |
| 方向 | `both`、`forward`、`backward` | 同一测试文件 |
| 长度 | `minlength` 过滤；`maxlength` 限制归一化弧长 | 同一测试文件及参数校验 |
| 断裂 | `broken_streamlines` 在积分过程中逐点更新最近遮罩单元；过短轨迹会回滚占用，起点按边界优先螺旋顺序尝试 | `streamplot broken_streamlines...`、`reserves mask cells...` |
| density | 标量 density 映射到 `30*density`；`density_x`/`density_y` 可独立控制两个方向 | `streamplot density uses...`、`accepts independent density axes` |
| 箭头 | `num_arrows` 按累计弧长分段定位，箭头尺寸按显示空间换算，支持常用 `FancyArrowPatch` 样式（空心/实心单双向、括号、端帽和 `fancy`/`simple`/`wedge` 命名样式） | `streamplot places one arrow...`、`common FancyArrowPatch arrow styles` |
| 样式 | `streamplot_with_style_grids` 支持网格 linewidth/color，颜色经过 cmap 和线性 norm 映射 | `streamplot maps grid-valued linewidth and color` |
| 返回值 | `StreamplotSet` 暴露生成的 line/arrow artists | `streamplot returns artists...` |
| 积分控制 | 自适应一阶/二阶 Heun 步长，支持最大步长和误差缩放 | `streamplot validates...` 及运行时轨迹测试 |

仍需继续迁移的上游语义：非线性坐标变换和完整 FancyArrowPatch 路径参数（连接器、曲线控制点和样式参数字符串）。当前 `max_steps` 是 MoonBit 侧积分上限参数；箭头尺寸已按显示空间换算，命名样式使用场景图元可表达的显示空间近似。

验证记录：本轮已恢复工具链，`moon check --target all` 和 wasm 测试通过；收尾仍需依次执行 `moon info`、`moon fmt`、全目标检查和全目标测试。
