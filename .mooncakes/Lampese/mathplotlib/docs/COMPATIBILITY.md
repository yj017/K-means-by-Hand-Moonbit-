# Matplotlib v3.11.2 兼容性清单

当前产品能力与验收范围见 [CAPABILITIES.md](CAPABILITIES.md)，四个大目标见 [现行路线图](MIGRATION_PLAN.md)。
本文件保留细粒度 API 行为参考；其中“计划”不自动加入当前交付范围。

这份清单记录 MoonBit 端的真实状态。只有有对应实现和测试的条目才能标记为“已实现”；计划中的条目不能当作已支持能力。

当前目标是实用、逐步迭代的 MoonBit 画图库。本文件保留 Matplotlib 接口对照和技术边界，未对齐的原生接口不自动成为产品交付前提。历史公开 API 等权指数约7%，仅作接口研究参考，不能表示画图库整体完成率；详见[MIGRATION_PROGRESS.md](MIGRATION_PROGRESS.md)。

MoonBit 工具链映射：Matplotlib 的 `extend` 参数/属性在 MoonBit 端统一称为
`extend_mode`，用于 `boundary_norm`、`contourf`、`tricontourf` 及返回对象；
默认值与 `neither`/`min`/`max`/`both` 语义不变（`extend` 已是 MoonBit 关键字）。

状态含义：

- **原型**：当前仓库有最小实现，但 API 或语义尚未冻结。
- **设计中**：已确定包边界，正在提取上游签名和测试。
- **计划**：属于 v3.11.2 目标，但尚未开始实现。
- **native**：需要 native FFI 或系统库。
- **宿主**：需要 JS、GUI、Web 或 Notebook 宿主。

## 当前已实现的原型

| matplotlib 概念 | MoonBit 入口 | 状态 | 说明 |
| --- | --- | --- | --- |
| 点数据 | `@mathplotlib.point` / `Point` | 原型 | 已拆到 `core` 包 |
| 显式范围 | `@mathplotlib.bounds` / `Bounds` | 原型 | 自动范围支持默认 5% 边距、显式 x/y margin 和显式范围优先 |
| 基础样式 | `@mathplotlib.style` / `Style` | 原型 | 颜色和宽度的最小子集 |
| 掩码数据 | `MaskedArray`, `MaskedMatrix`, `masked_array`, `masked_matrix` | 原型 | 显式值/掩码复制、形状校验、压缩/填充值、掩码传播和有限值提取；错误为 `MaskError` |
| Figure | `@mathplotlib.figure` / `Figure` | 原型 | 类型和生命周期已移到 `scene`；支持独立多 Axes 面板和 SVG 渲染 |
| 折线 | `Figure::plot` / `Figure::line` | 原型 | SVG 输出 |
| 散点 | `Figure::scatter` | 原型 | SVG 输出 |
| 柱状图 | `Figure::bar` | 原型 | SVG 输出 |
| SVG 文档 | `Figure::to_svg` | 原型 | 编码已移到 `backend/svg`，通过 `internal/render` IR 连接 |

## 核心对象和数值层

| 上游模块/对象 | 目标 MoonBit 包 | 状态 |
| --- | --- | --- |
| `matplotlib.typing` | `core` | 设计中 |
| `numpy` 数组输入语义 | `core/array` | 设计中 |
| `matplotlib.transforms` | `transforms` | 原型；Affine2D 的平移、缩放、旋转、错切、复合和逆变换，BBox 的范围、相交、并集、布局操作和变换树（bbox/blended/scaled translation） |
| `matplotlib.path` / `bezier` | `transforms` | 原型；Path 的 Move/Line/Curve/Close 基础模型、曲线点包含、包围盒内部极值和矩形内外裁剪，Bezier 二次/三次求值、分割、采样；完整非仿射变换、动态失效传播和全部 Path 细节仍待迁移 |
| `matplotlib.colors` | `core/colors` | 原型；RGBA、基础命名色、十六进制色、`Normalize`、`LogNorm`、`SymLogNorm`、`TwoSlopeNorm`、`PowerNorm`、`CenteredNorm`、支持扩展 bin/clip 的 `BoundaryNorm`、离散 `ListedColormap` 以及 under/over/bad 色彩 |
| `matplotlib.cm` | `core/colors` | 原型；灰度、viridis、plasma、inferno、magma、cividis 和自定义分段色图 |
| `matplotlib.scale` | `ticker/scale` | 原型；D35五种typed几何的显式Axis/Axes默认安装已验收：真实四对象/四flags、同值重装与rc捕获、共享holder/组顺序/删除后alias；详细验证与接口变化见[默认安装](../testdata/scale_defaults_README.md)。D36构造/Axis与Axes clear的默认生命周期已验收（共享组/target/晚错误/provider，见[说明](../testdata/initial_clear_README.md)）；D37–D40已接通数值autoscale、内建单位与secondary默认/独立视图；任意registry、通用Transform及完整动态绘制仍待迁移；D27最小Logit mask/clip几何及共享source limiter已验收，域外artist clip路径与完整tight/default生命周期仍待迁移；D26最小Asinh几何与独立便利sampler已验收，构造/clear默认locator/formatter安装由D36承接；线性/十进制对数和对称对数（symlog）变换、逆变换、有效值检查和主刻度生成；D25修正SymLog私有数值体为源分开ln/exp运算顺序以避免中间比值overflow，便利factory旧默认/验证保持 |
| `matplotlib.ticker` | `ticker` | 原型；D34命名 `LogitFormatter` 已验收：raw参数、独立dtype快照、浅复制共享可变标签集、原scalar身份、精确CPython tuple排序与set探测、NumPy Object距离排序和实际Axis管线均已对齐；123注册测试承载3779案例，四目标累计验证与六源检查通过。原始源期望保持，NaN地址哈希等宿主边界见[LogitFormatter](../testdata/logit_formatter_README.md)；D33命名 `LogFormatter`/`LogFormatterExponent`/`LogFormatterMathtext`/`LogFormatterSciNotation` 已验收：raw参数/immutable默认tuple与借用view、完整逻辑arange/geomspace缓存、分阶段数值/独立call/data/short、当前实际transform的linthresh与真实Axis/shared/secondary接线。新增152注册测试承载4557案例，四目标及四新source检查全过，exacthalf下溢另经四目标补验；数学/文本转换与宿主边界见[LogFormatter家族](../testdata/log_formatter_README.md)；D32命名 `EngFormatter` 已验收：live Scalar继承、raw精度与动态class/instance前缀表、数字hash/probe/复制、原NumPy clip/舍入、checked full batch与lateoffset均已接线；新增62注册测试承载1740验证案例（含99条共6200步字典轨迹），四目标及五新原源检查全过。NaN hash0/原地址hash与数值/宿主边界详见[EngFormatter](../testdata/eng_formatter_README.md)；D31命名 `ScalarFormatter` 已验收；原始数值/借用powerlimits与rc捕获、浅复制、分阶段checked准备、全数组精度、Python/NumPy舍入和独立call/data/short/offset，显式 `NumericLocale` 原regex/分组/tuple阶段、SVG72实际像素短格式、secondary constructor/direct/frame与late offset（含NullLocator）已接线。新增1685注册测试承载5706细分案例，四目标及五新原源检查全过；portable数学/affine inverse、空字体目录profile与资源/宿主边界见 [ScalarFormatter](../testdata/scalar_formatter_README.md)；完整默认安装/GUI/Text/TeX及OS字体/locale发现仍待迁移。D30命名 `PercentFormatter` 已验收，新增2293tests、三新source与四目标全过；保raw参数/晚精度转换、整数/浮点/NumPy范围、每值liveview、动态符号、shared与secondary constructor/aspect/defaultframe时序，详见[百分比Formatter](../testdata/percent_formatter_README.md)；D29命名 `FormatStrFormatter`/`StrMethodFormatter` 已验收，新增5161tests、六新source与四目标全过；checked原错误/可变fmt/浅copy、PythonFloat与NumPy Float64/Int64类型、精确整数和嵌套字段负号，以及主次/secondary筛选保dtype详见[字符串Formatter](../testdata/string_formatter_README.md)；旧pure便利helper行为保留；D28命名基础 `BaseFormatter`/`NullFormatter`/`FixedFormatter`/`FuncFormatter` 与独立checked主次/secondary接线已验收，新增352tests、三source与四目标全过；保借用view/动态Array、pos、重入与原Core错误，旧纯helper接口保留；D27命名 `LogitLocator` 已验收，新增879tests、四目标与三source检查全过，raw重复/局部MaxN回退/源context与范围顺序见[Logit](../testdata/logit_locator_README.md)；D26命名 `AsinhLocator` 已验收，新增1061tests及四目标/四source检查全过；typed参数、完整shape和portable数学profile见[Asinh](../testdata/asinh_locator_README.md)；D25已验收命名 `SymmetricalLogLocator`、原Float64完整arange反转与零展开、Int64 subs alias、raw transformed overlap、shared/secondary/checked Scene/SVG；原源及四目标证据见[SymLog](../testdata/symlog_locator_README.md)。D24已验收命名 `LogLocator` 参数、dtype网格、主次/secondary、local/shared minpos与checked自动范围；新整数pow/decade ln采用可移植正确舍入，已知Darwin非正确round差异保留双值证据，四目标与五原源检查通过，见[LogLocator](../testdata/log_locator_README.md)。D23 已验收命名 `AutoMinorLocator`/`NullLocator`，保留首次x/y rc捕获、整数major unique/wrapped diff、任意精度round与arange dtype、last-owner四provider、axis transformed overlap/raw邻接点、secondary自身minor与Null主次独立跳过格式化；原源及四目标证据见 [AutoMinor/Null](../testdata/auto_minor_locator_README.md)。D22 已验收的命名 `MaxNLocator`/`AutoLocator` 提供MaxNBins固定/Auto预算、真实Float64/Int64 steps view与extended snapshot、经典默认整数buffer截断写入/视图拷贝类型、逐项失败状态/None三态、完整nticks及prune-before-cap/真实view端点、大offset Edge、classic构造捕获、checked live adapters与SVG实际尺寸/字号预算；Fixed的Int64精确phase/环绕abs、固定dpi72 profile及四目标验收详见 [MaxN/Auto](../testdata/maxn_locator_README.md)。D21 已验收的命名 `LinearLocator`/`IndexLocator`/`FixedLocator` 保留原数量/preset、NumPy linspace/arange、固定位置/stride/NaN/alias、live主次adapter和checked错误协议；mutable signed/nested/0stride `TickValues`、Fixed.from_view/LinearPresets.set_view/get别名、固定Darwin NumPy FMA profile与真实Index data interval/删除后重绑/secondary空数据及checked轴/SVG接线详见 [命名数值定位器](../testdata/named_numeric_locator_README.md)，四目标与原源验收记录见检查点；原始log数据与Grouper登记/删除顺序已对齐，完整dataLim缓存窗口/relim仍待迁移。已支持 typed `MultipleLocator` 提供有限正Double base/有限offset、validate-before-update、独立对象copy、live主次adapter、原源升序邻接点与generic方向/错误映射、data/round_numbers动态rc view_limits及axis margin/sticky接线；验收证据见检查点，精确范围见 [固定间隔参考](../testdata/multiple_locator_README.md)。已有确定性线性/对数刻度和值标签；MaxN 风格的 nice step、integer/symmetric/prune 选项、LogLocator 的 `subs`/`numdecs` 和自动/固定/对数 minor locator；numeric locator 已可接入 `scene/axis` 与 pyplot；Scalar、Fixed、printf Format、Eng、Percent、Log、Null、函数 formatter 已接入轴和 SVG；Scalar 使用统一布局计算 offset、科学倍率、精度和 viewport，Eng/Percent 边界与自动精度已覆盖，mathtext 使用后端中立的乘号/上标表示；LogFormatter 默认返回数值标签，`label_only_base` 仅过滤非底数幂位置。默认数值Axis构造/clear的隐式locator生命周期已由D36验收；复杂 formatter 组合和完整 mathtext 渲染仍待迁移。 |
| `matplotlib.dates` | `ticker/date` | 原型；已支持命名 `MicrosecondLocator` 的有限正Double/分数间隔、whole-array awareness/NumPy秒偏移截断、精确interval_value、原源邻接点/年界、Auto/axis/共享SVG接线，旧Int32 helper继续clip且eager最多100000；详见 [微秒参考](../testdata/microsecond_locator_README.md)；已支持 `datestr2num`/`datestrs2num` 与 typed `DateStringParser`/可注入 `DateParserContext`，固定默认dateutil语法、Unicode词法、28位Decimal时间、default填充/月末/weekday/fold、本地TZif/POSIX/采样或显式descriptor、typed未知时区诊断、NumPy首probe/mixed-aware/epoch锁定顺序及scene/pyplot链路；String/flat-array类型边界与宿主能力限制保留，未迁移动态/多维/掩码容器；已支持标准 strftime 的固定 C locale 指令（12h/AMPM、年日、Sunday/Monday week、ISO weekyear/weekday/week、c/x/X），复用本地 Gregorian 日历并以完整400年周期及原formatter逐值参考验证；任意系统locale/OS扩展和flags仍待接入；已支持 typed `DateConverter`/`ConciseDateConverter`、复制隔离的 `DateAxisInfo`、首个日期单位推断与 scalar/flat-array 转换、`date.converter` auto/concise 配置；默认轴首次捕获，shared/scene/pyplot/SVG 与空 plot_date 已接线，保留固定上游 concise 构造的 multiples 覆盖行为；已有 DateTime 无 naive 标记，通用动态 units registry/NumPy masked 数组仍待迁移；已支持命名 `AutoDateFormatter` 的 locator 基础单位、排序 scaled 字符串/typed callable/默认回退与 rc 快照；新日期轴默认使用该格式器，主/次及数值 locator 更换后自动重绑定，日期次刻度标签/去重/可见性/共享轴/scene/pyplot/SVG 已接线；已支持完整 `AutoDateLocator` 对象的七级频率、minticks/maxticks/interval 表、日历选择与 phase、multiples 对齐、typed 诊断、动态单位和 nonsingular；默认日期轴及显式主/次 locator、scene/pyplot/SVG 已接线，旧范围 helper 保留兼容；已支持 `ConciseDateFormatter` 六级批量标签、zero/custom formats、共同小数尾零修剪、show_offset、倒置轴共享日期、scalar/cursor labels 与TeX字符串输出；普通/concise日期formatter可挂载x/y轴并通过shared axes、scene/pyplot和SVG共享offset文本接线，SVG通用TeX排版仍未接入；已支持 `get_epoch`/`set_epoch`、`config.date_epoch` fallback 与首次读取/转换锁定；ISO 原点支持年0、负年、时分秒与微秒，数值转换/时区/recurrence/locator/scene/pyplot/SVG 全链接入，自定义原点下保留相对精度修正与上游微秒原点不对称；已支持 `TimeDelta` 全范围规范化整数时长、标量/数组 `num2timedelta(s)`、`DateTime.add_timedelta`、保留规则时区的微秒级墙钟算术，以及按上游端点/linspace 算法的 `drange`（含 DST/负步长/浮点边界）；UTC Gregorian 与固定 UTC offset、微秒精度、ISO 时区后缀/小数秒解析、`%f`/`%z`/`%Z` 格式化、`DateFormatter::with_offset`、自动日期刻度，以及日/年/月/星期/时/分/秒/微秒显式定位器；多值 selector、负月日、每月第 N 个星期几、日历 recurrence、`interval` 相位、`byyearday`/`byweekno`/`byeaster`、`bysetpos`、带 `dtstart` 的 `count`/`until` 动态边界和微秒/offset SVG 标签已覆盖，`scene`/`pyplot`/SVG 已接入。新增带明确 `dtstart` 的 `RRule` 对象，支持 `locator`、`between`、`after`、`before`、`xafter`、`all`、固定 offset 复制、保留未指定字段的 `replace` 以及通过 `replace(clear=[...])` 清除 selector；`RRuleSet` 已支持多个 `RRule`/显式日期的包含、排除、UTC 顺序合并、去重和 `between`/`after`/`before`/`xafter`/`all` 查询；`business_day_locator` 已支持默认周一至周五或自定义 weekday mask、显式节假日日期、interval 和固定 offset，并已接入 scene/pyplot/SVG；新增显式 transition 时区规则，支持 `DateTime` 转换、formatter 和 scene/pyplot/SVG 标签在 transition 前后的动态 offset；显式日历/时间 locator 已按本地候选映射 UTC，spring gap 会跳过，fall fold 保留两个 instant；recurrence 也支持显式 transition 表；已支持调用方 TZif v2/v3 数据（历史秒级偏移、缩写、POSIX footer 未来规则及完整日期/SVG/recurrence 接线）；独立 `ticker/date/tzdb` 已捆绑 IANA 2026e 的 598 个标准 Zone/Link 名称与兼容别名，返回现有 DateTimeZone；已支持 RRule/RRuleSet 可选 occurrence 前缀缓存、独立原生 iter/iter_after、派生规则空缓存和 set mutator 失效/reader 快照；完整商业日历规则和更多 `dateutil.rrule` 对象语义仍待迁移；Minutely/Secondly 跨级不可达clock mask的迭代错误已在checked查询/计数对齐，新增RRuleDateIterator/checked_raw_iter的lazy next错误/终止/快照，occurrence_count补raise DateError；旧raw_iter native扩展及Python线程锁/动态代理边界见clock_iteration参考指南。locator 无匹配回退端点，对象查询返回空结果，输出上限为 100000；默认 `timezone` rc、`get_timezone`、互斥 String/typed zone 参数、num2date 动态/DateFormatter 与 locator 捕获/Auto 与 Concise 文本动态解析、显式 offset0、dateutil TZif 32-bit profile、host/POSIX/可选单名注册和轴原子错误映射已接入；完整 IANA zone 保留原64位/footer语义；Windows registry、dateutil内置bundle和宿主缩写兜底及弃用TZ语法未接入；typed `RRuleWrapper` 与边界 `RRuleDateTime` 已接入 timezone 推断/aware→naive、分阶段set失败状态、host clock默认、None参数、ordinal weekday、缓存/raw stream/count/typed copy和无epoch查询；named `RRuleLocator` 通过calendar扩展/update/shared wrapper接入主次轴/动态单位/自定义epoch/无Node/shared inverted SVG；命名 `MonthLocator`/`WeekdayLocator`/`DayLocator`/`HourLocator`/`MinuteLocator`/`SecondLocator` 已接入原默认/None/typed scalar-array-object、clock与Day前置验证、display rc捕获、共享rule主次轴/SVG/epoch/browser及原源参考；wrapper同级clock selector按gcd筛core并保留raw construct/阶段错误；命名 `YearLocator` 已支持冻结base年对齐、保留微秒/zone/fold、非法对齐日期错误、live scalar构造形态与原端点混合awareness回退；AutoDateLocator年倍数分支亦已接入并支持可选host context；AutoDateLocator其余recurrence分支已复用wrapper，支持原gap/fold0/duplicate coordinates并保留decoded bounds与fraction epoch转换顺序；负DST attach与fromutc双mask按dateutil原行为处理；dynamic代理/pickle/索引协议及pytz适配仍待迁移，typed范围见testdata/rrule_wrapper_README.md；typed `RelativeDelta`/weekday 对象、absolute/relative/Yday/monthend/DST应用、精确normalized、between同/异zone identity、对象加减/TimeDelta/neg/abs/scale/div/zero/Eq/immutable weeks与epoch/SVG链路已接入；年月Int64、其余relative有限Double，Python任意精度/date-only/naive动态混合及字段突变/反射协议仍待迁移 |
| `matplotlib.category` | `ticker/category` / `scene/axis` | 原型；persistent CategoryAxis 保留首次出现顺序与空字符串；D38 内建单位使用共享 live CategoryUnits，追加保用户四槽、整数 formatter 来源和真实类别范围；D39 已保留 Line 原始坐标并支持类别单位重排回算，缺项追加、数值来源绕过与晚失败状态保留，见 testdata/line_units_README.md |
| `matplotlib.axes.prop_cycle` | `scene.Figure` / `Axes::set_color_cycle` / `set_prop_cycle` | 原型；默认 tab10，基础曲线、参考线/跨度、annotation/arrow、spy、contour/tricontour/triplot、streamplot、violinplot、quiverkey 等单色入口共享循环；显式颜色覆盖且不推进循环，循环项校验 |
| `matplotlib.rcsetup` / `rcParams` | `config` | 原型；全局 tab10、x/y autoscale margin 和新 axes 的 major grid 默认值；D20 增加 `axes_autolimit_mode` 的 data/round_numbers 验证、默认data、复制/reset/getter，供 MultipleLocator 每次 view_limits 动态读取；D22增加classic_mode Bool、默认false与rc快照/reset，AutoLocator构造捕获；D23增加x/y minor_tick_divisions的Text/Number/Integer(BigInt)、默认auto、非负整数rc验证与原大小写token/快照/reset，AutoMinor首次有效查询捕获；MaxN/Auto继续每次读取autolimit；其他 rcParams 仍待迁移 |

## Figure、Axes 和图元

| 上游模块/对象 | 目标 MoonBit 包 | 状态 |
| --- | --- | --- |
| `Artist` | `scene/artist` | 原型 |
| `Figure` / `SubFigure` | `scene/figure` | 原型；Figure 支持规则 `subplots`、独立归一化矩形 `add_axes`（允许零尺寸和越界矩形，拒绝负值/非有限值）、`GridSpec` 共享轴约束和 `subplots_with_grid`，`subplots_adjust` 可更新 bounds 与间距并即时反映到已有 Axes；新增 `delaxes` 与独立于绘制顺序的 `gca`/`sca` 选择历史，删除末面板后允许空 Figure 并延迟重建；SubFigure 支持父 GridSpec 跨度、嵌套 `subplots`、标题、`clear`、句柄共享、直接成员 `delaxes` 和 SVG 渲染 |
| `Axes` / `_AxesBase` | `scene/axes` | 原型；每个 Axes 独立持有图元、范围、标签和标题，并可挂载多个次坐标轴；支持 axis decorations 的 on/off 和 clear；位置支持归一化 `get_position(original=...)`、四参数 `set_position(..., which=...)` 和 `reset_position`，auto/equal/numeric 与 SVG 共用范围和矩形计算；`set_aspect` 接受正有限 y/x 比例，`get_aspect` 返回 None(auto)/Some(ratio)，`share` 更新直接共享组并集，支持 transformed spans 与流线箭头显示尺寸；`Anchor::Named`/`Fraction`、`set_anchor`/`get_anchor` 及 `set_aspect(anchor=...)` 支持 compass/有限 tuple（含越界）锚定和 share，clear 保留锚点；允许零尺寸和越界，非法位置原子拒绝。`remove` 同步清理 Figure/SubFigure 列表并隔离共享轴，旧句柄保留数据与来源 Figure，重复/外部移除原子拒绝；GridSpec 手动覆盖在下次 `subplots_adjust` 时恢复；`set/get_adjustable` 与 `set_aspect(adjustable=...)` 支持 box/datalim，`apply_aspect` 和 checked SVG 同步实际视图，自动/显式选择及方向保留；共享 x/y 仅调整非共享轴，numeric datalim 两轴共享在 setter 提前拒绝；原非抛错 getter 失败返回 None，`to_svg_checked` 返回 DataError。固定范围覆盖不提供 Python 日志警告；`set/get_box_aspect` 支持正有限物理高/宽比和省参清除，设置时选择 datalim，清除保留模式；auto 仅缩框并允许两轴共享，numeric 先缩框再调视图，box 模式 numeric 优先，支持 anchor/动态网格/图像/流线单位；locator、twins、自动布局和 SubFigure 局部坐标仍待迁移 |
| `Axis` / `XAxis` / `YAxis` | `scene/axis` | 原型；范围、线性/对数/日期刻度、固定刻度、自定义标签、类别刻度、numeric major/minor locator 和 major/minor grid 可见性/样式；Axes 自动范围支持 x/y margins；D20 SVG 主次/secondary 刻度按变换后的view及上游1e-10容差筛选绘制，先保留完整刻度做formatter布局，direct tick_values仍返回邻接点；D38 四槽独立 Date/Category 单位默认安装、共享单位/回调与 checked 日期查询已验收，见[单位接线](../testdata/units_lifecycle_README.md) |
| `GridSpec` / `SubplotSpec` | `scene/gridspec` | GridSpec 原型；支持规则网格、`none`/`all`/`row`/`column` 共享轴、共享范围/刻度传播、外侧主刻度标签布局、可动态更新的 `hspace`/`vspace`、`width_ratios`/`height_ratios`、跨行列与嵌套 SubplotSpec、负行主序索引和 `Figure::add_subplot`；未显式设置的网格间距可继承 Figure 的 `wspace`/`hspace`，显式 GridSpec 间距优先 |
| `Line2D` / `AxLine` | `scene/lines` | D44 已验收稳定 Line2D 数据句柄、LineData 原始数组、lazy setter/getter、可写 TickValues 与每代缓存别名；Axes/Figure/pyplot.plot_line 返回句柄，checked relim 与 late SVG draw 已接通。D45 已验收 remove 的稳定身份删除、clear 后不同错误与 delaxes 后保留所属 Axes，不自动重算范围或删除静态图例。D46 已接通 get_visible/set_visible 的同值 no-op、hidden 转换前早退与完成后 stale。D47 两个 relim 入口已增加可选 visible_only，默认包含隐藏 Line，true 在转换和合并前过滤。D48 已验收 get/set_linewidth、IEEE 比较 stale 与无条件值保存，保留 IR 的当前样式和 artists 样式快照已接通；现 SVG 数字格式仍是便利 profile。D49 已验收 get/set_color(String)、完整固定名称表与原 String 验证、raw 快照及全局 C token 晚解析；旧 plot CSS 便利入口保留。D50 已验收 get/set_alpha(Double?)、相等不赋值及原始零符号，source 颜色 alpha 覆盖和 Line-only opacity 已接通。初次输入沿用等长便利合同；完整 Artist 属性/Path、AxLine 对象与通用图形协议仍待迁移，见 testdata/line_data_README.md |
| `Patch` / `Rectangle` / `Polygon` | `scene/patches` | 原型；Bar、BarH、FillBetween |
| `Collection` / `PathCollection` | `scene/collections` | 原型；`PathCollection` 支持散点颜色/大小广播、复制语义、自动范围和 SVG 圆点渲染 |
| `BoxStats` / `boxplot` | `scene/boxplot` | 原型；分位数、IQR 须线、离群点和 SVG 竖直/水平箱线图 |
| `Text` / `Annotation` | `scene/text` | `Text` 原型；`annotate`/`arrow` 原型，支持数据坐标、`axes fraction`/`figure fraction`、SVG `display`、`offset points`/`offset pixels`、偏移、箭头、`fontsize` 以及 `straight`/`arc3`/`angle` 连接器；复合 transform、完整连接器参数和富文本仍待迁移 |
| `Image` / `AxesImage` | `scene/image`, `scene/image_color`, `scene/masked_image` | 原型；二维标量图、RGB/RGBA 图像、vmin/vmax、`Normalize`/`LogNorm`/`SymLogNorm`/`TwoSlopeNorm`/`PowerNorm`/`CenteredNorm`、命名色图、非有限像素、`imshow_masked`、`origin=upper/lower`、允许反向边界的有限 `extent`、`aspect=equal/auto`、SVG 像素网格、立即贴合图像范围、自动缩放时的图像 sticky edges 和共享轴方向传播；RGB(A) 支持 typed `Rgb`/`Rgba`、三/四通道数组、全局 alpha、有限越界通道裁剪和无效像素透明；`interpolation="nearest"` 使用像素矩形，`interpolation="none"` 在线性坐标 SVG 轴上嵌入原始分辨率 RGBA PNG，`interpolation="bilinear"`、`"bicubic"`、`"spline16"`、`"spline36"`、`"hanning"`、`"hamming"`、`"hermite"`、`"kaiser"`、`"quadric"`、`"catrom"`、`"gaussian"`、`"bessel"`、`"mitchell"`、`"sinc"`、`"lanczos"` 和 `"blackman"` 使用对应的中心对齐预乘 alpha 核，`interpolation="auto"`/`"antialiased"` 按显示倍率在最近邻和 Hanning 之间选择；过滤模式在线性 SVG 轴上生成显示尺寸 PNG，非线性坐标自动回退到像素矩形 |
| `Table` | `scene/table` | 原型；支持文本/颜色矩阵、行列标签、单元格对齐、归一化 bbox、位置和边框模式，SVG 绘制 |
| `Legend` / handlers | `scene/legend` | 原型；显式条目、带 `label` 的自动条目、同名去重、线/点/色块样本和 SVG 绘制 |
| `Axes.margins` / `set_xmargin` / `set_ymargin` | `scene` / `pyplot` | D37 已验收：margin/tight 是每个 Axes 的状态；支持大于 -0.5 的值以及上游允许的 NaN/+Inf，变换后非有限 padding 归零，共享视窗由读取者发起计算 |
| `Axes.autoscale_view` / `pyplot.autoscale` | `scene` / `pyplot` | D37 已验收：独立 auto-enable、stored viewport、stale 和 per-Axes tight；autoscale_view 不 enable、不清 margin；autoscale 接受 enable=True/False/None 并请求 lazy 更新，只有 tight=True 会归零 margin；五种 numeric scale 与实际 locator 共享 checked 范围链，保真实成员、空 mutated view、方向、失败 partial；relim/dataLim 缓存与图像 attach 顺序已接入。D38 Date/Category 也已进入同一状态与范围链；D40已接入secondary自身空数据autoscale与独立视图；任意 Artist/provenance sticky、collection 添加前 unstale 仍后续，详见 testdata/autoscale_README.md |
| `Colorbar` | `scene/colorbar` | 原型；线性/对数规范化、竖直/水平渐变条、刻度和标签，SVG 输出 |
| `Container` 类型 | `scene/container` | 原型；`Axes`/`Figure` 可读取复合绘图调用生成的 artist 分组、类型和标签，支持 bar/barh/hist、errorbar、boxplot、stem、contour/tricontour、quiver、violin/violinplot、pie、streamplot、stackplot，并在 clear 时同步清空 |
| `Spine` | `scene/spines` | 原型；四条标准 spine 可读取/设置可见性、颜色、线宽、`Axes`/`Data`/`Outward` 位置和数据 bounds，SVG 后端按 side 渲染 |

## Axes 绘图方法

这些方法按图元和算法拆分，每一组单独实现、测试和发布：

| 方法组 | 代表方法 | 状态 |
| --- | --- | --- |
| 基础曲线 | `plot`, `plot_date`, `loglog`, `semilogx`, `semilogy` | 原型；SVG 后端支持线性、日期和基础十进制对数坐标 |
| 点和区间 | `scatter`, `errorbar`, `fill_between`, `fill_betweenx` | `fill_between`/`fill_betweenx`/`errorbar` 原型；`plot_masked`/`scatter_masked`/`fill_between_masked`/`fill_betweenx_masked` 支持显式掩码断点 |
| 阶梯和离散事件 | `step`, `stairs`, `stem`, `eventplot` | 原型；支持 pre/post/mid 阶梯、垂直/水平 stairs、填充 stairs、竖直/水平 stem 和多组事件线 |
| 条形和统计 | `bar`, `barh`, `hist`, `boxplot`, `violinplot`, `pie` | `barh`/`hist`/`pie`/`boxplot`/`violinplot` 原型；`Histogram` 暴露 counts、edges 和 bar patches；`violinplot` 支持 Gaussian KDE、Scott/Silverman/固定带宽、分位数、均值/中位数/极值线、单侧绘制和水平布局 |
| 面积和附加图元 | `fill`, `fill_between`, `stackplot`, `broken_barh`, `hist2d`, `quiverkey` | 原型；闭合多边形、堆叠面积图（zero/sym/wiggle/weighted_wiggle）、水平断续条、矩形二维直方图和数据坐标向量键已接入 scene/SVG |
| 图像和网格 | `imshow`, `pcolor`, `pcolormesh`, `matshow` | `imshow`/`pcolor`/`pcolormesh` 原型；`imshow`、masked `imshow` 和 pyplot 图像入口支持 `origin=upper/lower`、允许反向边界的有限 `extent` 及 `aspect=equal/auto`，SVG 按像素边界绘制并纳入自动数据范围，图像立即贴合范围且后续自动缩放支持 sticky edges 和共享轴方向传播；RGB(A) 已支持 typed `Rgb`/`Rgba`、三/四通道数组、全局 alpha、有限越界通道裁剪和无效像素透明；`interpolation="nearest"` 使用像素矩形，`interpolation="none"` 在线性 SVG 坐标轴上嵌入原始分辨率 PNG，`interpolation="bilinear"`、`"bicubic"`、`"spline16"`、`"spline36"`、`"hanning"`、`"hamming"`、`"hermite"`、`"kaiser"`、`"quadric"`、`"catrom"`、`"gaussian"`、`"bessel"`、`"mitchell"`、`"sinc"`、`"lanczos"` 和 `"blackman"` 使用对应的中心对齐预乘 alpha 核，`interpolation="auto"`/`"antialiased"` 按显示倍率在最近邻和 Hanning 之间选择；过滤模式在线性 SVG 坐标轴上生成显示尺寸 PNG，非线性轴回退到像素矩形，掩码和 RGB(A) 入口会转发该参数；规则网格 `pcolor`/`pcolormesh` 及 masked、显式 norm 入口支持 `antialiased` 边界控制；`pcolor_grid`/`pcolormesh_grid` 支持二维曲线坐标和 `flat`/`nearest`/`gouraud`/`auto` shading 及 `antialiased` 边界控制，Gouraud 以带顶点颜色的三角形图元编码到 SVG；`pcolor_grid_masked`/`pcolormesh_grid_masked` 支持数据与二维坐标 mask，并按单元传播；`imshow_masked` 使用 bad 色，`pcolor_masked` 省略对应多边形，`pcolormesh_masked` 使用 bad 色；网格支持显式 `ColorNorm`/`ColorMap`、BoundaryNorm 的 under/over 和 bad 色；`matshow` 使用半整数图像边界、零基整数刻度、顶部/两侧 x 刻度和等比例反向 y 轴，并转发全部 Matplotlib `interpolation` 名称；对数坐标会跳过非正网格边界 |
| 等值线 | `contour`, `contourf`, `clabel` | `contour`/`contourf`/`clabel` 原型（规则网格）；filled contour 已支持 `extend=min/max/both`，规则网格支持 `corner_mask`，`clabel` 支持代表性位置、字号和 `inline` 文字间隙；`ticker.Locator` 已支持 linear/fixed/log 自动 levels，LogLocator 支持 `subs`/`numdecs`；规则网格和三角等值线都按共享 crossing 拼接连续路径，filled band 会消除同一 band 的内部共享边并保留 mask 边界，多个边界环通过 SVG even-odd compound path 渲染孔洞；线 contour 支持按 level 循环的 `colors`/`linewidths`，`ContourSet` 提供拼接路径及 levels/layers 读取；高级 formatter 和更复杂的 locator 组合仍待迁移 |
| 向量场 | `quiver`, `barbs`, `streamplot` | `quiver`/`barbs`/`streamplot` 原型（规则网格）；`barbs_with_options` 已支持 half/full/flag 增量、rounding、flip、calm fill 和 tail/middle/tip pivot；streamplot 已支持 1D 与 meshgrid 风格二维坐标、独立 density 轴、显式起点、积分方向、长度限制、积分时断裂占据、按弧长箭头、自适应 RK12、网格 linewidth/color、显示空间箭头、常用 FancyArrowPatch 样式和 `StreamplotSet` 返回对象 |
| 统计辅助 | `acorr`, `xcorr`, `ecdf`, `hexbin`, `spy` | `acorr`/`xcorr`/`ecdf`/`hexbin`/`spy` 原型；`acorr`/`xcorr` 支持可调用 `detrend`、`detrend_none`、`detrend_mean` 和 `detrend_linear`，会校验 detrend 结果长度与有限值；`hexbin` 支持 `gridsize`、`mincnt`、`extent` 裁剪、`marginals` 边际计数柱、线性/对数/对称对数坐标空间、线性或对数色阶、`edgecolor`/`linewidth`、`values` 的 `mean`/`sum`/`min`/`max`/`count` 聚合和 `hexbin_reducer` 自定义聚合；`spy` 支持 `precision`、`markersize`、`origin`、`aspect=equal/auto` 和常用 marker 形状；置信区间、复数数值和 masked array 输入仍待迁移 |
| 几何辅助 | `axhline`, `axvline`, `axline`, `axhspan`, `axvspan`, `hlines`, `vlines` | `axhline`/`axvline`/`axline`/`axhspan`/`axvspan`/`hlines`/`vlines` 原型；这些单色入口使用 Axes 属性颜色循环，显式颜色不推进循环；`axline` 支持两点或点加斜率，线性坐标按数据范围裁剪，对数坐标的两点形式按显示空间裁剪 |
| 坐标和标注 | `text`, `annotate`, `arrow`, `secondary_xaxis`, `secondary_yaxis` | `text`/`annotate`/`arrow` 原型；`annotate` 支持数据坐标、`axes fraction`/`figure fraction`、SVG `display`、`offset points`/`offset pixels`、偏移、箭头、`fontsize` 和 `straight`/`arc3`/`angle` 连接器；次坐标轴支持多个实例、前向/逆向函数、固定刻度、独立 locator/formatter、标签、位置和 SVG 标签；D40独立默认四槽/视图、parent-name缓存、旧context范围设置与创建序/捕获placement已验收，见testdata/secondary_lifecycle_README.md；D41已接入set_functions/identity reset与同名已安装变换缓存；D42数值位置/set_location/set_alignment及完整draw第二定位阶段已验收；D43位置Affine参数已验收；通用Transform图、完整连接器参数和富文本仍待迁移 |
| 三角网格 | `Triangulation`, `triplot`, `tripcolor`, `tricontour`, `tricontourf` | `scene.triangulation`/`pyplot.triangulation` 支持显式索引或自动 Delaunay，派生唯一边、邻接和逐面 mask；`triplot_triangulation`、`tripcolor_triangulation`、`tricontour_triangulation`、`tricontourf_triangulation` 可复用网格；`Triangulation::get_trifinder`/`pyplot.get_trifinder` 支持点和批量查询，返回包含面的索引或 `-1`；三角 contour 线按共享 crossing 拼成连续 polyline，filled band 按边界消除拼成外环/孔洞环，非有限 z 值会被拒绝 |

## 后端

| 上游后端 | MoonBit 目标 | 状态 |
| --- | --- | --- |
| `backend_svg` | `backend/svg` | 原型；使用 `Milky2018/xml@0.5.0` |
| `backend_agg` | `backend/agg` | native |
| `backend_pdf` | `backend/pdf` | native |
| `backend_ps` | `backend/ps` | native |
| `backend_pgf` | `backend/pgf` | native/宿主 |
| `backend_cairo` | `backend/cairo` | native |
| `backend_webagg` | `backend/web` | 宿主 |
| `backend_nbagg` | `backend/notebook` | 宿主 |
| Qt/GTK/Tk/WX/macOS | `backend/gui/*` | 宿主 |

## 高级系统和生态

| 上游系统 | 状态 |
| --- | --- |
| `pyplot` 状态式 API | 原型；对象式绘图和对应的掩码门面（`plot_masked`, `scatter_masked`, `fill_between_masked`, `fill_betweenx_masked`, `imshow_masked`, `pcolor_masked`, `pcolormesh_masked`）已接入；常用对象命名别名、无参/显式矩形 `axes`、跨 Figure `sca`、无参/显式 `delaxes`、每 Figure 当前面板历史与删除后恢复、`grid`、`cla`、datalim 模式的 `axis("equal")`、`suptitle`/SVG `savefig`、tab10 颜色循环、spine 对象、`stackplot`、`margins`/`set_margins` 和 `subplots_adjust` 已接入；其余状态函数仍为第一版；绘图函数支持 `label` 自动图例，并可读取当前 axes 的图例条目 |
| `animation` 和 writers | 计划/宿主 |
| `widgets` 和事件 | 计划/宿主 |
| `mplot3d` | 计划 |
| `axisartist` / `axes_grid1` | 计划 |
| `style`、主题和 `rcParams` | 原型/计划 | `config` 已提供颜色循环、autoscale margin 和 major grid 默认值；完整主题、字体和其余 rcParams 仍待迁移 |
| Pillow 图像适配 | 计划/native |
| pandas/xarray 数据适配 | 计划/宿主 |
| 测试和图像比较工具 | 计划 |

D38 内建单位纵向接线已验收：42 个新增注册测试承载 90 个原源案例和 39 个定向测试，
18 个 custom-epoch 案例复用既有隔离驱动。最终四目标 nonJS21934 / JS21941 全过；
任意 Python converter/registry 与 NumPy 日期字符串语法不在 D38 内。

D39 Line 原始输入与类别单位重排已验收：18 个新增注册测试包含 19 个受控原源案例
和 17 个定向回归；完整四目标 nonJS21952 / JS21959 全过。24 个源观察中的 5 个 lazy
Line API 观察仅保留为 source-only，不冒称公开 Line2D 句柄已迁移；Scatter/生成显示线
不从原标签回算，既有显式类别配置仍保留单独合同。41 份公开接口保持不变。

D40 次坐标轴数值生命周期已验收：38新增注册测试（2正式组、36定向回归），53正式
原源观察，累计四目标nonJS21990/JS21997全覆盖。完整第二轮仅余两物理夹具，修正后
单文件86项四目标全过；旧JSON期望均未改。公开四个可变ticker镜像字段收束为原有
getter/setter，Axis新增function context桥，internal IR增加可选draw/placement/live-role钩子。
公开set_functions、用户Transform与完整GUI仍后续，详见
[testdata/secondary_lifecycle_README.md](../testdata/secondary_lifecycle_README.md)。

D41 函数替换与 identity reset 已验收：11新增注册测试（1正式组含27场景、10定向
回归），完整四目标nonJS22001/JS22008全过。46源观察中14个动态参数仅source-only；
同名parent-scale保旧安装变换、新name立即重装、CURRENT ticks别名与失败partial均覆盖。
forward/inverse公开只读字段改为私有可变存储，原getter保留；21行接口差异已审。
数值位置与location/alignment和后续定位阶段由D42承接；用户Transform与完整图形系统仍后续，见
[testdata/secondary_functions_README.md](../testdata/secondary_functions_README.md)。

D42 次轴位置与对齐已验收：21 个新增注册测试（2 正式组含 41 场景、19 个定向回归），
完整四目标 wasm/wasm-gc/native 各 22022 项、JS 22029 项，全部通过。56 条分项原源
记录中，7 个动态参数记录保留为 source-only；原有 JSON 期望保持。公开数值位置、
独立 alignment、延迟几何与完整 draw 的第二次定位已接通；内部 IR 增加不可变绘制框和
两个可选钩子，独立 IR 保留旧回退。位置 Transform、任意父布局回调、完整 Tick/Text
对象和非有限位置完整 SVG 仍有边界，详见
[testdata/secondary_position_README.md](../testdata/secondary_position_README.md)。

D43 次轴位置仿射已验收：16 个新增注册测试（2 正式组含 38 场景、14 个定向回归），
完整四目标 wasm/wasm-gc/native 各 22038 项、JS 22045 项，全部通过。52 条原源记录中
14 条保留为 source-only，原 34 条准备记录逐字段不变。Axes/Figure/pyplot 与 set_location
接通不可变 Affine2D 可选参数，保留 whole-matrix 分离检查、失败后新请求位置/旧 locator、
None 清除及入口快照时序。仅 Scene/pyplot 两份接口增加可选参数；通用 Transform 图、
原生可变别名与非有限位置完整 SVG 仍有边界，见
[testdata/secondary_transform_README.md](../testdata/secondary_transform_README.md)。

D44 公开 Line 数据与缓存已验收：25 个新增注册测试（1 正式组含 8 个连续场景、
24 个定向和公开入口回归），25 组原源记录中的 6 条动态协议保留为 source-only。
原 21＋4 记录逐字段保持。首完整四目标同一新增广播 fixture 假设失败，经原源诊断后
9 项内核及 2 项新增公开入口四目标补验全过，累计 nonJS22063 / JS22070 全覆盖。
单坐标失效、混代返回、旧缓存保留、clear 后解绑与 checked relim 前缀失败均接通；
5 份预期接口变化已审，其余 36 份不变。完整 Artist/Path、动态容器与 GUI 协议仍有
边界，见 [testdata/line_data_README.md](../testdata/line_data_README.md)。

D45 稳定 Line 移除已验收：13 个新增注册测试（1 正式组含 4 个连续场景、12 个定向
和公开入口回归），15 条原源记录中 5 条查询/重接入记录保留为 source-only，原 14 条
准备记录逐字段保持。完整四目标 wasm/wasm-gc/native 各 22076 项、JS 22083 项全部通过；
接口只在 Scene 新增 remove 一行，其余 40 份不变。图形 stale 回调、通用 add_line、
完整 get_lines 与 ArtistList 仍有边界，见
[testdata/line_remove_README.md](../testdata/line_remove_README.md)。

D46 Line 可见性已验收：15 个新增注册测试（1 正式组含 15 个连续原源操作、14 个
定向和公开入口回归），原 15 条准备记录和 draw-body hash 完整不变。完整四目标
wasm/wasm-gc/native 各 22091 项、JS 22098 项全部通过。隐藏跳过实际 Line 转换且不清
stale，可见成功才清；显式 getter、单位更新和默认 relim 仍处理隐藏 Line。仅 Scene
接口新增 get/set_visible，其余 40 份不变。完整样式、marker、rasterization 和 GUI 仍有
边界，见 [testdata/line_visible_README.md](../testdata/line_visible_README.md)。

D47 visible_only relim 已验收：11 个新增注册测试（1 正式组含 9 个连续原源操作、
10 个定向/公开回归），原 9 条准备记录完整不变。首完整四目标仅同一正式夹具的
初始 stored-view 桥接失败，显式对齐受控宿主输入后该组四目标补验通过；累计
nonJS22102 / JS22109 全覆盖。过滤先于转换/合并，all-hidden 保旧 minpos，晚失败保前缀；
仅 Scene 两个方法增加默认 false 的可选参数。静态图元继续默认可见，普通
in_autoscale=True 与图形宿主边界见
[testdata/relim_visible_README.md](../testdata/relim_visible_README.md)。

D48 Line 线宽与当前样式已验收：13 个新增注册测试（1 正式组含 28 个操作、两个
连续场景，12 个定向和公开入口回归）；39 条原源记录中的 11 条 SVG 样式结果明确
source-only，原准备记录完整字段不变。完整四目标 wasm/wasm-gc/native 各 22115 项、
JS 22122 项全过。仅 Scene 新增两个方法、IR provider 同时携带当前 Style，其余 39 份
接口不变。dash、完整 Artist 样式及原生 SVG 格式仍有边界，见
[testdata/line_width_README.md](../testdata/line_width_README.md)。

D49 Line 字符串颜色已验收：22 个新增注册测试（7 个正式组、15 个定向/公开回归），
1219 条原源观察中的 1217 条 typed，两个原生可变 RGB-list 记录为 source-only。
原 49 条准备记录及新增完整 draw 的三条记录逐字段保持；1163 项名称的 RGBA 位值
全部纳入校验。完整四目标 wasm/wasm-gc/native 各 22137 项、JS 22144 项全过。
Scene 新增 get/set_color，ticker 仅导出既有 Python 字符串表示薄包装，其余 39 份接口
不变。String 原值、独立全局 C 颜色索引、空/非空绘制和旧 CSS 便利入口边界见
[testdata/line_color_README.md](../testdata/line_color_README.md)。

D50 Line 可选 alpha 已验收：18 个新增注册测试（3 个正式组、15 个定向/公开回归），
59 条原源记录完整保留，其中 55 条 typed、4 条私有 RGBA 缓存历史为 source-only。
完整四目标 wasm/wasm-gc/native 各 22155 项、JS 22162 项全过。Style 是原始 alpha 的
唯一存储，source 颜色覆盖内嵌 alpha，legacy CSS 用 Line-only opacity 组合；alpha0
仍准备数据和颜色。4 份预期接口变化已审，其余 37 份逐字不变。None/Double、原始
零符号与缓存/SVG profile 边界见
[testdata/line_alpha_README.md](../testdata/line_alpha_README.md)。

D51 Line String linestyle 与虚线配置已验收：24 个新增注册测试（5 个正式组、19 个
定向/公开回归），76 条原源记录中 69 条 typed、7 条原生容器行为为 source-only。
三组原记录的完整字段、来源哈希和宿主元数据保持。完整四目标 wasm/wasm-gc/native
各 22179 项、JS 22186 项全过。getter 返回 canonical，合法重复 setter 仍置 stale；
模板仅在线型 setter 捕获，同值线宽仍按当前缩放开关刷新旧模板。None 仍更新数据，
颜色先于 GC 虚线验证，验证先于有限段筛选；SVG 输出已存储的虚线间距和偏移。
4 份预期接口变化已审，其余 37 份逐字不变。原生 tuple/list、marker、cap/join、
通用 Artist 与原生 SVG 格式仍有边界，见
[testdata/line_style_README.md](../testdata/line_style_README.md)。

D52 Line String drawstyle 与独立路径缓存已验收：21 个新增注册测试（4 个正式组、
17 个定向/公开回归），75 条原源记录完整保留，其中 74 条 typed、1 条原生 None
输入为 source-only。完整四目标 wasm/wasm-gc/native 各 22200 项、JS 22207 项全过。
五种 String、同值不变、改变只置 x 失效、default 共享 xy、steps 独立缓存及旧代别名
均已验证。处理后数据保持原点数，绘制和 relim 使用同一条展开路径；类别重排的
midpoint 范围按真实路径计算。仅 Scene 新增三个方法，其余 40 份接口逐字不变。
原生 Path 元数据/布局、NumPy 警告、通用 Path 与大线条裁剪优化等边界见
[testdata/line_drawstyle_README.md](../testdata/line_drawstyle_README.md)。

D53 Line 可选 String gapcolor 与两笔描边已验收：19 个新增注册测试（3 个正式组、
16 个定向/公开回归），54 条原源记录完整保留，52 条 typed、两条原生可变 RGB 为
source-only。四目标 wasm/wasm-gc/native 各 22219 项、JS 22226 项全过。间隙颜色、
逆虚线、GC/实际写入、前景颜色与完成回调严格按顺序执行；前景失败保留写入前缀，
不清 stale。空逆序列的 list/tuple 错误保留最后缩放历史，不能从当前 rc 推断。
4 份预期接口变化已审，其余 37 份逐字不变。低层静态 Style 间隙字段仅传输元数据；
原生颜色对象、marker、cap/join 与像素重叠仍有边界，见
[testdata/line_gapcolor_README.md](../testdata/line_gapcolor_README.md)。

D54 Line 数值 set_dashes 已验收：14 个新增注册测试（2 个正式组、12 个定向/公开
回归），54 条原记录全字段保留，44 条 typed、8 条原生 list 引用历史及两条 None-pair
为 source-only。四目标 wasm/wasm-gc/native 各 22233 项、JS 22240 项全过。调用时
快照映射原不可变 tuple，空序列恢复实线；非空序列不读取 rc 模板，后续线宽按当前
缩放开关重算旧快照。奇数长度和异常数值保留原来的晚 GC 校验。仅 Scene 新增一个
pure 方法，其余 40 份接口逐字不变。映射与借用边界见
[testdata/line_dashes_README.md](../testdata/line_dashes_README.md)。

## 完成标准

条目只有在以下条件都满足时才从“计划”或“原型”移为“已实现”：

1. 公共 API 与 v3.11.2 的目标签名有明确映射。
2. 默认值、形状、范围、异常和图元顺序有测试。
3. 至少一个目标后端有可复现输出。
4. Wasm/native/宿主限制已在条目中注明。
5. `moon info` 生成的公开接口经过审查，文档和示例同步更新。
