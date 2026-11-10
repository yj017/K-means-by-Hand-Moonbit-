# Detailed usage and implementation notes

This document preserves detailed API examples and source compatibility notes.
Start with the [project README](../README.md) for the current plotting workflow.
Current module: `Lampese/mathplotlib@0.2.1`; install and publication status are in
[the integration guide](PUBLISHING.md). The default plotting alias remains `@mathplotlib`.

## Drawing 快照与 Rabbita 组件

`let drawing = figure.to_drawing()` 在现有 checked 渲染中一起准备 SVG、画布尺寸和数据点命中坐标。
`drawing.svg()` 是对应静态输出，`drawing.points()` 返回独立数组；修改图表后重新准备快照。
根包导出 `Drawing` / `HitPoint`，快照与纯命中计算包为 `Lampese/mathplotlib/drawing`，不依赖 DOM。

同一 module 的 JS 子包 `Lampese/mathplotlib/rabbita`（别名 `@plot_dom`）提供
`@plot_dom.view(drawing, id=..., on_event=...)`，返回 Rabbita `Html`，
应用处理 `Hover`、`Click`、`ToggleSeries` 并管理状态。当前索引属于该帧，不是跨数据重排的持久 ID。
完整可运行示例、导入与限制见 [adapter 指南](../rabbita/README.md)，
验证范围见 [DOM 验收](RABBITA_DOM.md)。

## 图例位置与单方向网格

```moonbit nocheck
let fig = @mathplotlib.figure()
fig.plot([0.0, 1.0], [1.0, 2.0], label="Series A")
fig.set_legend_position(@mathplotlib.LegendPosition::LowerLeft)
fig.grid(axis="y")
let svg = fig.to_svg_checked()
```

四角为 `UpperRight`（默认）、`UpperLeft`、`LowerRight`、`LowerLeft`；
每个 `Axes` 均有同名 getter/setter。完整 `clear()` 恢复默认位置，
`clear_legend()` 沿用恢复自动条目的行为并保留位置。
`grid(axis="x"/"y")` 可在默认模式下选择方向；显式 `which="major"/"minor"` 仍可用。
实际多图示例见 [`cmd/gallery`](../cmd/gallery/main.mbt)，验收范围见 [M1](MILESTONE_M1.md)。


# MoonPlot

MoonPlot is a MoonBit plotting library inspired by Matplotlib v3.11.2. It keeps
numeric data in `core`, figure and artist state in
`scene`, and SVG encoding in `backend/svg`. The SVG backend uses the pinned
`Milky2018/xml@0.5.0` dependency; XML types do not cross into the public
plotting API.

```moonbit nocheck
let fig = @mathplotlib.figure(width=640, height=400)
fig.set_title("A MoonBit plot")
fig.set_x_label("time")
fig.set_y_label("value")
fig.plot([0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 0.5, 2.0])
fig.scatter([
  @mathplotlib.point(0.0, 0.0),
  @mathplotlib.point(1.0, 1.0),
])
let svg = fig.to_svg()
```

Figure 可以把父 `GridSpec` 的一个跨度交给 `SubFigure`，再在这个区域内创建独立的
嵌套网格。`SubFigure` 句柄通过共享数据保留 Axes 状态，因此从
`Figure::subfigures()` 重新取得的句柄仍能读取同一组 Axes；父网格比例变化也会实时
反映到子区域矩形。

```moonbit nocheck
let fig = @scene.figure(width=480, height=320)
let outer = try! fig.grid_spec(1, 2, width_ratios=[1.0, 2.0])
let subfig = fig.add_subfigure(try! outer.cell_spec(0, 1))
let axes = try! subfig.subplots(2, 1)
axes[0].plot([0.0, 1.0], [0.0, 1.0])
axes[1].scatter([@core.point(0.5, 0.5)])
subfig.suptitle("Nested panels")
let svg = fig.to_svg()
```

几何基础位于独立的 `transforms` 包。BBox 可以做范围运算并应用仿射变换，Path 和 BezierSegment 为后续 patch、clip 和 SVG 曲线提供统一数据模型。Path 的二次/三次曲线会参与精确包围盒计算，点包含测试会按曲线展开为稳定的折线近似；`clip_to_bbox` 会按矩形内外半平面裁剪闭合路径。

```moonbit nocheck
///|
let box = @transforms.bbox_from_bounds(0.0, 0.0, 2.0, 1.0)

///|
let moved = box.transformed(@transforms.translation(3.0, 4.0))

///|
let curve = try! @transforms.cubic_bezier(
  @mathplotlib.point(0.0, 0.0),
  @mathplotlib.point(0.0, 1.0),
  @mathplotlib.point(1.0, 1.0),
  @mathplotlib.point(1.0, 0.0),
)

///|
let samples = try! curve.sample(16)

///|
let data_to_display = @transforms.bbox_transform(
  @transforms.bbox(0.0, 0.0, 10.0, 5.0),
  @transforms.bbox(40.0, 20.0, 440.0, 220.0),
)

///|
let display_point = data_to_display.apply(@mathplotlib.point(5.0, 2.5))
```

日期可以按 Matplotlib 的日序自动格式化，也可以使用显式格式：

```moonbit nocheck
let dates = [
  try! @date.datetime(2024, 1, 1),
  try! @date.datetime(2024, 1, 2),
]
let fig = @mathplotlib.figure(width=420, height=260)
try! fig.plot_date(dates, [1.0, 2.0])
let svg = fig.to_svg()
```

日期值可以携带固定 UTC offset；数值日序仍表示同一个 UTC instant，标签按轴的
offset 展开。也可以直接给 formatter 设定 offset：

```moonbit nocheck
let local = try! @date.datetime(1970, 1, 1, hour=5, offset_minutes=345)
let formatter = try! @date.date_formatter("%H:%M %z %Z").with_offset(345)
let label = formatter.format_value(local.to_ordinal())
try! fig.set_x_date_offset(345)
```

首次 `plot_date` 会从输入日期保留的规则时区或固定 offset 初始化日期轴；后续序列会保留已经
配置的 offset、locator、format 和固定 ticks。需要状态式入口时，可以使用
`@pyplot.xaxis_date_offset` 或 `@pyplot.yaxis_date_offset`。

也可以把显式日历定位器接到对象式或 pyplot API。定位器返回的仍是
Matplotlib 日序，因此可以和普通数值绘图共用范围和 SVG 刻度链路：

```moonbit nocheck
let locator = try! @date.month_locator_on(3)
try! fig.set_x_date_locator(locator)
```

`@date.year_locator`、`@date.month_locator`、`@date.weekday_locator`、
`@date.day_locator`、`@date.hour_locator`、`@date.minute_locator`、
`@date.second_locator` 和 `@date.microsecond_locator` 分别覆盖年、月、
星期、日、时、分、秒和微秒粒度；
`@date.nth_weekday_locator` 可定位每月第 N 个星期几（支持正负序号和月份筛选）；
星期定位器使用 Monday=0 到 Sunday=6，默认值与 Matplotlib 一样是 Tuesday；
`@pyplot.xaxis_date_locator` 与 `@pyplot.yaxis_date_locator` 提供状态式入口。

主网格线默认关闭，和 Matplotlib 的 `axes.grid=False` 一致；可以按两个轴分别开启，
并设置颜色和线宽：

```moonbit nocheck
try! fig.axes().grid(which="both", color="#d1d5db", linewidth=0.8)
```

`Axes::set_axis_off` 或 `@pyplot.axis(mode="off")` 可以隐藏边框、刻度、标签、网格和
次坐标轴而保留图元；`mode="on"` 恢复这些装饰。

基础绘图入口默认使用 Matplotlib 的 tab10 属性颜色循环。连续调用 `plot`、`scatter`、
`bar` 或 `barh` 会按当前 axes 取下一种颜色；显式传入 `color` 会覆盖该次绘图，并保留
下一次自动颜色的位置。可以在对象式或 pyplot API 中替换循环：

```moonbit nocheck
try! fig.axes().set_color_cycle(["#264653", "#e76f51"])
fig.plot([0.0, 1.0], [0.0, 1.0])
try! fig.axes().set_margins(0.0, 0.1)
```

`Axes::set_prop_cycle`、`Figure::set_prop_cycle` 和 `@pyplot.set_prop_cycle` 是同一组
颜色循环设置的 Matplotlib 命名入口。

同一循环也覆盖单色的参考线和跨度、`annotate`/`arrow`、`spy`、规则网格 `contour`、
三角网格 `triplot`/`tricontour`、`streamplot`、`violinplot` 与 `quiverkey`。一个调用产生
的多个线段或面共享同一循环颜色；传入显式 `color` 后不会消耗下一项。

自动范围的边距默认是 x/y 各 5%，可以通过 `set_margins`、`set_x_margin` 和
`set_y_margin` 调整；显式 `set_xlim`/`set_ylim` 默认关闭对应的自动缩放。对数轴在变换后
跨度上应用边距。边距拒绝小于等于 `-0.5` 的值，上游允许的 NaN 和正无穷会使 padding
归零。`axes.autoscale()` 重新开启选中轴的自动缩放，请求在下次读取时更新视窗；没有数据
且当前视窗已变更时保留旧视窗。`enable=Some(false)` 关闭自动缩放，`enable=None` 保留两个
开关并请求双方向更新。`autoscale(tight=true)` 会把选中轴的边距设为零。

`autoscale_view(tight=true)` 立即计算已开启自动缩放的方向，保留 margin，并跳过 locator
的外扩策略。省略 `tight` 会沿用该 Axes 上次设置的值。`get_xlim_checked()` 和
`get_ylim_checked()` 解析待更新的视窗并保留错误；原 `get_xlim()`/`get_ylim()` 仍返回
Option，但正常读取返回实际视窗。`x_limits()`/`y_limits()` 保留固定范围的便利查询合同。
数据范围保存在独立缓存中；修改已有图元数据后用 `relim()` 重算，再按需调用
`autoscale_view()`。数值范围链已通过四目标验收，具体范围见
[autoscale 说明](../testdata/autoscale_README.md)。

新建 Figure/Axes 读取 `@config` 包中的全局默认值。可以只改变后续新对象的颜色循环、
自动范围边距和主网格默认样式，并用 `@config.reset()` 恢复：

```moonbit nocheck
try! @config.set_color_cycle(["#264653", "#e76f51"])
try! @config.set_x_margin(0.0)
try! @config.set_grid(true, "#d1d5db", 0.8)
let fig = @scene.figure()
@config.reset()
```

Axes 的四条边框通过 `spine` 对象独立控制。`axes.spine(@scene.SpineSide::Left)`
和 `axes.spines()` 可以读取或设置某条边框的可见性、颜色和线宽，SVG 会按 side 保持
这些设置；`SpinePosition::Data`、`SpinePosition::Outward` 和 `set_bounds` 可进一步
调整边框位置和绘制区间。

复合绘图调用产生的图元可以通过 `axes.containers()` 查看。每个 `Container` 提供
`kind()`、`label()` 和 `artists()`；`Figure::containers()` 转发默认 axes 的分组，
`Axes::clear()` 会同时清空这些分组。条形图、误差条、箱线图、stem、等值线、quiver、
violin、pie 和 streamplot 都会保留调用顺序与生成的图元快照：

```moonbit nocheck
let fig = @scene.figure()
try! fig.errorbar([0.0], [1.0], yerr=[0.1], label="measurement")
let groups = fig.containers()
assert_eq(groups.length(), 1)
assert_eq(groups[0].label(), "measurement")
```

月、星期、日、时、分和秒定位器也接受非空数组筛选器；数组会复制、排序并去重，
所以调用方之后修改原数组不会改变定位器。负的 `bymonthday` 从月末计数，`-1`
表示月末；interval 先按日历单位步进，再应用筛选器：

```moonbit nocheck
let locator = try! @date.month_locator(
  bymonth=[2, 4],
  bymonthday=-1,
  interval=1,
)
try! fig.axes().set_x_date_format("%Y-%m-%d")
try! fig.set_x_date_locator(locator)
```

需要组合多个日历字段时，可以使用 `@date.rrule_locator`。它按
`Yearly`、`Monthly`、`Weekly`、`Daily`、`Hourly`、`Minutely` 和 `Secondly`
展开，并支持 `interval`、`wkst`、`bymonth`、正负 `bymonthday`、`byyearday`、
`byweekno`、相对西方复活节的 `byeaster`、`byweekday`、时分秒筛选和
`bysetpos`。筛选数组会在构造时复制、排序并去重；`bysetpos` 在每个日历周期完成
展开后应用：

```moonbit nocheck
let locator = try! @date.rrule_locator(
  @date.RRuleFrequency::Yearly,
  byweekno=[1, -1],
  byweekday=[0],
  byhour=[0],
  byminute=[0],
  bysecond=[0],
  dtstart=@date.datetime(2024, 1, 1),
  count=4,
)
try! fig.set_x_date_locator(locator)
```

需要直接查询 occurrence 时，可以用带明确 `dtstart` 的 `@date.rrule` 对象。它提供
`between`、`after`、`before`、`xafter` 和 `all`，`between` 默认使用开区间，传入 `inc=true`
后包含相等边界；`all` 和 locator 查询都限制为最多 100000 个结果：

```moonbit nocheck
///|
let rule = try! @date.rrule(
  @date.RRuleFrequency::Monthly,
  @date.datetime(2024, 1, 1),
  byweekday=[0, 1, 2, 3, 4],
  bysetpos=[-1],
  byhour=[9],
)

///|
let meetings = try! rule.between(
  @date.datetime(2024, 1, 1),
  @date.datetime(2024, 7, 1),
)
```

`dtstart`、`count` 和 `until` 可限制 recurrence 的起点、出现次数和包含式截止时间；
`count` 会计入可视范围之前已经发生的候选日期。未提供 `dtstart` 时，仍使用
Matplotlib 的可视窗口锚点。

日期数值时长可用 `num2timedelta(days)` 转为 `TimeDelta`，数组使用
`num2timedeltas(values)`。它按 Python 的 round-half-to-even 规则保留微秒，采用
规范化的天/秒/微秒分量，覆盖 `-999999999` 到 `999999999` 天，最大正值还可含
86399 秒和 999999 微秒。`days()`、`seconds()`、`microseconds()` 读取分量，
`total_seconds()` 返回浮点总秒数（很大时长的微秒细节应读取整数分量）。`timedelta(...)` 接受精确整数单位（days、weeks、
hours、minutes、seconds、milliseconds、microseconds），负分量会规范化；非有限日数
或时长范围溢出抛出 `DateError`。

```mbt nocheck
///|
let step = @date.timedelta(hours=4)

///|
let dates = @date.drange(
  @date.datetime(2011, 1, 1),
  @date.datetime(2011, 1, 2),
  step,
)

///|
let next = @date.datetime(2243, 10, 17, microsecond=123456).add_timedelta(step)
```

`drange` 返回可直接传入数值绘图或 fixed ticks 的日期日序数组，复现上游的
ceil → 精确日期末点调整 → linspace 顺序；常规正步长使用半开区间。
保留上游负步长和浮点 ceil 边界的实际结果（个别输入可能仍保留终点），不换成逐点
累加。它没有 locator 的 100000 条上限；零步长、日期中间溢出、负样本数或超出
MoonBit Int32 数组索引范围会抛出 `DateError`。

`with_timezone` / `zone.to_datetime` 返回的日期保留规则引用，可用 `timezone()`
读取；`with_offset` 清除规则引用。`add_timedelta` 按本地整数微秒相加并重新确定
offset，保留远期日期所有微秒位。规则算术按 dateutil 取 fold 的较早 instant、
gap 的变更后 offset；显式 `zone.to_ordinal` 仍拒绝 gap。`drange` 的墙钟末点计算
及首次 `plot_date` 的轴初始化都会使用保留的规则，后续系列继续保留已设置的轴配置。

`datestr2num(text)` 接入固定 dateutil 默认通用日期解析，`datestrs2num(texts)` 是扁平数组入口：
支持数字/英文月名、不同年月日顺序、紧凑日期、12h/AMPM、小数时间、星期及 UTC/数字/本地
时区标签。两位年份按 parser 构造时的当前本地年份解释为前 50 年至后 49 年；省略字段用
`default_date`，未给默认值时用当前本地日期的午夜。未显式给 day 时才回落至月末，显式
非法日期仍抛 `DateError`。原有 `parse_iso` 继续提供单独的 ISO 解析入口。

```mbt nocheck
///|
let context = @tzdb.parser_context("America/New_York")

///|
let parser = @date.DateStringParser::new(context~)

///|
let ticks = @date.datestrs2num(
  ["Nov 3 2024 1:30 EDT", "Nov 3 2024 1:30 EST"],
  parser~,
)

///|
figure.plot(ticks, [0.0, 1.0])

///|
figure.axes().set_x_date()

///|
figure.set_x_date_timezone(@tzdb.timezone("America/New_York"))
```

可直接使用宿主 `TZ` / `TZDIR` 或 `/etc/localtime`，也可注入
`DateParserContext::from_tzif`、`from_posix`、`utc` 或可选 `tzdb.parser_context(name)`。
context 的 `clock` 是返回 signed Unix 毫秒的回调；构造 context 不读 clock/epoch，
构造 parser 捕获本地年份和标准/夏令时描述符。默认描述符采用固定 CPython 采样规则，
`with_local_info(std_seconds, dst_seconds, [std_name, dst_name])` 可传入另一宿主的描述符。
规则仍负责实际本地日期和 DST 查询。无法读取宿主时区时会报错，需要提供显式 context。
基础 date 包不捆绑 IANA 数据；JS 文件入口使用 guarded Node builtin lookup，无静态
node:fs 导入，嵌入环境的 runtime 能力边界见[解析参考指南](../testdata/date_parser_README.md)。

`DateStringParser.parse` / `parse_many` 返回日期，`to_number` / `to_numbers` 执行数值转换；
free helper 也可传 `parser` 与 `default_date`。默认实例在首次非空 free 调用时惰性
创建，随后复用；需要提前捕获年份时可显式构造并传入 parser。`warnings()` 返回复制的
`DateParseWarning::UnknownTimezone(name)` 数组，包括晚些时候发生错误前的诊断。
未传 parser 的 free helper 可用 `date_parse_warnings()` 读取其默认实例的诊断；该 getter
不会创建 parser 或读取 clock/epoch。
`copy()` 隔离诊断状态，共享 clock 回调与不可变规则。已识别的宿主本地标签返回固定 offset
快照；继承自 `default_date` 的规则时区保留，绘图时可像上例明确设置显示时区。

无默认值的数组保留上游 NumPy 首项额外探测及整组先解析后转换的顺序；首项有时区时，
后续无时区项按实际宿主本地时间解释。有显式默认值则逐项解析、转换，错误发生时的
日期 epoch 锁定时机也保留。空数组不选择宿主 parser，也不锁 epoch。当前类型接口为
String / 扁平 Array[String]；Python stream/bytes、异构和多维/掩码 NumPy 容器尚未迁移。
默认 DateTime 沿用已有显式 offset 模型；fuzzy、parserinfo、tzinfos 不是上游
`datestr2num` 的参数。独立原对象和完整 helper 数值、clock、诊断参考见解析指南。

日期显示默认取 `@config.timezone()`（初值 `"UTC"`）。`set_timezone(name)` 储存名称，
`@date.get_timezone()`、`num2date`、普通 `date_formatter` 与 locator 在使用时解析；
构造器接受互斥的 `tz="..."` 或 `timezone=zone`。普通 formatter/locator 捕获已解析值，
Auto/Concise 的省略时区在生成文本时重新读取当前 rc；已有 locator 的刻度位置保持原时区。
`date_formatter` 与 `AutoDateFormatter::new` 现在具有 checked `DateError`；
提供显式 UTC/zone 可绕过无效默认。日期轴把构造错误映射为 `DataError`，原子保留旧配置。

```mbt nocheck
@config.set_timezone("XST-5:45")
let date = @date.num2date(0.0) // 1970-01-01 05:45
let utc = @date.num2date(0.0, tz="UTC")
let formatter = @date.date_formatter("%H:%M %Z", tz="XST-5:45")
@config.set_timezone("UTC")
```

名称查询支持调用方注册的 TZif、宿主文件与 GNU TZ 字符串。字符串按固定 dateutil
行为读取 TZif 的 **32 位兼容区块**；完整历史/未来规则继续用 `tzif_timezone` 或
`@tzdb.timezone(name)`，再传 `timezone=zone`。浏览器可调用
`@tzdb.register_timezone(name)` 显式接入某个名称，其余基础包仍不依赖整库。
`DateTime`/`date2num`/字符串 parser 不读取这个显示 rc；`from_ordinal`、
`format_date_ticks`、`auto_date_formatter`、`date_tick_values` 保持原 UTC helper 协议。
具体捕获时机、宿主能力和语法范围见 [日期时区说明](../testdata/timezone_README.md)。

`RelativeDelta::new` 和 `DateTime::add_relative_delta` 现已接入日历字段替换、相对年月日/
分数时间及 weekday nth。年月用 Int64，分数日期/时间用 Double；绝对字段和 weekday
索引用 Int32，`mo`～`su` 可通过 `with_nth` 指定第几个星期几。计算按源顺序夹紧月末，
再加墙钟时长、最后移动 weekday；保留现有时区 gap/fold 规则，与显示 rc/epoch 无关。
`normalized()` 以精确十进制半偶舍入级联日/时/分/秒/微秒；`RelativeDelta::between(first,
second)` 构造 first-second，按同一时区对象的墙钟与不同对象的实际时刻语义计算。
`add`/`subtract`、`add_timedelta`、`negated`/`abs`、`scaled`/`divided`、`with_weeks`、
`is_zero` 和 Eq 均已接入。绝对字段与 leapdays 采用源对象的左右优先级；乘除会独立
截断每个相对分量（包括乘以 1.0），Eq 比较保存的分量与有效 weekday occurrence。
`DateTime::sub_relative_delta` 保留绝对字段的替换含义。

这些 API 使用不可变 typed 对象；Int64 年/月、有限 Double 相对日期/时间与 Int32
绝对字段限定了数据范围。Python 任意精度整数、date-only/naive 动态混合、任意字段
突变、反射/序列化等对象协议仍待迁移。固定原源参考、舍入位形与重现命令见
[日历相对运算参考](../testdata/relative_delta_README.md)。

`RRuleWrapper::new`/`set` 已提供公开 rrulewrapper 的 typed 对应；用 `RRuleDateTime`
明确传入 naive/aware 日期，`byweekdays=[mo.with_nth(2)]` 表示每月第二个周一。
规则采用 naive recurrence 后附时区，保留上游 gap/fold、推断时区和失败后的部分状态；
旧 `RRule` 的 instant 查询与 skip-gap/双 fold 规则继续保留。`raw_iter()` 惰性产生底层
naive 日期，`after/before/between/xafter` 按有效时区返回结果。

`RRuleLocator::new(wrapper, tz="UTC").as_locator()` 可用于主/次日期坐标轴，并共享可变
wrapper；后续 `set(frequency=..., interval=...)` 会改变 tick 与自动标签单位。
直接 `tick_values(first, last)` 接收 RRuleDateTime，按 relativedelta 扩展并更新 wrapper。
显示时区和 wrapper base 独立，显式 `copy()` 可复制 wrapper 配置与空缓存。
`AutoDateLocator` 的 recurrence 分支也已接入这一实现，自动刻度遵循原 gap/fold0
行为；已解码的 bounds 直接传递，保留微秒 epoch 的转换顺序。旧显式定位器 helper
继续提供 skip-gap/双 fold 扩展，具体分支范围见 [自动日期参考](../testdata/auto_locator_README.md)。
Python 动态代理、pickle、pytz 适配及无上限 eager 容器未接入；具体生命周期、typed 边界、
原源参考与重现方式见 [wrapper/定位器说明](../testdata/rrule_wrapper_README.md)。

`YearLocator::new(base=5, month=7, day=4, tz="UTC")` 已提供命名年定位器；
`as_locator()` 可挂到日期轴并共享 `rule()` 返回的 wrapper。对齐按冻结 base 计算，
保留输入微秒，非法对齐年月日会抛错；旧 `year_locator()` 扩展继续保留。
wrapper 的 scalar 月/日用 `bymonth_value`/`bymonthday_value`，与原数组参数分开。
自动年倍数分支也已接入；`AutoDateLocator::new(context=...)` 可以为浏览器或测试
提供 host clock/context。原源参考与边界见 [YearLocator说明](../testdata/year_locator_README.md)。

`MonthLocator`、`WeekdayLocator`、`DayLocator`、`HourLocator`、`MinuteLocator` 和
`SecondLocator` 现已提供命名对象，可用 `as_locator()` 安装到主/次日期轴，或通过
`as_rrule_locator()` 使用共同查询入口。`WeekdayLocator` 默认周二；selector 数组用
原关键字，scalar 用 `_value`，对象用 `on_weekday`/`byweekdays`。
`null` 表示明确 None，`context` 注入 host clock。构造/更新会按上游拒绝不可达的同级
时钟 selector；原小写 helper 扩展继续保留。默认值、生命周期和参考见
[命名定位器说明](../testdata/named_locator_README.md)。

`MicrosecondLocator::new(interval=0.5, tz="UTC")` 支持分数微秒，直接查询接收
`RRuleDateTime`；`as_locator()` 可挂到日期主/次轴。`interval_value()` 返回准确间隔，
旧 `DateLocator.interval()` 对分数给整数投影；nonsingular 使用准确值。自动微秒分支
复用这个对象。邻接点、mixed awareness、年界/浮点精度及旧 helper 的区别见
[微秒定位器说明](../testdata/microsecond_locator_README.md)。

跨级时钟组合的迭代错误也已对齐：构造可成功，`after/before/between/xafter` 与
`occurrence_count()` 在实际读取时可能抛 `DateError`。`checked_raw_iter()` 返回
`RRuleDateIterator`，`next()` 可抛错并在错误后终止，保留更新前的 core/cache 快照。
`occurrence_count()` 现为 checked 方法，非 raising callback 需显式处理错误。
原 `raw_iter()` 保留不抛错的原生 Iter 扩展；错误边界、缓存和参考见
[递推迭代说明](../testdata/clock_iteration_README.md)。

日期数值默认以 `1970-01-01T00:00:00` 为原点。可以在首次数值转换或读取 epoch
之前选择其他原点，例如把原点移到 2400 年以保留附近日期的微秒精度：

```mbt nocheck
///|
fn main {
  @date.set_epoch("2400-01-01T00:00:00")
  let value = @date.datetime(2400, 1, 1, microsecond=123457)
  let number = @date.date2num(value)
  assert_eq(@date.num2date(number).microsecond(), 123457)
}
```

`get_epoch()` 会确定并锁定原点；`set_epoch()` 在原点已确定后抛出 `DateError`，
包括再次设置相同值。也可先通过 `@config.set_date_epoch(...)` 设置首次读取的
fallback；配置修改与 `@config.reset()` 都不会重置已确定的日期原点。
时区文件加载、规则构造和精确 `with_timezone` 转换不会确定原点。

epoch 接受 UTC ISO 年、年月或完整日期，完整日期可带 `T`/空格时间到微秒；
支持 signed Int32 天文年份（包括 `0000-12-31`、负年与 `+10000`）。日期对象仍
限制为年 1～9999。无效设置原子失败；不支持时区后缀、`NaT`、相对日期文字或
亚微秒格式，也不宣称覆盖 NumPy 的全部字符串语法。远离原点超过 70×365 天时，
反向数值转换按上游修正到最近的 20 微秒。上游对微秒 epoch 有一个保留的细节：
正向转换使用整秒原点，反向转换使用完整原点，所以二者可能不互为逆；通常选用
整秒原点。时区规则、墙钟算术与 recurrence 日期对象继续使用原来的绝对时刻。

当前日期值默认按 UTC Gregorian 解释，也支持固定 UTC offset、ISO 时区后缀、`%z`/`%Z`
格式和 SVG 日期标签 offset；同时支持微秒精度、ISO 小数秒（1～6 位）和 `%f` 六位微秒
格式。显式 transition 时区规则可用于 `DateTime` 转换、formatter 和 scene/pyplot/SVG
标签，transition 前后会使用不同的 offset；显式日历/时间 locator 会按本地候选映射
到 UTC，跳过 spring gap，并保留 fall fold 的两个 instant。`rrule_locator` 也可以通过
`DateLocator::with_timezone` 或 `RRule::with_timezone` 按显式 transition 表生成同样的
动态候选。`tzif_timezone(data : Bytes)` 现可加载调用方提供的 IANA TZif v2/v3 数据，
保留历史秒级 offset、时区缩写与 POSIX footer 未来规则；自动日期刻度、显式 locator、
`RRule` 和 scene/pyplot/SVG 共用这些规则。`%z` 在需要时输出秒（例如 `+000921`），
`%Z` 输出数据中的缩写（例如 `PMT`）。需要按名称查找时，可显式导入
`Lampese/mathplotlib/ticker/date/tzdb`：

```mbt nocheck
///|
let zone = @tzdb.timezone("Asia/Shanghai")

///|
let formatter = @date.date_formatter("%Y-%m-%d %H:%M %Z").with_timezone(zone)
```

`concise_date_formatter()` 根据整组刻度中变化的最小日期单位生成简洁标签，例如
`["Jan", "02", "03"]`，并把共同日期放在轴边缘的 offset 文本中。它通过已有日期轴
入口接入自动或显式 locator，x/y 轴、共享轴和 SVG 都可以使用：

```mbt nocheck
///|
let concise = @date.concise_date_formatter()

///|
let figure = @scene.figure(width=520, height=280)

///|
figure.plot_date([@date.datetime(2024, 1, 1), @date.datetime(2024, 1, 3)], [1.0, 2.0])

///|
figure.set_x_date_locator(@date.day_locator())

///|
figure.set_x_date_formatter(concise.as_formatter())
```

`Axes` / `Figure` 提供 `set_x_date_formatter`、`set_y_date_formatter`，`pyplot` 提供
`xaxis_date_formatter`、`yaxis_date_formatter`。同样可安装普通 `date_formatter(...)`。
`as_formatter()`、轴 setter 和 getter 都使用配置副本。显式 `set_*_date_format` 会替换
批量 formatter；手写 tick labels 优先，并抑制共享日期文本；清除日期模式也清除配置。

独立使用时，`concise.format_ticks(values)` 返回 labels，`get_offset()` 读取最近成功
批次的共同日期。空数组返回空 labels 并清空 offset；无效日期原子抛错。单值
`format_value` 默认只显示年份，可用 `with_default_format` 配置；`format_data_short`
返回完整的年月日时分秒。构造参数 `formats`、`zero_formats`、`offset_formats` 各有六项，
分别对应年、月、日、时、分、秒；空数组选默认值，非空数组长度不是六会报错。数组
输入和 getter 返回值都复制隔离，`show_offset=false` 只隐藏共同日期文本。

`with_offset` / `with_timezone` 配置 formatter 的标签时区，不改变 locator 的时区；
轴的 `set_date_offset` / `set_date_timezone` 则继续同时更新定位和标签。倒置轴按上游
选择共同日期的端点，微秒标签移除整组共同的尾零，配置支持此前接入的自定义 epoch。
`format_date` 支持标准 strftime 指令的固定 C locale 输出，月/星期名称与 AM/PM 为英文。
常用新增格式如下；这些规则同样用于普通、Auto、Concise formatter 和 converter 默认标签。

| 指令 | 含义与输出 |
| --- | --- |
| `%I` / `%p` | 十二小时制 01–12 / AM、PM |
| `%j` | 三位年内日序 001–366 |
| `%U` / `%W` | 周日/周一作为首周起点，首周之前为 00，最大 53 |
| `%u` | ISO 星期，周一 1 至周日 7 |
| `%G` / `%V` | ISO 周所属年份（四位）/周编号 01–53 |
| `%c` | C locale 完整日期时间，如 `Fri Jan  1 13:00:00 2021` |
| `%x` / `%X` | `%m/%d/%y` / `%H:%M:%S` |

例如 2021-01-01 的 `%Y-%m-%d` 是 `2021-01-01`，`%G-W%V-%u` 是 `2020-W53-5`。
周号和年日使用时区转换后的本地日期；UTC 跨日不会覆盖本地日历。四位年份、已有
`%f`/`%z`/`%Z` 与 `%%` 行为保留。未知指令、未支持的 flags/E/O/OS 扩展和末尾 `%`
按既有协议保留原文；任意系统 locale 尚未接入。参考逐值核对与完整 400 年周期验证见
[日期格式参考](../testdata/date_format_README.md)。`usetex=true` 或 `with_usetex(true)`
可返回上游 TeX 包装字符串；当前 SVG 文本层原样输出这些字符串，通用 TeX 排版尚未接入。

`AutoDateFormatter::new()` 则按 locator 的基础单位选择 `scaled` 中最小的、满足
`key >= unit` 的格式；没有匹配项时使用 `default_format`。基础单位不乘 interval，
例如每 30 分钟一次的 locator 仍使用 minute 格式。新建日期轴默认安装这个对象，
更换主/次 locator 或缩放自动日期范围后，格式会跟随实际 locator 的频率更新：

```mbt nocheck
///|
let locator = @date.minute_locator(byminute=[0, 30])

///|
let formatter = @date.AutoDateFormatter::new(locator~).with_scale(
  1.0 / 1440.0,
  @date.Text("%d %H:%M"),
)

///|
figure.set_x_date_locator(locator)

///|
figure.set_x_date_formatter(formatter.as_formatter())
```

可用 `with_scaled` 替换全部规则，也可用 `with_scale` 更新一项；字典键排序，重复键
取最后值，数组复制隔离。支持负值和无限阈值，拒绝不可排序的 NaN 键。`with_locator`
用于独立对象更换 locator；`with_locator_unit` 支持自定义 locator，安装到轴后通常
无需手工调用，轴会以实际主/次 locator 覆盖最初绑定。没有单位元数据的数值 locator
按上游回退到 1 天。`DateLocator::unit_scale()` 可读取基础单位。原有
`auto_date_formatter(lower, upper)` 与 `format_date_ticks` 的范围 helper 保留兼容，
它们不代替这个按 locator 单位工作的命名对象。完整自动定位对象见下方。

`AutoDateLocator::new(minticks=5, interval_multiples=true)` 使用固定上游的七级频率、
各级最大刻度数和 interval 表，从年到微秒选择真实日历定位器：

```mbt nocheck
///|
let automatic = @date.AutoDateLocator::new(maxticks=@date.All(8)).with_intervals(
  @date.Hour,
  [3],
)

///|
figure.set_x_date_locator(automatic.as_locator())
```

`maxticks` 支持 `DateMaxTicks::All(count)`，或
`ByFrequency([(DateFrequency::Month, 6), (DateFrequency::Day, 9)])`，后者保留其他级别
的默认值。`with_minticks`、`with_maxticks`、`with_intervals` 返回独立副本；值必须为
正整数，interval 表不能为空，表的顺序保留。`with_interval_multiples` 只修改对齐开关，
保留已配置的表；构造时开关决定默认日表。`with_offset` / `with_timezone` 设置本地日历。

`get_locator(first, last)` 接收 DateTime，`get_locator_for_range(lower, upper)` 接收
数值日期并返回具体定位器；`tick_values` 输出数值刻度并保留范围方向。选择后可读取
`frequency`、`unit_scale`、`selected_interval` 与 `warnings`。`selected_interval` 是
自动表中选择的候选值；对齐模式下返回的 recurrence locator 可能以 interval=1 配合
selector 实现相同间隔。诊断使用 `AutoDateWarning::IntervalFallback` 和
`DistantMicroseconds`，每次选择替换，读取返回副本。极短范围不足 minticks 时，实际
使用微秒定位器，但频率状态保留上一次值，与上游一致。

`as_locator()` 与原 Auto 对象共享选择状态，因此独立
`AutoDateFormatter::new(locator=automatic.as_locator())` 会跟随后续选择读取单位。
`copy()` 隔离配置和状态；安装到 Axis 以及从 Axis getter 读取时均复制，避免不同轴
互相改变选择状态。新日期轴使用完整 Auto 对象，首次启用捕获
`@config.date_interval_multiples()`；用 `set_date_interval_multiples(false)` 可改变后续
日期轴的默认对齐。显式 `set_tick_count` 覆盖默认对象的各级最大刻度数。

`nonsingular` 单独处理自动范围：空/非有限范围使用 1970-01-01 至 1970-01-02，单点
范围向两边各扩展 730 天。SVG 在 margin 之前应用，显式单点 limits 也使用扩展后的
刻度范围；直接 `AutoDateLocator.tick_values` 不隐式扩展。实现复用既有 recurrence、
微秒、epoch 和 TZif 转换；gap 跳过、fold 保留两个 instant 的已验收扩展语义保留。
独立上游参考和复现方法见 [auto_locator_README](../testdata/auto_locator_README.md)。

`DateConverter::new(interval_multiples=true)` 复用数值转换与完整自动定位器，
`ConciseDateConverter::new(...).as_converter()` 选择 concise 默认标签，可配置
`formats`、`zero_formats`、`offset_formats`、`show_offset`。默认配置
`@config.set_date_converter("concise")` 或 `"auto"` 作用于随后启用的日期轴，
`default_date_converter()` 每次读取 rc；已启用的轴保留快照，`clear_date` 后重新捕获。

```mbt nocheck
///|
let converter = @date.ConciseDateConverter::new(show_offset=false).as_converter()

///|
figure.set_x_date_converter(converter)

///|
let info = converter.axisinfo(unit=@date.fixed_timezone_seconds(561))
```

`axisinfo(unit?)` 返回 `DateAxisInfo`，包含 `major_locator()`、`major_formatter()`、
空 `label()` 和 1970-01-01/02 的 `default_limits()` 日期值。构造不锁定 epoch。
同一个 info 的 locator/formatter getter 保留动态单位引用；`copy()` 同时复制定位器
并重新绑定格式器，隔离选择状态。`convert` 接收日期数组，`convert_value` 接收单值；
标签时区不改写转换后的 UTC instant。`default_units` 取首个日期的规则时区，或构造
精确到秒的固定 offset 时区，空数组返回 `None`；`default_unit` 是单值入口。

`Axes` / `Figure` 提供 `set_x_date_converter` / `set_y_date_converter`，`pyplot` 提供
`xaxis_date_converter` / `yaxis_date_converter`，共享轴会先统一校验再安装副本。
替换默认配置保留已有显式 locator、fixed ticks/labels 和时区；显式日期格式继续优先。
`plot_date` 复用已有转换配置；普通空输入不推断 converter，需要空日期轴时先显式调用
`Axes::set_x_date()`。后续序列保留已设置的单位和标签。

固定 v3.11.2 的 `ConciseDateConverter` 父类初始化会把 `interval_multiples` 重置为
`true`，这里保留该行为，包括 rc 切换路径；普通 `DateConverter` 尊重传入值。当前
输入为已有 `DateTime` 和扁平日期数组：该类型始终有 offset（含 UTC）。
`plot_date_units` 与 `update_x_date_units` / `update_y_date_units` 接收
`RRuleDateTime::naive` / `aware`，明确区分无时区日期和有时区 instant。NumPy datetime64、
掩码数组及任意动态 registry 仍属后续范围。六项格式数组复用 concise
formatter 的校验与空数组默认扩展。证据与边界见
[日期转换器参考](../testdata/date_converter_README.md)。

`DateScaleFormat::Func((Double, Int?) -> String)` 接收原始数值和位置；单值调用未给
位置时为 `None`，`format_ticks` 逐值传 `Some(index)`。回调负责自己的时区转换与 TeX
包装，formatter 不额外改写。需要原始数组调用时，`ValuesFunc` 配合 `format_array`，
`DatesFunc` 配合 `format_dates`，后者保留原日期对象的本地字段与 offset。输入形状不
匹配时，命名对象抛出 `DateError`；通用 `DateFormatter` adapter 保持已有的非抛错
数值回退协议。自动 formatter 的共享 offset 恒为空，查询它不会再次执行用户回调。

`@config.set_date_autoformatter("minute", "%d %H:%M")` 可修改新对象的默认格式，
`date_autoformatter(unit)` 读取一项，`date_autoformats()` 返回复制的七项列表。
单位名为 `year/month/day/hour/minute/second/microsecond`。对象和日期轴启用时会捕获
配置；后续配置修改或 reset 不改变已经建立的 formatter。

日期次刻度可通过 `set_x_minor_date_locator` / `set_x_minor_date_formatter`（y 同理）
接入 `Axes` / `Figure`，`pyplot` 对应 `xaxis_minor_date_locator` /
`xaxis_minor_date_formatter`。默认次刻度标签为空；安装 formatter 后会在 SVG 对应
侧显示，沿用共享轴标签可见性。主、次 formatter 分别跟随各自实际 locator，日期轴
也接受已有数值 locator。默认按视口跨度 × 1e-5 去掉与主刻度重合的日期次刻度，
可用 `Axis::set_minor_overlap_removal(false)` 关闭这一步；`clear_date` 会清除日期次
刻度设置。时区、DST、自定义 epoch 和 `usetex` 字符串接口与其他日期 formatter 共用。

该独立包捆绑 IANA **2026e** 标准发布数据的 598 个 Zone/Link 名称（包含
`US/Eastern`、`Asia/Calcutta`、`UTC` 等兼容别名）；`available_timezones()` 返回
新的字典序名称数组，`version()` 返回数据版本。名称精确区分大小写，未知名称
抛出 `DateError`。它使用编译期嵌入的 345 份去重 TZif（共 206817 字节），首次查找
时按需解析；不依赖系统时区目录、网络或 `TZ` 环境变量。`ticker/date` 和普通绘图
包不在生产代码中导入该数据包。返回的 zone 直接传入现有 `with_timezone`、
`set_x_date_timezone` 或 `pyplot.xaxis_date_timezone`，动态刻度和 SVG 共用同一规则。

生产数据范围、许可和更新步骤见 [tzdb](../ticker/date/tzdb/README.md)。

秒级固定 offset 可通过 `datetime(..., offset_seconds=561)`、
`from_ordinal(..., offset_seconds=561)`、`fixed_timezone_seconds(561)` 和
`timezone_transition_seconds` 构造；ISO 后缀也接受 `+HHMMSS` / `+HH:MM:SS`。
`DateTime::offset_seconds`、`DateTimeZone::initial_offset_seconds` 和
`DateTimeZone::offset_seconds_at` 返回精确秒数。旧分钟 accessor 对秒级历史值返回
向零截断的分钟投影，计算和标签使用完整秒数；`offset_seconds` 与非零
`offset_minutes` 不能同时提供。现有分钟级构造方式保持兼容。

TZif v1/v4、leap-second 表和绝对值达到一天的 offset 会抛出 `DateError`。
本库使用 Matplotlib/POSIX UTC 日序；空 footer 时沿用最后一个显式类型是兼容策略，
不是对缺失未来规则的推断。外部 TZif 数据的范围和更新由调用方负责；测试固定使用 IANA 2026e，
数据和复现步骤见 [testdata/tzif](../testdata/tzif/README.md)。
`RRule::replace` 已支持保留未指定字段、重新校验 selector，并通过
`clear=["bymonth", "byweekday"]` 这类显式列表清除已有 selector；更完整的工作日/节假日日历规则和其他日期对象语义仍在后续切片；当前已提供
`business_day_locator`，支持默认周一至周五、自定义 weekday mask、显式节假日日期、
interval 和固定 UTC offset，并接入 scene、pyplot 与 SVG。动态 recurrence 的
`dtstart`/`count`/`until` 基础边界和对象查询已经覆盖。无匹配
筛选器会回退到 locator 的输入端点，直接对象查询返回空数组，数组结果最多返回 100000 个
occurrence，非法或不可表示的日序返回空数组。

`rrule(..., cache=true)` 与 `rruleset(cache=true)` 可启用逐步增长的 occurrence
前缀缓存，默认关闭。`cache_enabled()` 返回开关；`replace(cache=...)` 可改变开关，
省略时保留。`replace`、`with_offset`、`with_timezone` 产生的新规则使用独立空缓存。

`iter()` 和 `iter_after(value, count=..., inc=true)` 返回 MoonBit 原生
`Iter[DateTime]`，支持 `next()`、`take()`、`map()` 与 `for`。每次调用有独立读取
位置，缓存读者共用已生成前缀；未消费前不生成 occurrence。示例（已导入日期包）：

```mbt nocheck
///|
let rule = @date.rrule(@date.Daily, @date.datetime(2024, 1, 1), cache=true)

///|
let first_three = rule.iter().take(3).to_array()

///|
let next_two = rule.iter_after(@date.datetime(2024, 2, 1), count=2).to_array()
```

lazy iterator 由真实 `count` / `until` 或受支持的日历边界终止，没有数组查询的
100000 条上限；数组 API 继续最多返回 100000 条。timezone gap/fold、UTC 排序和
count 计数共用现有生成链。缓存开启时会保留已消费前缀，因此长序列可选择关闭缓存。
`RRuleSet` 流式合并包含来源、按 UTC 微秒去重并应用排除，再计算输出上限，
不会先把每个来源截为 100000 条。集合的 `rrule/rdate/exrule/exdate` 会使后续查询
使用新缓存；已创建的 reader 保持创建时的来源快照。`locator()` 继续使用有界刻度
生成器，输出不因对象查询缓存开关而改变。


The stateful convenience layer lives in the separate `pyplot` package:

```moonbit nocheck
@pyplot.figure(width=640, height=400)
@pyplot.plot([0.0, 1.0, 2.0], [0.0, 1.0, 0.0])
@pyplot.title("A stateful plot")
let svg = @pyplot.render_svg()
```

对象式 API 同时提供常用的 Matplotlib 命名别名，例如 `set_xlim`、`set_xlabel`、
`get_title` 和 `get_subplotspec`；`pyplot.suptitle` 与 `pyplot.savefig`
分别对应当前 figure 标题和 SVG 字符串输出。

`Axes::get_position()` 返回以 Figure 左下角为原点的归一化矩形
`(left, bottom, width, height)`；`original=true` 读取分配位置，默认读取应用
auto/equal/numeric aspect 后的绘制位置。`rect()` 保留左上角原点的像素矩形语义。

```moonbit nocheck
let fig = @scene.figure(width=400, height=200)
let ax = try! fig.add_axes(0.0, 0.0, 1.0, 1.0)
try! ax.set_position(0.25, 0.25, 0.5, 0.5)
try! ax.set_xlim(0.0, 1.0)
try! ax.set_ylim(0.0, 1.0)
ax.set_aspect_equal()
let original = ax.get_position(original=true).unwrap() // width = 0.5
let active = ax.get_position().unwrap() // width = 0.25, height = 0.5
let svg = fig.to_svg()
```

`set_position` 的 `which` 支持 `"both"`（默认）、`"original"` 和 `"active"`；
active-only 值会在下一次读取或绘制时按 original/aspect 重新计算。
`reset_position()` 只将 active 恢复为 original，后续读取仍会应用 aspect。
手动定位保留 GridSpec 成员关系，下次 `subplots_adjust` 会恢复网格位置；独立
`add_axes` 的位置保持不变。零尺寸与越界坐标可用，负尺寸、非有限值与坐标溢出
会被原子拒绝。SubFigure 内的 Axes 暂用根 Figure 坐标；
自动布局仍待迁移。

`Axes::set_aspect(value)` 接受正有限数值，表示一个 y 数据单位显示为一个 x 数据单位
的多少倍；默认 box 模式通过缩小绘图矩形满足比例，默认居中，保留原始位置和数据范围。`get_aspect()`
返回 `None`（auto）或 `Some(value)`；`Some(1.0)` 对应 equal。
现有 `set_aspect_equal()`、`set_aspect_auto()` 入口仍可用。

```moonbit nocheck
let ax = try! @scene.figure(width=400, height=200).add_axes(0.25, 0.25, 0.5, 0.5)
try! ax.set_xlim(0.0, 1.0)
try! ax.set_ylim(0.0, 1.0)
try! ax.set_aspect(2.0) // 同一数据单位的 y 显示长度为 x 的两倍
let active = ax.get_position().unwrap() // width = 0.125, height = 0.5
```

默认仅更新该面板；`share=true` 更新其直接 x/y 共享组成员的并集，适用于 numeric、
equal 和 auto。比例使用经过轴尺度变换的范围，支持现有 log/symlog、自动范围边距和
图像 sticky edges。`Figure::set_aspect`/`get_aspect` 作用于首面板；pyplot 用
`gca().set_aspect(...)` 设置当前面板。图像入口的 `aspect` 参数仍接受 auto/equal，
绘图后可对 Axes 设置数值比例。

`Axes::set_anchor` 决定比例约束留下空余空间时，实际绘图区域如何定位。默认
`Anchor::Named("C")` 居中；`"SW"`/`"S"`/`"SE"`、`"W"`/`"E"` 和
`"NW"`/`"N"`/`"NE"` 对应九宫格方向。`Anchor::Fraction(x, y)` 使用左下角
原点，0 为左/下、1 为右/上，并允许 `[0, 1]` 之外的有限值。

```moonbit nocheck
let ax = try! @scene.figure(width=400, height=200).add_axes(0.25, 0.25, 0.5, 0.5)
try! ax.set_xlim(0.0, 1.0)
try! ax.set_ylim(0.0, 1.0)
try! ax.set_aspect(2.0, anchor=@scene.Anchor::Named("SW"))
let active = ax.get_position().unwrap() // left = 0.25, width = 0.125
try! ax.set_anchor(@scene.Anchor::Fraction(1.0, 0.5))
```

`get_anchor()` 保留 Named/Fraction 输入形式；这两种枚举分别映射 Matplotlib 的
字符串/坐标元组。`share=true` 将锚点同步到直接 x/y 共享组并集；省略 `set_aspect`
的 `anchor` 参数时保留原锚点。无效方向与非有限元组会在修改任何面板前被拒绝。
auto 模式下锚点保留但不改变位置；`clear`/`cla` 保留锚点，新 Axes 默认居中。
`Figure::set_anchor`/`get_anchor` 作用于首面板；pyplot 使用 `gca()` 的同一接口。

`Axes::set_adjustable("datalim")` 选择调整数据视图范围来满足比例，保留整个面板矩形；
`"box"` 则继续缩小活动框。也可在 `set_aspect(..., adjustable="datalim")` 中设置。
范围调整使用轴尺度变换后的坐标，保留正反方向，支持现有 log/symlog 与自动边距。

```moonbit nocheck
let fig = @scene.figure(width=400, height=200)
let ax = try! fig.add_axes(0.0, 0.0, 1.0, 1.0)
try! ax.plot([0.0, 1.0], [0.0, 1.0])
try! ax.set_xlim(0.0, 1.0)
try! ax.set_ylim(0.0, 1.0)
try! ax.set_aspect(1.0, adjustable="datalim")
try! ax.apply_aspect()
let x = ax.get_xlim().unwrap() // [-0.5, 1.5]，原始面板位置不变
let svg = try! fig.to_svg_checked()
```

`apply_aspect()`、活动位置读取和绘制会应用范围调整；`original=true` 不触发调整。
在 datalim 模式，`get_xlim`/`get_ylim` 返回已解析的实际视图；自动范围在增加数据或
调整 margin 后重新计算，显式范围也可能被比例约束覆盖。原有自动/显式缩放选择保持。
共享 x 时仅可改 y，共享 y 时仅可改 x；两轴都共享的 numeric datalim 设置在 setter 提前
原子拒绝。`share=true` 的 `set_aspect` 同时传播模式；原 `set_aspect_equal/auto`
便捷入口继续只切换比例。clear 保留 adjustable，新 Axes 默认 box。

`Figure::to_svg_checked()` 通过 `DataError` 报告无法表示的逆变换范围，所有 datalim
面板解析成功后才写回视图；`get_position()` 遇到解析失败返回 `None`。
原 `to_svg()` 保留非抛错便利签名，checked 绘制失败时会终止该调用。
pyplot 的 `axis(mode="equal")` 使用 datalim 并恢复 autoscale；通过 `gca()` 可直接
设置模式。固定范围覆盖不提供 Python 日志警告；twins 和自动布局仍待迁移。

`set_box_aspect(aspect=...)` 约束面板的物理高/宽比，独立于一个数据单位的显示比例。
数值须为正且有限；省略参数的 `set_box_aspect()` 对应上游 `None`，清除约束。
设置数值会将 adjustable 切换为 datalim，清除时保留当前模式；`clear`/`cla` 保留
物理框约束，新 Axes 默认无约束。`get_box_aspect()` 返回 `Some(ratio)` 或 `None`。

```moonbit nocheck
let fig = @scene.figure(width=400, height=200)
let ax = try! fig.add_axes(0.0, 0.0, 1.0, 1.0)
try! ax.set_box_aspect(aspect=1.0) // 200×200 像素，不是归一化矩形的宽高相等
let active = ax.get_position().unwrap() // left=0.25, width=0.5, height=1.0
try! ax.set_aspect(2.0) // 保持方框，再调整数据视图使 y 单位为 x 的两倍
try! ax.set_box_aspect() // 保留 datalim，随后按原始面板尺寸调整视图
```

auto 数据比例仅按 box aspect 和 anchor 缩小物理框，不修改范围，允许两轴共享；
设置 box aspect 不向普通共享面板传播。numeric datalim 先缩物理框，再调整范围，
继续遵守共享限制。手动切换至 box 模式时，numeric aspect 优先于保存的 box aspect；
auto 数据比例加物理约束配合 box 模式会通过 checked API 报无效组合。
`Figure::set_box_aspect`/`get_box_aspect` 作用于首面板，pyplot 使用 `gca()` 的同一接口。

`Axes::remove()`、`Figure::delaxes(ax)` 和 `SubFigure::delaxes(ax)` 可移除已有面板。
`axes_list()` 保留其余面板的创建顺序；移除后旧句柄的 `is_attached()` 为 false，
旧数据仍可读取，但不会再渲染或向存活共享轴传播设置。重复移除或传入其他容器的
句柄会抛出 `DataError::InvalidReference`，不改变已有状态。

`Figure::gca()` 返回当前面板，`Figure::sca(ax)` 更新该 Figure 的选择历史；
删除当前面板后恢复最近选择的存活面板。`Figure::axes()` 仍返回首面板。
删除最后一个面板会保留空 Figure；`axes_list()` 和 `to_svg()` 不创建替代面板，
下次 `axes()`、`gca()` 或 Figure 绘图便利调用会按当前 subplot bounds 创建新面板。

```moonbit nocheck
let fig = @scene.figure()
let panels = try! fig.subplots(1, 3)
ignore(try! fig.sca(panels[0]))
ignore(try! fig.sca(panels[1]))
try! panels[1].remove()
fig.gca().set_title("back to the first panel")
```

`pyplot.delaxes()` 默认删除当前面板；`pyplot.delaxes(ax=panel)` 删除指定面板，
即使它来自另一 Figure，也不切换当前 Figure。对象式选择和移除会同步影响 pyplot。
对象式 `Figure::subplots` 替换网格后，当前面板为最后创建的面板；
`pyplot.subplots`/`subplots_with_grid` 保留选中首面板的现有便利行为。
SubFigure 的 `delaxes` 仅接受该区域直接创建的面板；Figure 的入口也支持删除嵌套
面板。当前 colorbar 独立归属 Figure，删除 Axes 不会自动删除它。

独立的多面板场景可以通过 `subplots` 创建。返回的 `Axes` 各自保存图元、范围、标签和标题：

```moonbit nocheck
let (fig, axes) = try! @pyplot.subplots(rows=1, columns=2)
axes[0].plot([0.0, 1.0], [0.0, 1.0])
axes[0].set_title("left")
axes[1].imshow([[0.0, 1.0], [1.0, 0.0]], cmap="viridis")
let svg = fig.to_svg()
```

`GridSpec` 可以把共享轴约束写入布局结果。`Row` 让同一行共享坐标，`Column`
让同一列共享坐标，`All` 和 `None` 分别表示全部共享和不共享。`All`/按列共享时，
SVG 只在外侧行绘制主 x 刻度标签；`All`/按行共享时只在外侧列绘制主 y 刻度标签：

```moonbit nocheck
let grid = try! @gridspec.gridspec(2, 2).with_shared_axes(
  @gridspec.ShareMode::Row,
  @gridspec.ShareMode::Column,
)
let (fig, axes) = try! @pyplot.subplots_with_grid(grid)
try! axes[0].set_x_limits(10.0, 0.0)
try! axes[0].set_y_limits(5.0, -5.0)
let svg = fig.to_svg()
```

也可以为列和行设置相对尺寸，比例会被布局结果保留：

```moonbit nocheck
let (fig, axes) = try! @pyplot.subplots(
  rows=1,
  columns=2,
  width_ratios=[1.0, 3.0],
)
```

`SubplotSpec` 可以继续创建嵌套网格。父网格的比例更新会反映到子网格的位置：

```moonbit nocheck
let fig = @scene.figure(width=640, height=400)
let outer = try! fig.grid_spec(1, 2)
let inner = try! outer.cell_spec(0, 1).subgridspec(2, 1)
let top = fig.add_subplot(try! inner.cell_spec(0, 0))
let bottom = fig.add_subplot(try! inner.cell_spec(1, 0))
top.plot([0.0, 1.0], [0.0, 1.0])
bottom.plot([0.0, 1.0], [1.0, 0.0])
let svg = fig.to_svg()
```

`GridSpec::cell_spec` 和 `GridSpec::index` 分别提供显式的二维和行主序单元选择，
负索引从末尾计算；`SubplotSpec` 还提供首尾行列查询。

需要逐点控制散点样式时，可以使用 `scatter_collection`。颜色和大小数组支持空值、单值或
与点数相同的长度，大小按标记面积解释：

```moonbit nocheck
///|
let collection = try! @pyplot.scatter_collection(
  [0.0, 1.0],
  [1.0, 0.0],
  colors=["#1f77b4", "#d62728"],
  sizes=[16.0, 49.0],
)

///|
let svg = @pyplot.render_svg()
```

`core/colors` 提供内置和自定义分段色图；对象式图像 API 也可以直接接收色图对象：

```moonbit nocheck
let cmap = try! @colors.custom_colormap(
  "red-blue",
  [try! @colors.rgba(1.0, 0.0, 0.0), try! @colors.rgba(0.0, 0.0, 1.0)],
)
axes[1].imshow_with_colormap([[0.0, 1.0]], cmap, vmin=0.0, vmax=1.0)
```

图像颜色可以使用线性或对数规范化，规范化对象也可以直接复用于
colorbar：

```moonbit nocheck
let norm = @colors.log_color_norm(
  try! @colors.log_norm(vmin=1.0, vmax=100.0),
)
try! axes[1].imshow_with_norm([[1.0, 10.0, 100.0]], norm, cmap="viridis")
let bar = fig.colorbar(norm, try! @colors.colormap("viridis"))
bar.set_label("value")
```

需要在零点附近保持对称的色阶时，可以使用对称对数、双斜率或中心对称规范化；也可以
用幂律规范化强调低值或高值区间。它们都可以复用于图像、规则网格和 colorbar：

```moonbit nocheck
let symlog = @colors.symlog_color_norm(
  try! @colors.symlog_norm(1.0, vmin=-100.0, vmax=100.0),
)
let diverging = @colors.two_slope_color_norm(
  try! @colors.two_slope_norm(0.0, vmin=-4.0, vmax=10.0),
)
let centered = @colors.centered_color_norm(
  try! @colors.centered_norm(vcenter=0.0, halfrange=10.0),
)
let power = @colors.power_color_norm(
  try! @colors.power_norm(2.0, vmin=0.0, vmax=100.0),
)
try! axes[1].imshow_with_norm([[-100.0, 0.0, 100.0]], symlog, cmap="viridis")
let _symlog_bar = fig.colorbar(symlog, try! @colors.colormap("viridis"))
let _diverging_bar = fig.colorbar(diverging, try! @colors.colormap("gray"))
let _centered_bar = fig.colorbar(centered, try! @colors.colormap("gray"))
let _power_bar = fig.colorbar(power, try! @colors.colormap("gray"))
```

`imshow`、掩码图像和 pyplot 入口可以设置像素原点、数据坐标范围、轴纵横比和整幅图像透明度 `alpha`。全局透明度会与色图颜色或 RGBA 像素本身的透明度相乘。
`origin="upper"` 会把第一行放在图像上方，`origin="lower"` 会把它放在下方；
`extent` 按 `(left, right, bottom, top)` 给出图像范围：
边界可以反向以独立控制像素方向；图像加入后会立即贴合范围，后续自动缩放会恢复数据
范围并抑制图像边缘外侧的自动边距。

```moonbit nocheck
try! axes[1].imshow(
  [[0.0, 1.0], [1.0, 0.0]],
  origin="lower",
  extent=[10.0, 14.0, 20.0, 24.0],
  aspect="auto",
  alpha=0.7,
)
```

`interpolation` 支持大小写不敏感的 Matplotlib 过滤器：`"nearest"`、`"none"`、
`"bilinear"`、`"bicubic"`、`"spline16"`、`"spline36"`、`"hanning"`、`"hamming"`、
`"hermite"`、`"kaiser"`、`"quadric"`、`"catrom"`、`"gaussian"`、`"bessel"`、
`"mitchell"`、`"sinc"`、`"lanczos"`、`"blackman"`、`"auto"` 和 `"antialiased"`。
默认的 `"nearest"` 按 SVG 像素矩形绘制；在线性坐标轴上使用 `"none"` 时，SVG 会嵌入
原始分辨率的 RGBA PNG。其他过滤器在线性坐标轴上按中心对齐的预乘 alpha 核生成显示尺寸
PNG；`"auto"` 和 `"antialiased"` 按显示倍率在最近邻和 Hanning 之间选择。所有模式都
保留 `origin`、反向 `extent`、`alpha` 和图像裁剪，对数等非线性坐标轴会自动回退到像素矩形。
掩码图像、RGB/RGBA 图像和 pyplot 图像入口都转发这一参数：

```moonbit nocheck
try! axes[1].imshow(
  [[0.0, 1.0], [1.0, 0.0]],
  cmap="viridis",
  interpolation="none",
  aspect="auto",
)
```

RGB 和 RGBA 矩阵可以直接作为已经着色的图像传入。`Rgb` 通过
`@colors.rgb` 构造并默认使用不透明 alpha；`Rgba` 通过 `@colors.rgba` 构造，SVG
会保留每个像素的 alpha。需要从通道数组输入时，使用三通道或四通道入口；有限越界
通道会裁剪到 `[0, 1]`，NaN 和 Infinity 所在像素会变成透明像素。

```moonbit nocheck
let rgb_image = [
  [try! @colors.rgb(1.0, 0.0, 0.0), try! @colors.rgb(0.0, 1.0, 0.0)],
]
try! axes[1].imshow_rgb(rgb_image, aspect="auto")
try! axes[1].imshow_rgba_channels(
  [[[0.0, 0.0, 1.0, 0.5]]],
  aspect="auto",
)
```

掩码数据在 `core` 中保存原始值和独立布尔掩码。掩码值会从自动色阶中排除；折线和散点在掩码位置断开，`pcolor` 省略对应多边形，`pcolormesh` 和 `imshow` 可使用色图的 bad 色：

```mbt check
///|
test "masked image example" {
  let data = try! @mathplotlib.masked_matrix([[1.0, 1000.0, 2.0]], mask=[
    [false, true, false],
  ])
  let fig = @mathplotlib.figure(width=280, height=180)
  try! fig.imshow_masked(data, cmap="gray")
  let _svg = fig.to_svg()
  assert_true(_svg.contains("<svg"))
}
```

也可以显式配置 bad 色。统计图和 NumPy 广播尚未统一接受 `MaskedArray`；当前掩码入口集中在上述折线、散点、填充、图像和规则网格 API。

离散色阶可以由边界规范化和 `ListedColormap` 组合得到；图像 API 提供同时传入
两者的入口：

```moonbit nocheck
let discrete_norm = @colors.boundary_color_norm(
  try! @colors.boundary_norm([0.0, 1.0, 2.0], 2),
)
let discrete_cmap = try! @colors.listed_colormap(
  "status",
  [try! @colors.rgba(0.9, 0.2, 0.2), try! @colors.rgba(0.2, 0.8, 0.3)],
)
try! axes[1].imshow_with_norm_and_colormap(
  [[0.5, 1.5]],
  discrete_norm,
  discrete_cmap,
)
```

矩阵可以用 `matshow` 直接显示。它会使用零基行列索引，把第一行放在顶部，
并让两个数据轴保持等比例。它也接受上述全部 `interpolation` 名称；`"none"` 在线性
SVG 轴上嵌入原始分辨率 PNG，其他过滤器按上述规则生成过滤后的图像：

```moonbit nocheck
let matrix = try! @mathplotlib.figure(width=360, height=260)
try! matrix.matshow(
  [[0.0, 1.0, 2.0], [3.0, 4.0, 5.0]],
  interpolation="none",
)
let svg = matrix.to_svg()
```

对象式 API 也可以显式切换等比例显示和刻度标签侧：

```moonbit nocheck
let axes = matrix.axes()
axes.set_aspect_equal()
axes.set_x_tick_position(@axis.TickPosition::Top)
```

表格作为独立的 scene 图元绘制，支持单元格颜色、行列标签、对齐和归一化 bbox：

```moonbit nocheck
///|
let table = try! axes.table(
  cell_text=[["10", "20"], ["30", "40"]],
  col_labels=["x", "y"],
  row_labels=["first", "second"],
  loc="bottom",
)
```

饼图会校验非负数据、标签和颜色数量，并返回归一化后的扇区比例：

```moonbit nocheck
///|
let fractions = try! fig.pie([1.0, 2.0, 3.0], labels=["one", "two", "three"])
```

参考线和跨度也可以通过对象式或 `pyplot` API 添加：

```moonbit nocheck
fig.axes().hlines([0.5], 0.0, 1.0)
fig.axes().axvspan(0.2, 0.4, color="#abcdef")
```

统计图支持多组数据的箱线图，并保留离群点：

```moonbit nocheck
///|
let stats = try! fig.boxplot([[1.0, 2.0, 3.0, 4.0, 20.0], [2.0, 3.0, 4.0, 5.0]])
```

小提琴图从原始序列计算 Gaussian KDE，也可以选择带宽、分位数和统计线：

```moonbit nocheck
///|
let violins = try! fig.violinplot(
  [[1.0, 2.0, 3.0, 4.0], [2.0, 3.0, 5.0]],
  points=64,
  bandwidth=@scene.ViolinBandwidth::Silverman,
  quantiles=[[0.25, 0.75], [0.5]],
  showmeans=true,
  showmedians=true,
  side=@scene.ViolinSide::Both,
)
```

`horizontal=true` 将数据轴切换到水平方向；`side` 可以选择 `Both`、`Low` 或 `High`。SVG 后端会输出密度多边形及请求的统计线，常量序列会使用稳定的显示范围。

小提琴图从原始序列计算 Gaussian KDE，也可以选择带宽、分位数和统计线：

```moonbit nocheck
///|
let violins = try! fig.violinplot(
  [[1.0, 2.0, 3.0, 4.0], [2.0, 3.0, 5.0]],
  points=64,
  bandwidth=@scene.ViolinBandwidth::Silverman,
  quantiles=[[0.25, 0.75], [0.5]],
  showmeans=true,
  showmedians=true,
  side=@scene.ViolinSide::Both,
)
```

`horizontal=true` 将数据轴切换到水平方向；`side` 可以选择 `Both`、`Low` 或 `High`。SVG 后端会输出密度多边形及请求的统计线，常量序列会使用稳定的显示范围。

向量场使用配对的位置和分量数组：

```moonbit nocheck
try! fig.quiver(
  [0.0, 1.0], [0.0, 1.0],
  [1.0, -0.5], [0.5, 1.0],
)
```

规则二维网格可以绘制等值线和填充等值带。`x` 与 `y` 必须同时提供，且长度分别匹配列数和行数；省略时使用整数网格坐标：

```moonbit nocheck
///|
let data = [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0], [2.0, 3.0, 4.0]]

///|
let lines = try! fig.contour(data, levels=[1.0, 2.0, 3.0])
try! fig.clabel(lines, fontsize=12, color="#111827")

///|
let bands = try! fig.contourf(
  data,
  x=[10.0, 20.0, 30.0],
  y=[-1.0, 0.0, 1.0],
  levels=[0.0, 2.0, 4.0],
  cmap="viridis",
)
```

当前实现覆盖规则网格上的线性插值、代表性 level 标签、可配置 `clabel` 字号和 SVG 输出；`contourf` 与
`tricontourf` 的 `extend_mode`（对应 Matplotlib 的 `extend`）可取
`neither`、`min`、`max` 或 `both`，会按数据范围绘制
levels 之外的 under/over 色带。规则网格的 `corner_mask=false` 会屏蔽包含非有限角点的
整个单元，默认值 `true` 保留有限三角角点。`clabel(inline=true)` 会在代表性线段处留出
文字间隙。`@ticker.maxn_locator` 提供 1/2/2.5/5 的 nice step，并支持整数、对称范围和
端点裁剪；`@ticker.log_locator` 还支持按十进制周期配置 `subs` 和 `numdecs`；`@ticker.auto_minor_locator`、`@ticker.log_minor_locator` 和
`@ticker.fixed_minor_locator` 可生成次刻度。对象式和 pyplot 入口都可以把 major/minor
locator 接到轴上，并用 `grid(which="minor")` 绘制次网格：

```moonbit nocheck
try! fig.set_x_locator(try! @ticker.maxn_locator(count=6))
try! fig.set_x_minor_locator(try! @ticker.auto_minor_locator(subdivisions=2))
try! fig.axes().grid(which="minor", color="#dbeafe", linewidth=0.4)
```

`grid(which="major"|"minor", axis="x"|"y"|"both")` 可以分别控制两个方向；旧的
`which="x"`、`which="y"` 简写继续保留。

`@ticker.MultipleLocator::new(base=0.5, offset=0.25)` 按固定间隔和偏移生成数值刻度。
`base` 接受有限正 Double，`offset` 接受有限 Double；直接 `tick_values` 返回升序刻度，
包含范围外的相邻点。`as_locator()` 和 `as_minor_locator()` 可安装到主/次轴，主 adapter
亦可供 contour 使用；generic adapter 保留输入方向，次刻度还会裁到范围内并去掉主刻度。

```moonbit nocheck
let locator = try! @ticker.MultipleLocator::new(base=0.5, offset=0.25)
try! fig.set_x_locator(locator.as_locator())
try! fig.set_x_minor_locator(try! @ticker.MultipleLocator::new(base=0.25).as_minor_locator())
try! locator.set_params(base=1.0)
let independent = locator.copy()
```

对象的 `set_params` 先验证全部提供的值再更新，省略参数保持原值。轴、shared/secondary
轴和 generic adapter 的 `copy()` 保留同一可变对象，后续更新立即可见；需要独立配置时
使用 `MultipleLocator.copy()`。`multiple_locator(base=..., offset=...)` 是返回主刻度 adapter
的便利入口。

`@config.set_axes_autolimit_mode("round_numbers")` 让 MultipleLocator 的自动范围在边距和
sticky edges 之后对齐刻度；默认 `"data"` 保留数据范围。`view_limits` 每次读取当前 rc，
显式范围和图像暂存视图仍优先；当前 `tight` 采用零边距，尚无完整上游 tight 状态机。
Double 运算、eager 前缀上限及具体接线边界见 [固定间隔定位器说明](../testdata/multiple_locator_README.md)。
SVG 主/次与 secondary 刻度按变换后的视图和上游 `1e-10` 容差筛选绘制，
直接查询仍返回邻接点，标签布局先使用完整刻度集。

命名 `LinearLocator`、`IndexLocator` 和 `FixedLocator` 在 D21 按各自源对象语义接入：
Linear 默认有效数量为11，支持共享 preset store；Fixed 保留输入顺序、重复值和非有限值，
忽略查询范围；Index 从数据起点加 offset 按 base 步进，允许负步长且不排序范围。
旧 `linear_locator` / `fixed_locator` helpers 的默认值、校验和裁剪继续保留。

```moonbit nocheck
let fixed = @ticker.FixedLocator::new([4.0, 1.0, 0.0, -1.0, -4.0], nbins=2.0)
let ticks = try! fixed.tick_values(100.0, -100.0)
assert_eq(try! ticks.to_array(), [0.0])
try! ticks.set(-1, 0.5)
try! fig.set_x_locator(fixed.as_locator())
```

Linear 与 Fixed 的直接结果是可变 `TickValues`，保留 preset/位置 buffer 的借用和 stride；
`get`/`set` 支持负索引，`view(start,stride,length)` 支持反向、嵌套和零 stride，
`to_array` 和 `copy` 产生独立值。`FixedLocator::new` 借用数组，`from_view` 保留已有 view，
`from_list` 复制，`locations()` 返回 TickValues；对象 `copy()` 浅共享位置 buffer，独立保存 nbins。
Linear 的 `presets().set_view` 可借用同一类 view，`get` 也返回 TickValues。主/次 adapter 保留 live
handle，generic adapter 物化结果时才应用前缀上限；Index 的轴调用使用真实 data interval。
`TickValues::from_int64_array` 也可借用真实整数buffer：Double赋值按Int64向零截断，
NaN/Inf/越界抛checked错误，view/copy保留储存类型；get/to_array仍提供Double访问接口。
错误传播、preset/更新细节与 shared/secondary 接线状态见
[命名数值定位器说明](../testdata/named_numeric_locator_README.md)，最终门禁记录在迁移检查点。

D22 已验收命名 `MaxNLocator` 与 `AutoLocator`。MaxN 的 nbins 表示间隔上限，
`MaxNBins::Count(4)` 与 `MaxNBins::Auto` 可分别指定固定预算和物理轴空间预算：

```moonbit nocheck
let locator = try! @ticker.MaxNLocator::new(nbins=@ticker.MaxNBins::Count(4), integer=true)
try! fig.set_x_locator(locator.as_locator())
let automatic = @ticker.AutoLocator::new()
try! fig.set_y_locator(automatic.as_locator())
fig.axes().y_axis().set_tick_label_size(12.0)
```

Auto 在构造时捕获 `config.classic_mode()`，后续参数更新和查询共享 `as_maxn_locator()`
返回的 live 对象。主/次 adapter 保留 live handle；源错误沿 checked 轴、contour 与 SVG 链传播。
classic=true的默认steps保留原Int64 buffer，false为Float64；复制后仍共享各自原buffer。
steps 接收 borrowed `TickValues`，extended staircase 独立捕获；`set_params` 保留上游的
逐项更新和失败后部分状态，`steps=None` / `prune=None` 与省略参数不同。

自动预算使用实际 plot 长度与实际 tick 字号，并保留原物理换算的舍入顺序，x 为 `floor(width/(3*size))`，y 为
`floor(height/(2*size))`；secondary 使用父 plot 的主方向长度和自己的字号。
当前为固定 SVG dpi72/user-unit profile，默认字号10，数值小于1先夹到1，NaN/Inf保留
原字体比较语义；完整字体 rc、字符串字号和可变dpi仍待迁移。旧 `maxn_locator(count=...)`
继续原 helper 合同。参数、精度、邻接点、前缀上限和参考见
[MaxN/Auto说明](../testdata/maxn_locator_README.md)；四目标及原源验收记录见检查点。

命名 `AutoMinorLocator` 从排序去重后的前两个主刻度确定统一网格；首次有效查询才捕获
x/y 的 `minor_tick_divisions` 配置，之后重绑轴或修改配置不会重置捕获值：

```moonbit nocheck
let minor = @ticker.AutoMinorLocator::new()
try! fig.axes().set_x_minor_locator(minor.as_minor_locator())
minor.set_ndivs(Some(@config.MinorTickDivisions::Number(2.5)))
try! fig.axes().set_y_locator(@ticker.NullLocator::new().as_locator())
```

`Number(Double)` 保留原构造器的零、负数、小数和非有限值；rc 验证则转换成非负的
`Integer(BigInt)`，`Text("auto")` 按主间隔自动选择四或五段。`set_ndivs(None)` 可以重新捕获。
直接 `tick_values` 保留上游“不支持”错误，绑定后的 `call` 才执行查询。Axis 的 raw minor
getter 保留邻接点，随后按变换后的范围去重；SVG 在绘制时另做可视过滤。secondary 支持自己
的主刻度、minor locator 与 overlap 配置。`NullLocator` 可用于主、次刻度，SVG 分别跳过其
定位和格式化。旧 `auto_minor_locator` helper 保留原合同；完整参数、整数精度、引用所有权、
上限与未迁移边界见 [AutoMinor/Null说明](../testdata/auto_minor_locator_README.md)。

命名 `LogLocator` 已接入主、次刻度和 secondary，D24 已通过四目标验收：

```moonbit nocheck
let major = try! @ticker.LogLocator::new()
let minor = try! @ticker.LogLocator::new(subs=Some(@ticker.LogSubs::Text("auto")))
try! fig.set_x_locator(major.as_locator())
try! fig.axes().set_x_minor_locator(minor.as_minor_locator())
```

省略 `subs` 使用 `[1]`，显式 `subs=None` 选择自动次刻度；数值序列使用
`LogSubs::Values(TickValues)`，保留 Float64 view 的共享。`LogNumTicks` 区分原始文本、
Double 与任意精度整数；构造器捕获 classic 默认预算，查询继续读取当前 classic 和
autolimit 配置。`tick_values` 使用所属轴的局部 minpos，`nonsingular` 和 `view_limits`
使用共享轴 minpos；非正下界、倒置范围及错误传播保留各自查询顺序。
普通 log helpers 的旧合同继续保留。参数、所有权、自动范围、数值精度和验收状态见
[LogLocator说明](../testdata/log_locator_README.md)；完整默认 Axis 生命周期仍在后续范围内。

命名 `SymmetricalLogLocator` 已在 D25 通过四目标验收。显式指定 base 和线性阈值，
或从已有 `Scale::SymLog` 捕获这两个值：

```moonbit nocheck
let locator = try! @ticker.SymmetricalLogLocator::new(base=10.0, linthresh=2.0)
try! fig.set_y_locator(locator.as_locator())
locator.set_params(subs=@ticker.SymLogSubs::Values(@ticker.TickValues::from_array([1.0, 2.0])))
```

它保持 Float64/Int64 subs 的共享储存类型，默认 `numticks=15`，只使用所属轴的 view；
线性区早返回、负段和 subs 顺序、外部邻接刻度及延迟错误按源对象处理。Scale 便利函数的
旧默认阈值与验证继续保留；完整默认 locator/formatter 生命周期仍待迁移。参数、数值
边界和 secondary 放置证据见 [SymmetricalLogLocator说明](../testdata/symlog_locator_README.md)。

D26 已验收命名 `AsinhLocator` 与最小 Asinh 坐标几何。两者显式配对，locator 的
`linear_width` 独立于坐标变换，构造器默认请求 11 个采样点：

```moonbit nocheck
let geometry = try! @mathplotlib.asinh_scale(linear_width=1.0)
let locator = @ticker.AsinhLocator::new(1.0)
try! fig.set_x_scale(geometry)
try! fig.set_x_locator(locator.as_locator())
```

原始 `subs` 区分共享 sequence 与 ndarray view；显式 `numticks=None` 会保留到查询时报错。
数值原语采用跨目标正确舍入数学合同，近底数幂处可能与 Darwin 源平台生成不同的整组刻度；
含 NaN 的源集合排序非确定，本移植保留 NaN 数量并将其置于数值刻度之后。完整 AsinhScale
默认 locator/formatter 生命周期仍在后续。四目标新增 1061 项测试及原源复验均通过，精确范围见
[AsinhLocator说明](../testdata/asinh_locator_README.md)。

D27 已验收命名 `LogitLocator` 与最小 Logit 几何。显式安装定位器，原始概率刻度
可保留下溢零、重复值及视图外邻点，放大局部时复用同一个 MaxN 参数状态：

```moonbit nocheck
let major = try! @ticker.LogitLocator::new()
let minor = try! @ticker.LogitLocator::new(minor=true)
try! fig.set_x_scale(try! @mathplotlib.logit_scale(nonpositive="mask"))
try! fig.set_x_locator(major.as_locator())
try! fig.axes().set_x_minor_locator(minor.as_minor_locator())
```

`as_maxn_locator()` 提供共享的继承参数状态；直接调用该状态的数值方法采用 MaxN 合同。
Logit 自身的查询继续读取所属轴 view、投影名称、实际 tick space 与局部 minpos。
最小几何支持 `mask`/`clip` 数值变换及有效概率域 SVG；完整默认格式器安装、tight 生命周期
和域外 clip 路径仍在后续范围。新增 879 项测试，四目标及三份原源参考检查全部通过；
MaxN 的两处十进制幂复用可移植正确舍入原语，修复非 JS 目标的刻度起点误差。准确范围见 [LogitLocator说明](../testdata/logit_locator_README.md)。

D28 已验收命名基础 `BaseFormatter`、`NullFormatter`、`FixedFormatter` 与
`FuncFormatter`。这些对象保留借用的刻度位置、可变序列和轴身份，通过独立的 checked
接口安装；原有 formatter 便利函数的复制与纯函数合同继续保留：

```moonbit nocheck
let formatter = @ticker.FuncFormatter::new(fn(value, pos) {
  let index = pos.unwrap_or(-1)
  "\{value}@\{index}"
})
try! fig.set_x_named_formatter(formatter.as_base_formatter())
```

带位置的回调读取整组原始刻度，视图外标签也先参与格式化；回调错误会传给 SVG 调用方。
原始数值 view 在批量执行后才物化，保留回调内修改未来元素的行为；完整 Text/Tick 缓存和
默认格式器安装生命周期仍待后续。新增 352 项测试，四目标及三份原源参考检查全部通过；
具体范围见 [基础 Formatter 说明](../testdata/basic_formatter_README.md)。

D29 已验收命名 `FormatStrFormatter` 与 `StrMethodFormatter`，同样安装到 named formatter
槽。格式字符串可以通过 `set_fmt` 修改；无效格式在调用时抛出 checked 错误。

```moonbit nocheck
let formatter = @ticker.StrMethodFormatter::new("{x:.2f}")
try! fig.set_x_named_formatter(formatter.as_base_formatter())
formatter.set_fmt("{pos}: {x:+.3g}")
```

直接调用与 Double 数组采用 Python float 格式，数值 view 保留 Float64/Int64 来源；整数
标签保留全部 64 位，`!r` 保留 NumPy 类型信息。主次刻度、共享轴和 secondary/SVG 复用
既有 checked 管线，Unicode 负号按字段动态处理。新增 5161 项测试，四目标与六份原源
参考检查全部通过；支持范围、C locale 和动态 Python 边界见
[字符串 Formatter 说明](../testdata/string_formatter_README.md)。

D30 已验收命名 `PercentFormatter`，保留可变原始参数、浅复制、每值读取当前轴范围与
动态符号转义。自动精度及显式精度转换、Python/NumPy 标量、虚拟轴整数范围、共享轴
绑定和副轴同步顺序均通过原源对照。

```moonbit nocheck
let formatter = try! @ticker.PercentFormatter::new(
  xmax=@ticker.PercentXMax::Number(1.0),
)
try! fig.set_x_named_formatter(formatter.as_base_formatter())
formatter.set_decimals(@ticker.PercentDecimals::Number(2.0))
```

新增 2293 项测试；wasm、wasm-gc、native 各 19801 项，JS 19808 项全部通过，三份新
原源检查通过。支持范围、精度文本和副轴时序见
[百分比 Formatter 说明](../testdata/percent_formatter_README.md)。

D31 已验收命名 `ScalarFormatter`，支持独立的刻度、数据、短标签和 offset 格式化，
保留可变缓存、原始数值类型、借用参数、locale 分组与实际坐标轴的像素精度。

```moonbit nocheck
let formatter = @ticker.ScalarFormatter::new(use_math_text=Some(false))
try! fig.set_x_named_formatter(formatter.as_base_formatter())
formatter.set_scientific(false)
```

checked 准备与 offset 错误贯通主次轴、共享轴、secondary 和 SVG；NullLocator 跳过
刻度批次后仍读取当前 offset。新增 1685 个注册测试承载 5706 个细分验证案例，四目标
全过，五份新原源检查通过。数值、locale、SVG72 几何与宿主边界见
[ScalarFormatter 说明](../testdata/scalar_formatter_README.md)。

D32 已验收命名 `EngFormatter`，保留工程前缀、动态单位和精度、自动 offset、可变前缀表，
并通过同一对象的 `ScalarFormatter` 视图访问继承状态。

```moonbit nocheck
let formatter = @ticker.EngFormatter::new(
  unit="Hz",
  use_offset=Some(@ticker.ScalarNumber::Boolean(true)),
)
try! fig.set_x_named_formatter(formatter.as_base_formatter())
formatter.set_unit("s")
formatter.as_scalar_formatter().set_use_locale(Some(false))
```

主次轴、共享轴、secondary 与 SVG 保留完整批次和最终 offset 的调用顺序。新增 62 个
注册测试承载 1740 个验证案例，另含 6200 步字典操作轨迹；四目标全过，五份新原源
检查通过。数值与 NaN 身份哈希的可移植 profile、类型和宿主边界见
[EngFormatter 说明](../testdata/eng_formatter_README.md)。

D33 已验收命名 `LogFormatter`、`LogFormatterExponent`、`LogFormatterMathtext` 和
`LogFormatterSciNotation`，保留可变原始参数、live 父类视图和独立浅复制。

```moonbit nocheck
let formatter = try! @ticker.LogFormatterSciNotation::new()
try! fig.set_x_named_formatter(formatter.as_base_formatter())
formatter.set_label_minor(@ticker.LogValue::Numeric(@ticker.ScalarNumber::Boolean(true)))
```

`set_locs` 忽略传入位置，空批次也按当前轴范围刷新子标签；真实主次轴、共享轴和
secondary 使用各自实际 transform 的 linthresh。新增 152 个注册测试承载 4557 个验证
案例；wasm、wasm-gc、native 各 21700 项，JS 21707 项全部通过，四份新原源检查通过。
完整逻辑集合、文本底数、可移植数学及宿主边界见
[LogFormatter 家族说明](../testdata/log_formatter_README.md)。

D34 已验收命名 `LogitFormatter`，用于概率轴的十进制幂、半值和补数标签：

```moonbit nocheck
let formatter = @ticker.LogitFormatter::new()
let labels = try! formatter.format_ticks([0.1, 0.5, 0.9])
try! fig.set_x_named_formatter(formatter.as_base_formatter())
```

它保留 raw 参数、独立位置快照和浅复制共享的可变 minor 标签集合；`LogitKey` 可显式
保留 NaN 键身份，`TickValues` 批次则按 NumPy 标量读取规则处理。新增123个注册测试承载3779个细分案例，四目标验证与六份源检查通过；
具体类型、排序/集合协议和宿主边界见[LogitFormatter 说明](../testdata/logit_formatter_README.md)。

数值轴也可以设置基础 formatter。`scalar_formatter` 支持 power limit 和 additive offset，
`fixed_formatter` 按位置提供标签，`format_str_formatter` 支持 `%g`、`%f`、`%e`、`%d`、`%%`
及常见宽度/精度标志，`log_formatter`、`null_formatter` 和 `func_formatter` 分别用于对数、
隐藏标签和自定义函数。formatter 会复制自己的配置，日期轴和类别轴会拒绝 numeric formatter：

```moonbit nocheck
try! fig.set_x_formatter(@mathplotlib.format_str_formatter("x=%+.2f"))
try! fig.set_y_formatter(try! @mathplotlib.scalar_formatter())
```

Scalar formatter 选中的 offset 会在 SVG 轴边缘显示，并按 viewport 计算科学倍率和精度；
`eng_formatter` 支持 SI 工程前缀、负指数和舍入进位，`percent_formatter` 会按 viewport
自动选择 0 到 5 位小数，`log_formatter` 的 `label_only_base` 只隐藏非底数幂位置而保留
数值标签。Scalar offset 支持后端中立的乘号和 Unicode 上标表示；完整 mathtext 排版和
更多 formatter 组合仍在迁移中。

标注默认使用数据坐标。`xycoords` 可以改为 `axes fraction`、`figure fraction` 或
SVG `display` 坐标；
文本位置还可以用同一组 fraction 坐标，或用相对于锚点的 `offset points`（SVG 中按
显示坐标换算）或 `offset pixels`。`connector` 支持 `straight`、`arc3` 和 `angle`：

```moonbit nocheck
try! fig.annotate(
  "peak",
  1.0,
  2.0,
  offset_x=0.25,
  offset_y=0.30,
  arrow=true,
  fontsize=14,
)
try! fig.annotate(
  "screen label",
  0.25,
  0.75,
  offset_x=36.0,
  offset_y=18.0,
  xycoords="axes fraction",
  textcoords="offset points",
  connector="arc3",
  arrow=true,
)
try! fig.annotate(
  "figure label",
  0.1,
  0.9,
  xycoords="figure fraction",
  textcoords="figure fraction",
  connector="angle",
)
try! fig.annotate(
  "display label",
  40.0,
  50.0,
  offset_x=18.0,
  offset_y=12.0,
  xycoords="display",
  textcoords="offset pixels",
)
try! fig.arrow(0.0, 0.0, 1.0, 0.5, color="#1f77b4")
```

当前版本输出 SVG 线段、填充箭头头部和文本；`fontsize` 会传递到 SVG 文本样式。
复合 transform、完整连接器参数对象和富文本属性仍待迁移。

无限直线可以用两个点定义，也可以用一个点和数据坐标斜率定义；SVG 后端会把它裁剪到当前坐标区域：

```moonbit nocheck
try! fig.axline(@mathplotlib.point(0.0, 0.0), slope=1.0, color="#7f1d1d")
try! fig.axline(
  @mathplotlib.point(0.0, 1.0),
  xy2=@mathplotlib.point(1.0, 0.0),
)
```

次坐标轴可以通过一对前向/逆向函数建立。它会复用主轴的刻度位置，
并把转换后的数值绘制在顶部或右侧：

```moonbit nocheck
let secondary = fig.secondary_xaxis(x => x * 2.0, x => x / 2.0)
secondary.set_label("double x")
```

同一个 Axes 可以挂载多个次坐标轴；每个实例都可以独立设置位置、标签和固定刻度：

```moonbit nocheck
let top = fig.secondary_xaxis(x => x * 2.0, x => x / 2.0)
top.set_label("double x")
let bottom = fig.secondary_xaxis(
  x => x + 10.0,
  x => x - 10.0,
  location=@scene.SecondaryAxisLocation::Bottom,
)
bottom.set_label("shifted x")
```

附加图元也按独立 API 接入：`fill` 绘制闭合多边形，`broken_barh` 绘制水平断续条，
`hist2d` 计算矩形二维直方图，`quiverkey` 在数据坐标中绘制带标签的向量键。

```moonbit nocheck
try! fig.fill([0.0, 1.0, 0.5], [0.0, 0.0, 1.0], color="#d62728")
try! fig.broken_barh([(0.0, 0.5), (0.8, 0.4)], (0.2, 0.3))
try! fig.hist2d([0.0, 0.5, 1.0], [0.0, 1.0, 0.5], bins_x=4, bins_y=4)
try! fig.quiverkey(0.2, 0.8, 0.4, "speed")
```

规则网格的标量数据可以用 `pcolor` 或 `pcolormesh` 绘制。坐标数组表示 cell boundaries，长度分别比列数和行数多一：

```moonbit nocheck
try! fig.pcolormesh(
  [[0.0, 0.5], [1.0, 0.25]],
  x=[10.0, 20.0, 30.0],
  y=[-1.0, 0.0, 1.0],
  vmin=0.0,
  vmax=1.0,
  cmap="viridis",
)
```

省略 `x` 和 `y` 时使用整数边界；非有限单元会跳过。二维曲线坐标可以使用
`pcolor_grid` 或 `pcolormesh_grid`，`flat` 使用角点网格，`nearest` 从中心网格推导边界，
`gouraud` 使用与数据同形状的顶点网格并在每个四边形的两个三角形上插值顶点颜色：

```moonbit nocheck
try! fig.pcolormesh_grid(
  [[0.0, 1.0], [2.0, 3.0]],
  [[0.0, 1.0], [0.2, 1.2]],
  [[0.0, 0.1], [1.0, 1.1]],
  shading="nearest",
)
```

`gouraud` 示例：

```moonbit nocheck
try! fig.pcolor_grid(
  [[0.0, 0.5, 1.0], [0.25, 0.75, 1.25], [0.5, 1.0, 1.5]],
  [[0.0, 1.0, 2.0], [0.0, 1.0, 2.0], [0.0, 1.0, 2.0]],
  [[0.0, 0.0, 0.0], [1.0, 1.0, 1.0], [2.0, 2.0, 2.0]],
  shading="gouraud",
)
```

SVG 使用每个三角形的三色渐变编码 Gouraud 插值。需要传播二维数据或坐标掩码时，
使用 `pcolor_grid_masked` / `pcolormesh_grid_masked`，三种 shading 都会跳过依赖
被屏蔽顶点的单元；`pcolormesh_grid_masked` 对数据 mask 保留 bad 色语义。
`pcolor_grid` 和 `pcolor_grid_masked` 的 `antialiased` 会在 SVG 单元边界启用细边；
`pcolormesh_grid` 和对应 masked 入口默认关闭，也可显式打开。
规则网格 `pcolor` / `pcolormesh` 及其 masked、显式 norm 入口也接受同名参数，默认值
分别为开启和关闭。

规则网格也可以传入显式颜色规范化和色图对象，从而保留离散分箱以及 under/over/bad 颜色：

```moonbit nocheck
let norm = @colors.boundary_color_norm(
  try! @colors.boundary_norm([0.0, 1.0, 2.0], 2),
)
let cmap = try! @colors.listed_colormap("traffic", [
  try! @colors.rgba(1.0, 0.0, 0.0),
  try! @colors.rgba(0.0, 0.0, 1.0),
])
cmap.set_under(try! @colors.rgba(0.0, 1.0, 0.0))
cmap.set_over(try! @colors.rgba(1.0, 1.0, 0.0))
try! fig.pcolor_with_norm_and_colormap([[-1.0, 0.5, 1.5, 3.0]], norm, cmap)
```

阶梯和离散事件图使用独立的场景图元：

```moonbit nocheck
try! fig.step([0.0, 1.0, 2.0], [1.0, 2.0, 1.0], where_="post")
try! fig.stairs([1.0, 2.0], edges=[0.0, 1.0, 2.0], fill=true)
try! fig.fill_betweenx([0.0, 1.0, 2.0], [0.0, 0.5, 0.0], right=[1.0, 1.5, 1.0])
ignore(try! fig.stackplot(
  [0.0, 1.0, 2.0],
  [[1.0, 2.0, 1.0], [2.0, 1.0, 2.0]],
  labels=["lower", "upper"],
  baseline="zero",
))
try! fig.stem([1.0, 2.0, 1.5])
try! fig.eventplot([[0.0, 1.0, 2.0], [0.5, 1.5]])
```

`step` 的 `where_` 支持 `pre`、`post`、`mid`；`stairs` 和 `stem` 支持水平布局。当前事件图先以多条线段表示，复杂 LineCollection 属性仍待迁移。

向量场还可以用基础 `barbs` 绘制风羽线段：

```moonbit nocheck
try! fig.barbs(
  [0.0, 1.0],
  [0.0, 1.0],
  [1.0, -0.5],
  [0.5, 1.0],
  color="#1f77b4",
)
```

`barbs_with_options` 还支持按 half/full/flag 增量绘制、rounding、flip、calm fill 和
tail/middle/tip pivot：

```moonbit nocheck
try! fig.barbs_with_options(
  [0.0, 1.0],
  [0.0, 1.0],
  [55.0, 25.0],
  [0.0, 0.0],
  pivot="middle",
  flip=true,
)
```

规则 1D 网格上的向量场可以积分成流线：

```moonbit nocheck
ignore(try! fig.streamplot(
  [0.0, 1.0, 2.0],
  [0.0, 1.0, 2.0],
  [[1.0, 1.0, 1.0], [1.0, 1.0, 1.0], [1.0, 1.0, 1.0]],
  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
  density=1.0,
))
```

当前版本使用双线性采样和自适应一阶/二阶 Heun 积分，支持严格递增等间距网格、独立 `density_x`/`density_y`、显式起点、正向/反向/双向积分、最小/最大归一化弧长、积分时断裂轨迹占据、30×density 边界优先起点掩码、显示空间箭头、常用 `FancyArrowPatch` 箭头样式和 `StreamplotSet` 返回对象。`streamplot_with_style_grids` 可以把网格值映射到线宽和颜色，并接受 `vmin`/`vmax`：

```moonbit nocheck
///|
let stream = try! fig.streamplot_with_style_grids(
  [0.0, 1.0],
  [0.0, 1.0],
  [[1.0, 1.0], [1.0, 1.0]],
  [[0.0, 0.0], [0.0, 0.0]],
  linewidths=[[1.0, 2.0], [1.0, 2.0]],
  color_values=[[0.0, 1.0], [0.0, 1.0]],
  cmap="viridis",
  arrows=false,
)
```

二维 meshgrid 坐标可以通过 `streamplot_mesh` 传入；带连接器参数和样式参数字符串的完整 FancyArrowPatch 路径仍待迁移。

统计辅助函数会同时返回可检查的数据对象并绘制结果：

```moonbit nocheck
///|
let correlation = try! fig.acorr(
  [1.0, 2.0, 3.0],
  maxlags=1,
  detrend=@scene.detrend_mean,
)

///|
let cdf = try! fig.ecdf(
  [3.0, 1.0, 1.0, 2.0],
  weights=[1.0, 2.0, 1.0, 1.0],
  compress=true,
)
```

当前版本支持 `acorr`、`xcorr` 和 `ecdf` 的基础有限数组语义；`acorr`/`xcorr` 可传入 `detrend` 函数，也提供 `@scene.detrend_none`、`@scene.detrend_mean` 和 `@scene.detrend_linear`；置信区间、复数数值以及统计函数的 masked array 输入仍待迁移。

散点数据可以按规则六边形聚合：

```moonbit nocheck
///|
let bins = try! fig.hexbin(
  [0.0, 0.1, 1.0, 1.0],
  [0.0, 0.0, 1.0, 1.0],
  gridsize=3,
  cmap="viridis",
)
```

`hexbin` 默认显示每个六边形中的点数，也可以传入 `values` 使用 bin 均值；`reduce` 还支持 `sum`、`min`、`max` 和 `count`，也可以用 `@scene.hexbin_reducer` 包装自定义聚合函数。`bins="log"` 可对正的聚合值使用对数色阶，`extent=[xmin, xmax, ymin, ymax]` 可裁剪聚合范围，`marginals=true` 会绘制底部和右侧边际计数柱，并可用 `edgecolor`/`linewidth` 设置六边形边缘。在对数或对称对数坐标轴上，六边形会在变换后的坐标空间中保持规则。

矩阵稀疏模式可以用 `spy` 显示；`precision` 控制非零阈值，`markersize` 控制标记大小，
`marker` 支持 `o`、`s`、`^`、`v`、`D`、`x`、`+`、`|`、`_`、`.` 和 `,`，`origin` 支持
`upper`/`lower`，`aspect` 支持 `equal`/`auto`（默认 `equal`）：

```moonbit nocheck
try! fig.spy(
  [[0.0, 1.0, 0.0], [2.0, 0.0, -3.0]],
  precision=0.5,
)
```

显式三角网格可以绘制线框或按顶点标量填色：

```moonbit nocheck
let xs = [0.0, 1.0, 0.0]
let ys = [0.0, 0.0, 1.0]
let triangles = [[0, 1, 2]]
try! fig.triplot(xs, ys, triangles)
try! fig.tripcolor(xs, ys, triangles, [0.0, 0.5, 1.0])
try! fig.tripcolor(xs, ys, triangles, [0.0, 0.5, 1.0], mask=[false])
```

`triplot`、`tripcolor`、`tricontour` 和 `tricontourf` 的 `mask` 按三角形逐面生效，
被屏蔽的面不会生成 artist。

`tripcolor` 的标量数组可以按顶点提供（每个三角面取均值），也可以按三角面提供
（每个面直接使用一个值）。

自动 contour levels 可以通过 `ticker.Locator` 控制；支持线性、固定和对数 levels，
对数 locator 可通过 `subs` 生成每个 decade 内的次级 levels，
对象式和 pyplot 入口使用同一 locator：

```moonbit nocheck
///|
let locator = @ticker.linear_locator(count=5)

///|
let contour_set = try! fig.contour([[0.0, 1.0], [2.0, 3.0]], locator~)
```

需要复用网格拓扑时，可以用 `triangulation` 从顶点自动生成确定性的 Delaunay 网格，
并在多个绘图调用之间共享唯一边、邻接和 mask：

```moonbit nocheck
let mesh = try! @scene.triangulation(
  [0.0, 1.0, 0.0, 1.0],
  [0.0, 0.0, 1.0, 1.0],
)
try! fig.triplot_triangulation(mesh)
try! fig.tripcolor_triangulation(mesh, [0.0, 1.0, 2.0, 3.0])
```

可以从同一网格取得 `TriFinder`，查询单点或并行坐标数组；外部点和 masked 面返回 `-1`：

```moonbit nocheck
///|
let finder = mesh.get_trifinder()

///|
let face = finder.find(0.25, 0.25)

///|
let faces = try! finder.find_many([0.25, 0.75], [0.25, 0.75])
```

三角网格也可以直接生成线性等值线和填充等值带：

```moonbit nocheck
///|
let tri_lines = try! fig.tricontour(xs, ys, triangles, [0.0, 1.0, 2.0], levels=[
  0.5, 1.5,
])

///|
let tri_bands = try! fig.tricontourf(xs, ys, triangles, [0.0, 1.0, 2.0], levels=[
  0.0, 1.0, 2.0,
])
```

三角等值线会把共享边上的 crossing 拼成连续 polyline；闭合路径保留首尾闭合点。
`tricontourf` 会在每个 filled band 内消除相邻三角形的内部共享边，生成外环和孔洞环，
并把多个边界环编码为 SVG 的 even-odd compound path，使孔洞保持透明；逐面 `mask` 会阻止跨过被屏蔽面的连接。三角 contour 的 z 值必须是有限数。线 contour
还可以传入按 level 循环使用的 `colors` 和 `linewidths`；省略时继续使用单个 `color`
和 `linewidth`。`ContourSet::segments()`、`segment_levels()`、`allsegs()` 和
`layers()` 可读取已拼接的线路径或 filled band 边界。

`Figure::to_drawing()` 的线等值线提示保存精确 level 和原生成路径槽；填色等值区
保存实际 clip 区间、代表值和原逻辑 band 槽，完整区域按真实 SVG 填充规则识别孔洞。
填色的 band 槽不等于上述 getter 的去空 layer 或展平边界环索引，几何锚点也不表示
鼠标处标量场采样。详见[线等值线交互](CONTOUR_INTERACTION.md)和
[填色等值区交互](CONTOURF_INTERACTION.md)。

线性轴也可以切换为基础十进制对数轴，或使用跨过零点的对称对数轴；普通对数轴上的
非正数据点会被 SVG 后端跳过：

```moonbit nocheck
let fig = @mathplotlib.figure(width=420, height=260)
try! fig.loglog([1.0, 10.0, 100.0], [1.0, 10.0, 100.0])
let svg = fig.to_svg()
```

```moonbit nocheck
let symlog = try! @scale.symlog_scale(linthresh=1.0, base=10.0)
try! fig.set_x_scale(symlog)
try! fig.set_y_scale(symlog)
try! fig.plot([-100.0, -1.0, 0.0, 1.0, 100.0], [-100.0, -1.0, 0.0, 1.0, 100.0])
```

类别数据会按首次出现顺序转换为轴位置，重复类别保持相同位置，并沿用现有 SVG 刻度渲染：

```moonbit nocheck
let fig = @mathplotlib.figure(width=420, height=260)
fig.plot_category(["低", "高", "低"], [1.0, 3.0, 2.0])
let svg = fig.to_svg()
```

The current implementation is the first migration slice. It intentionally
keeps plotting data separate from rendering so additional axes, chart types,
backends, and host integrations can be added without changing the core data
API. It is not yet a complete Matplotlib replacement.

The staged migration scope, package boundaries, and acceptance criteria are
documented in [MIGRATION_PLAN.md](MIGRATION_PLAN.md). The pinned upstream
survey and real implementation status are tracked in
[UPSTREAM_SURVEY.md](UPSTREAM_SURVEY.md) and
[COMPATIBILITY.md](COMPATIBILITY.md).

Run the example CLI with:

```text
moon run cmd/main
```

Run checks and tests with:

```text
moon check --target all
moon test
moon test --target native
```


D35 已接通五种既有几何的显式默认刻度安装。`Axis::set_scale`、
`Axes::set_x_scale` / `set_y_scale` 每次都会创建真实命名 major/minor locator 和 formatter，
重复设置也重新读取 rc。Linear 的 x/y minor.visible 独立，默认关闭；Asinh minor 使用
共享不可变 tuple。共享轴共用 ticker 槽和四个默认标志，保留各自视图与几何；移除后
旧句柄仍保有源 ticker 别名。已有 `set_tick_count` 继续作为显式便利采样入口。
构造/clear/units/secondary 的完整默认生命周期仍在后续范围，源边界与四目标验收见
[默认安装说明](../testdata/scale_defaults_README.md)。


D36 已接通构造与 clear 的实际默认生命周期。`axis(horizontal=false)` 在构造时读取 y
配置；`Axis::clear` 原位替换共享 ticker，保留视图与 overlap 设置。`Axes::clear_checked`
按原源清理自己、共享成员、late minor rc 与目标视图；Figure/SubFigure 也提供 checked
入口，嵌套面板只走一次清理。共享组与 Figure 绘制列表分开，已移除目标可以重新加入
刻度组。源对照、保留转换信息、用户回调错误及两类视图 provider 的区别见
[构造与清理说明](../testdata/initial_clear_README.md)。完整自动范围状态与通用 units 更新
仍按后续切片推进。

D38 已接通内建 Date/Category 单位生命周期。四个 locator/formatter 槽位独立保留用户设置，
重复类别输入只追加共享 `CategoryUnits` 映射；日期单位变化按真实共享顺序更新默认对象、
执行 checked 单位回调，再请求对应方向自动范围。同 converter、同单位的重复数据不会因为
rc 改变而重装默认对象。日期和类别都使用与 numeric 相同的缓存范围、stale、auto-enable、
stored view 和 SVG 路径；类别没有固定半格扩边。

`AxisUnitTag` 与 `Axes::set_x_units` / `set_y_units` 是有序、失败保留前置修改的单位入口；
已有 `set_x_date_converter` 等预校验便利操作继续保留其原合同。类别刻度向命名 formatter
传递 Python 整数列表来源，`{x:d}` 与 `{x!r}` 可正确格式化；显式 Double 批次仍保留浮点来源。
公开日期 locator 查询可用 `tick_values_checked` 保留错误。现有显式类别配置替换仍是单独的
便利扩展。D38 精确范围与复现见
[testdata/units_lifecycle_README.md](../testdata/units_lifecycle_README.md)。

D39 已保留 Line 每个坐标的 Numeric、Category 或 Date 原始输入。通过 `set_x_units` /
`set_y_units` 替换类别映射时，类别 Line 按新映射回算，缺失旧标签会追加；同坐标的数值
Line 保持原值。单位回调逐 Line 转换 x、y，两者成功后才更新该 Line，全部成功后重建
dataLim 并仅请求事件方向；晚失败保留前面 Line 和单位映射已发生的修改。
Scatter 和生成的 contour/streamplot 显示线继续使用已转换几何。公开 Artist 和 render
模型在 D39 阶段仍为数值快照；公开数据句柄由下述 D44 承接。原源对照与边界见
[testdata/line_units_README.md](../testdata/line_units_README.md)。

D40 为每个次坐标轴保留独立的数值 Axis、默认 locator/formatter、四个默认标志和视图。
非 log 父轴的子轴初始视图为 `[0,1]`；`apply_aspect` 同步父范围，绘制时先按旧子轴
上下文设置范围，再按父 scale 名称决定是否重装默认对象。只有父轴名称恰为 `log`
才安装 functionlog。`set_ticks` 的历史标志在直接替换 locator 后仍保留；父 scale 名称
变化时恢复的是当前 locator 的刻度，而不是旧的 `set_ticks` 参数。

SVG 按次轴创建顺序准备完整主次刻度批次，使用各自已经安装的变换与独立视图放置刻度。
显式 `set_tick_count` / `clear_locator` 采样仍是便利扩展。旧可变 `tick_count`、`fixed_ticks`、
`locator`、`formatter` 字段已收束为现有 getter/setter，避免形成两份状态。
完整源构造器、物理尺寸、错误阶段及尚未覆盖的 Transform/GUI 协议见
[次坐标轴生命周期](../testdata/secondary_lifecycle_README.md)。本片行为验收结果见执行检查点。

D41 增加 `SecondaryAxis::set_functions(forward, inverse)` 与 `reset_functions()`，后者
对应原版的 `set_functions(None)`。当前函数通过原有 `forward()` / `inverse()` getter
取得，旧 getter 返回的函数值仍可使用；原公开只读字段现由私有可变存储承接。
同名父 scale 下，替换函数保留已安装的变换、刻度对象和当前视图。之后 aspect/draw
用新函数映射父范围，已安装变换则等父 scale 名称变化才重装。

新函数先存入，再执行名称检查与必要重装；CURRENT locator 查询失败时保留新函数和
之前的子轴状态。原始参数、NaN 回退、别名及绘制时替换的验证见
[次轴函数替换](../testdata/secondary_functions_README.md)。本入口接受两个非抛错 Double
回调；用户 Transform 对象及通用向量回调仍按后续切片推进。

D42 增加数值位置 `SecondaryAxisLocation::Position(Double)`、`set_location` 和
`set_alignment`。`location()` 返回原始命名或数值位置，`position()` 返回归一化位置，
`alignment()` 返回独立的 `SecondaryAxisAlignment`。构造时，小于 0.5 的位置选择底部或
左侧，其余选择顶部或右侧；之后移动位置会保留已选方向，显式对齐不会移动坐标轴。
位置允许超出 `[0,1]`，也在接收时保留 NaN/Inf；实际几何到 aspect/draw 阶段才更新。

次轴保存自己的原始框和当前框，短格式、刻度空间和 SVG 从同一份几何派生。完整 SVG
绘制在父 scale 名称重置后再次执行定位和范围同步，随后捕获本轴的框与对齐用于输出。
直接 `apply_aspect()` 会恢复构造时的原始框；`prepare_draw()` 保留较早的数值准备阶段。
具体原源记录、浮点运算顺序和验证状态见
[次轴位置与对齐](../testdata/secondary_position_README.md)。通用位置 Transform 图、任意回调改变
父面板布局、完整 Tick/Text 图元及非有限位置的完整 SVG 行为仍有独立边界。

D43 为 Axes、Figure 和 pyplot 的次轴创建入口，以及 `set_location`，增加可选的
`transform : Affine2D?`。传入 `Some(affine)` 时，x 次轴使用该仿射的 y 分量，y 次轴使用
x 分量，另一方向仍沿父面板；仿射输出使用显示坐标。省略参数或传 `None` 会清除此前
设置的仿射，恢复父面板归一化坐标。

该入口对应原版直接 Affine2D 的分离条件：两个非对角分量都必须为零，包括当前方向未
使用的分量。负缩放和零缩放可以使用，也不要求逆变换。更新时先保存合法的请求位置，
再检查仿射；检查失败会保留新请求位置和旧 locator，后续定位继续使用旧位置与旧仿射。
一次定位开始后，回调安装的新 locator 留给后续定位。具体参考和验证状态见
[次轴位置仿射](../testdata/secondary_transform_README.md)。这里使用不可变仿射值；原版可变
Transform 别名、通用或非线性变换图仍有独立边界。

D44 增加稳定的 `Line2D` 数据句柄及 `LineData::Numeric` / `Category` / `Date`。
Axes、Figure 和 pyplot 的 `plot_line` 返回句柄，初次绘制沿用现有等长输入与单位设置合同。
setter 复制输入并延迟转换，原始 getter 借用保存的数组；处理后 getter 返回可写的
`TickValues`。每次成功重算安装新缓存，旧视图仍指向旧缓存；顺序读取 x、y 时可能取得
两代视图。单坐标 getter 只检查自身的失效标志。

```moonbit nocheck
let fig = @mathplotlib.figure()
let line = fig.plot_line(
  @mathplotlib.LineData::Numeric([0.0, 1.0]),
  @mathplotlib.LineData::Numeric([2.0, 3.0]),
)
line.set_ydata(@mathplotlib.LineData::Numeric([4.0, 6.0]))
fig.axes().relim_checked()
fig.axes().autoscale_view()
let svg = fig.to_svg_checked()
```

数据修改、getter 与重算不会自动更新 dataLim 或请求范围更新，显式 `relim_checked`
逐图元更新范围并保留晚失败前已经合并的部分。SVG 到实际 Line 绘制前才准备最新数据，
正常完成该 Line 后清除其 stale；保留的 IR 使用原句柄。clear 会解除旧句柄的 Axes
绑定，旧缓存和借用视图仍可使用。正式原源记录、错误与宿主边界见
[Line 数据与缓存](../testdata/line_data_README.md)。完整 Artist 属性、通用 Path、动态 Python
容器与 GUI 回调协议仍有独立边界。

D45 增加 `Line2D::remove()`。它删除对应图元并解除单位转换的 Axes 绑定，保留原始数据、
借用视图、缓存及 Line 自身的 stale。范围、图例和容器快照独立保留，需要更新范围时调用
`relim_checked()`。重复移除会返回原版的 ValueError；clear 则禁用仍附着 Line 的移除绑定，
旧句柄再移除会返回 NotImplementedError。已经移除的 Line 不受之后的 clear 影响。
从 Figure 删除 Axes 不会清空它的 Line，保留的句柄仍可正常移除。

```moonbit nocheck
line.remove()
fig.axes().relim_checked()
fig.axes().autoscale_view()
```

新导出的 IR 排除已移除图元，之前导出的 IR 继续持有原句柄。精确错误、原源记录与
图形宿主边界见 [Line 移除生命周期](../testdata/line_remove_README.md)。

D46 增加 `Line2D::get_visible()` 和 `set_visible(Bool)`。初始可见；只有值发生变化才
标记 Line stale，同值设置保持原状态。隐藏绘制在转换数据前返回，因此待处理的形状或
单位错误会保留到重新显示后的绘制。隐藏返回不清 stale；可见 Line 正常完成才清除它，
包括空数据或全部非有限点的情况。

```moonbit nocheck
line.set_visible(false)
let hidden_svg = fig.to_svg_checked()
line.set_visible(true)
let visible_svg = fig.to_svg_checked()
```

隐藏不修改数据、范围或自动范围请求；显式 getter、单位更新及默认 relim 仍处理该 Line。
已导出的 IR 在到达 Line 绘制阶段时读取当前可见性。原源记录与 leaf-draw 宿主边界见
[Line 可见性](../testdata/line_visible_README.md)。

D47 为 `Axes::relim` 和 `relim_checked` 增加可选的 `visible_only`，默认为 false。
传 true 时，隐藏的稳定 Line 会在数据转换与范围合并之前跳过；默认仍包含隐藏 Line。
全部隐藏时，原始范围变为空范围，之前的最小正值元数据保留。晚失败依旧保留先前已合并
的可见图元范围，不回滚整个调用。

```moonbit nocheck
fig.axes().relim_checked(visible_only=true)
fig.axes().autoscale_view()
```

relim 本身不请求自动范围、不改变 viewport 或 auto-enable；单位更新仍强制回算每条
Line 并使用默认 relim。尚无可变可见性的独立图元沿用可见默认。复现与边界见
[按可见性重算范围](../testdata/relim_visible_README.md)。


D48 增加 `Line2D::get_linewidth()` 和 `set_linewidth(Double)`，保留初始宽度 2 的便利
构造。setter 接受负数与非有限值，不改变数据、范围、可见性或自动范围请求；只有 IEEE
比较不相等时才置 stale，但总保存传入值。因此正零改成负零保留符号且不置 stale，重复
NaN 则仍置 stale。

```moonbit nocheck
line.set_linewidth(3.25)
let width = line.get_linewidth()
let svg = fig.to_svg_checked()
```

保留的 IR 到达实际 Line 绘制阶段时一起读取当前点和样式，已写出的前一条 Line 不受
后续回调追溯修改。`Axes::artists()` 返回当前不可变样式快照，并保留原几何查询的延迟
转换边界；以前返回的样式快照保持原值。现有 SVG 数字格式继续使用便利 profile，原版
零宽省略 stroke、宽度 1 省略属性和固定六位格式仍是独立原源证据。marker 样式与通用
Artist 样式系统仍有缺项；虚线后续由 D51 接通，详见 [Line 线宽](../testdata/line_width_README.md)。


D49 增加 `Line2D::get_color()` 和会报告错误的 `set_color(String)`。setter 先按原版
String 规则验证，再保存原字符串；重复设置同一合法颜色也会标记 stale。支持完整固定
名称表、短颜色名、四种十六进制形式、Python 灰度字符串、`none` 和 `C…`。失败保留
旧样式与 stale，不转换待处理数据，不消耗 Axes 自动颜色。

```moonbit nocheck
line.set_color("tab:blue")
let raw = line.get_color() // "tab:blue"
let svg = fig.to_svg_checked()
```

`get_color()` 和 `Axes::artists()` 保留原拼写，绘制时才派生 CSS。`C…` 在非空可见 Line
绘制时读取当前全局颜色配置，独立于 Axes 的自动颜色游标；超出固定 Python 整数位数
限制的 token 此时才报错。隐藏跳过数据和颜色准备，空 Line 正常完成且不解析颜色，
非空的全非有限数据仍会解析。原有绘图入口保留 CSS 便利合同，因此旧入口允许的
`transparent` 与显式 setter 的原版验证不同。SVG 沿用现有 RGBA-to-CSS profile；完整
原源记录、名称表与宿主边界见 [Line 字符串颜色](../testdata/line_color_README.md)。


D50 增加 `Line2D::get_alpha()->Double?` 和 `set_alpha(Double?)`。None 保留颜色自带的
透明度，Some 值须在 [0,1] 内；NaN、无穷或越界输入会在修改状态前报错。与线宽不同，
相等 alpha 完全不重新赋值，因此正零改成负零也会保留原来的符号。颜色和线宽修改
都会保留当前 alpha，旧不可变样式快照也保持原值。

```moonbit nocheck
line.set_alpha(Some(0.5))
let alpha = line.get_alpha()
line.set_alpha(None)
```

显式 source color 的 alpha 覆盖颜色内嵌值，`none` 及 C token 选中的 `none` 仍为零。
旧 CSS 便利入口使用单独的 Line stroke-opacity 组合，可能与 CSS 自带 alpha 相乘。
`Style::line_alpha()` 与工厂参数只用于 Line stroke，其他图元继续保持原合同。
alpha0 仍执行数据和颜色准备；隐藏/空 Line 的阶段保持各自规则。原源记录、私有颜色
缓存的符号边界和渲染 profile 见 [Line 透明度](../testdata/line_alpha_README.md)。

D51 增加 `Line2D::get_linestyle()` 和 `set_linestyle(String)`。支持 `solid`、`dashed`、
`dashdot`、`dotted` 及其短拼写，getter 返回 `-`、`--`、`-.`、`:`；`none`、`None`、
空字符串和单个空格统一返回 `None`。合法重复设置仍标记 stale，非法拼写先报错并
保留旧状态。`None` 跳过线条及颜色准备，仍会更新数据并报告数据错误。

```moonbit nocheck
line.set_linestyle("dashed")
line.set_linewidth(3.0)
let canonical = line.get_linestyle() // "--"
let svg = fig.to_svg_checked()
```

`config` 的 `lines_dashed_pattern`、`lines_dashdot_pattern`、`lines_dotted_pattern`
及对应 setter 管理复制的模板，`lines_scale_dashes` 管理是否按线宽缩放。线型 setter
捕获当前模板；后续修改模板不会改变已安装的线。线宽 setter 每次从已捕获模板重算，
包括同值线宽，并读取当前缩放开关。SVG 使用已算好的 dasharray/offset，不再次缩放。
`Style::line_stroke()` 返回不可变的当前载荷，序列查询返回副本；低层 `line_stroke`
工厂供静态 Line 外观传输，不重建 Line2D 的 setter 历史。其他图元不消费此字段。
负数和全零虚线序列在实际绘制的 GC 阶段校验；完整原源、数值与 SVG 边界见
[Line 线型](../testdata/line_style_README.md)。

D52 增加 `Line2D::get_drawstyle()`、`set_drawstyle(String)` 和
`path_values_checked()`。支持 `default`、`steps-pre`、`steps-mid`、`steps-post`
及 `steps`；`steps` 采用 pre 的几何，getter 仍保留 `steps`。相同字符串不改变状态，
不同字符串标记 x 待重算及 stale，数据转换与路径展开延迟到后续查询或绘制。

```moonbit nocheck
line.set_drawstyle("steps-mid")
let samples = line.xy_values_checked() // 原点数，交错 x/y
let vertices = line.path_values_checked() // 展开的绘图路径，交错 x/y
let svg = fig.to_svg_checked()
```

路径查询借用当前 Float64 缓存。默认路径与处理后 xy 共享存储，阶梯路径保留独立的
展开结果；修改借用的 xy 不会自动刷新已缓存的阶梯路径。显式强制 recache 会按原始
输入建立新缓存代，旧借用视图保持旧代。绘制和 relim 使用同一条缓存路径，数据查询
保持未展开的点数。该接口是数值路径顶点桥，不等于通用 Path/codes/marker 系统；
完整来源、别名和数值边界见 [Line 阶梯路径](../testdata/line_drawstyle_README.md)。

D53 增加 `Line2D::get_gapcolor()`、`set_gapcolor(String?)` 与 `is_dashed()`。
间隙颜色保留原始字符串；`None` 清除，`Some("none")` 是透明颜色。每次合法设置都会
标记 stale，包括重复设置，非法颜色保留全部旧状态。`is_dashed()` 只查询当前线型。

```moonbit nocheck
line.set_linestyle("dashed")
line.set_gapcolor(Some("tab:orange"))
line.set_color("tab:blue")
let svg = fig.to_svg_checked()
```

可见、非空、正线宽的虚线先绘制反向虚线及间隙色，再解析并绘制前景色。两笔共用
缓存路径，透明度覆盖内嵌 alpha；透明间隙仍执行校验和绘制。后续前景错误保留先前
写入且不清除 stale。原始颜色与 `C0` 等 token 延迟到各自绘制阶段解析。
`Style::line_gapcolor()` 和工厂参数传输原始元数据；低层静态 Style 不自动展开两笔。
完整来源、错误顺序和渲染边界见 [Line 间隙色](../testdata/line_gapcolor_README.md)。

D54 增加 `Line2D::set_dashes(Array[Double])`，把调用时的数值序列保存为快照，对应
原接口的不可变 tuple 输入。空序列恢复实线，非空序列安装自定义虚线并返回 `--`；
每次调用都会标记 stale。修改传入数组不会改变已安装的线或其后续线宽重算。

```moonbit nocheck
line.set_dashes([5.0, 2.0, 1.0, 2.0])
line.set_gapcolor(Some("tab:orange"))
let svg = fig.to_svg_checked()
line.set_dashes([]) // 恢复实线
```

自定义序列使用当前线宽和缩放开关，不读取全局虚线模板；后续线宽 setter 重算已
捕获的序列，String 线型 setter 则重新捕获全局模板。奇数长度、NaN、Inf、负数和
全零输入不在 setter 提前拒绝，绘制沿用已有 GC 校验。原生可变 list 的借用语义
及 `(None, None)` 不在此数值快照接口内。来源与完整边界见
[Line 自定义虚线](../testdata/line_dashes_README.md)。
