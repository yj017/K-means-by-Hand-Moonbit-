# Mooncakes 依赖评估

本项目以实用绘图能力对齐为目标，现行范围见 [路线图](MIGRATION_PLAN.md)。依赖只在对应层确实需要时接入，核心数据模型和场景模型不暴露第三方类型。

候选表记录历史核查结果，版本和可用性须在实际接入前重新验证。
当前采用统一 module `Lampese/mathplotlib@0.2.1`，Rabbita 是同一模块中的 JS 子包。
安装与发布状态见 [发布说明](PUBLISHING.md)，实现与复现见 [DOM 验收](RABBITA_DOM.md)和
[组件使用说明](../rabbita/README.md)。

## 统一模块中的 Rabbita 子包

`rabbita/` 对应 `Lampese/mathplotlib/rabbita`，通过 `supported_targets = "js"` 限定浏览器包。
它固定 `moonbit-community/rabbita@0.16.7`，复用 `Milky2018/xml@0.5.0` 将同次渲染的 SVG
转为公开节点树。核心 facade、Scene、Drawing 与 SVG renderer 不 import Rabbita；
组件公开接口可以使用 Rabbita 类型，核心模型中没有 UI 类型。

Mooncakes 在 module 层解析依赖，安装统一模块也会获取 Rabbita 及其传递依赖。
统一依赖图解析 `moonbitlang/x@0.5.1`、`moonbitlang/async@0.22.4`、
`moonbit-community/moonback@0.8.5`；安装包元数据均已核查为 Apache-2.0。
根 manifest 保留 `x@0.4.46` 的最低版本声明，Rabbita 的需求通过最小版本选择将它提升到 `0.5.1`。
不再声称静态使用有独立 module 缓存或无需解析 UI 依赖；静态编译按包导入关系进行，不引入 JS 组件。

[M2 v0.2.0](MILESTONE_M2.md) 的两个源码模块包与权限预检属于历史交付。
0.2.1 按用户要求合并为 `Lampese/` 前缀的一个 module，当前发布状态以 [发布说明](PUBLISHING.md) 为准。

## 已核查候选

| 包 | 版本 | 结论 | 接入边界 |
| --- | --- | --- | --- |
| `caijiewei295/tzif-engine` | `0.1.0` | Apache-2.0；源码/解析限制已核查；四目标各 847/847 通过 | `ticker/date` 私有 TZif load/PosixRule，公共 API 不暴露第三方类型 |
| `marianoguerra/temporal` | `0.1.0` | 已核查时区 provider；内置仅 UTC，仍需外部规则源；本轮不采用 | 不引入额外日期模型 |
| `Milky2018/xml` | `0.5.0` | 在当前 Moon `0.1.20260920` 上可编译；registry build success、仓库未归档 | `backend/svg` 的 XML 写出与结构测试 |
| `Milky2018/svg` | `0.6.0` | 提供 SVG 解析和 CPU 栅格化，适合后端验证 | 仅 `backend/svg` 或图像测试工具；不进入 `core`/`scene` |
| `mizchi/font` | `0.7.4` | 字体解析候选 | 文本测量和字体资源层，待阶段 5 评估 |
| `0717lee/pixelforge` | `0.19.0` | 图像处理和编解码候选 | PNG/图像后端，待阶段 7 评估 |
| `mizchi/numbt` | `0.2.4` | 维护中，主要提供 native Float/BLAS | 可选 native 加速；不作为跨平台 binary64 核心 |
| `bobzhang/colors` | `0.8.2` | 有维护活动和 Double 颜色空间转换 | 使用前核对 registry 元数据与仓库许可证 |

## 暂不采用

| 包 | 原因 |
| --- | --- |
| `Kaida-Amethyst/matplotlib` | registry 标记为 legacy，并依赖 Python bridge，不能作为独立 MoonBit 迁移基础 |
| `tonyfettes/cairo` | registry build success，但元数据中的 GitHub 仓库返回 404，维护状态未确认 |

## 接入规则

1. `core` 只使用 MoonBit 自身的 `Double`、数组和错误类型，保证 Wasm/native 的基础语义一致。
2. `scene` 只产生后端无关的图元和布局结果；任何 XML、位图或 C 类型都不能泄漏到该层。
3. `Milky2018/xml` 只有在 `backend/svg` 开始结构化编码时加入，并用 `moon add` 固定版本后提交 `moon.mod` 变化。
4. native 图像、字体和 GUI 依赖分别放入对应后端包，不能为了一个后端改变公共绘图 API。
5. 每次增加依赖都记录版本、构建状态、许可证核查结果和最小验证命令。

## 当前验证依据

候选版本来自本轮 Mooncakes registry/仓库状态核查。`0.6.1` 的 registry 包在当前工具链上引用了已不存在的 `Int32`，因此本项目固定使用兼容的 `0.5.0`，并已通过 `moon check --target all`、`moon test` 和 native 测试。未接入的候选不应出现在核心包的公开 `.mbti` 中。

## D01 TZif 数据接入

- 固定 `caijiewei295/tzif-engine@0.1.0`（Apache-2.0），声明的传递模块依赖为
  `moonbitlang/x@0.4.46`（Apache-2.0）。仅 `ticker/date` 导入解析 facade、
  私有类型和 POSIX evaluator；自有 transition/gap/fold/recurrence 继续复用。
- 包源码与 LICENSE 已从 Mooncakes 0.1.0 归档核对；不修改或复制解析器实现。
  候选信息：[Mooncakes](https://mooncakes.io/docs/caijiewei295/tzif-engine@0.1.0)。
- TZif 标准：[RFC 9636](https://www.rfc-editor.org/rfc/rfc9636.html)。本 adapter
  支持 v2/v3；v1/v4、leap-second 表及超出 DateTime offset 范围的数据显式拒绝。
- 基础 date 包接受调用方 Bytes；D02 另有可选独立 tzdb 生产数据包。IANA 2026e fixtures 属公有领域，仅用于
  黑盒测试；编译器、源数据哈希与复现说明在 `testdata/tzif/README.md`。
- 验证日志：`.moonagent/checkpoints/D01-{narrow,info,fmt,check-all,test-all}.log`。

D01 最终验证：moon info && moon fmt、moon check --target all 通过（8 条已有 warnings）；
专项 178/178，wasm/wasm-gc/js/native 各 847/847。未出现第三方公开类型。

## D02 可选 IANA 名称数据库

- 新 `ticker/date/tzdb` 包内嵌 IANA tzdata **2026e** 标准构建的全部 598 个
  Zone/Link 名称（包含 backward）；345 份去重 TZif slim，共 206817 字节。
  复用 D01 的解析依赖，无新增 Mooncakes 依赖，也不引入第二套日期模型。
- 再次核查 `moonbitstack/moondate`：文档明确不含 named DST/IANA；temporal
  仍需外部 provider；tzif-engine 为解析器，不分发完整库。此处直接复用官方
  public-domain 数据与 pinned zic，非手写时区规则。
- 基础 date/scene/pyplot 的生产导入不依赖 tzdb；scene/pyplot 仅在黑盒测试导入。
  用户显式导入 tzdb.timezone(name)，再把自有 DateTimeZone 传入已有入口。
- 官方源归档/哈希、源文件清单、canonical/alias→内容索引与每项哈希见
  `ticker/date/tzdb/manifest.json`；许可随包保存；不启用可选 backzone/packrat，
  不含系统 localtime、leap/right 或任意 POSIX TZ 字符串解析。
- `scripts/generate_tzdb.py` 从校验后的固定归档在临时目录构建 zic，逐一核对
  源 Zone/Link 与产物名称；--check 可在不改 checkout 的情况下复现验证。
  全部名称的历史/未来参考 offsets 由 Python zoneinfo 读取同一 TZif 独立产生。
- D02 验证进度/日志见 MIGRATION_STATUS 与 `.moonagent/checkpoints/D02-*`。

D02 最终验证：独立生成 --check、info/fmt、check --target all 通过；
专项 14/14，wasm/wasm-gc/js/native 各 861/861，每目标包含全名称 8372 个参考 offset 断言。

## D11 日期字符串宿主上下文

- `moonbitlang/x@0.4.46` 从已存在的传递依赖提升为显式固定依赖（Apache-2.0），
  仅 `internal/date_host` 在 native/Wasm 复用 `x/fs.read_file_to_bytes`；无新增自有Cstub。
- JS使用guarded `process.getBuiltinModule`读文件，避免静态node:fs导入；无该能力的
  嵌入宿主显式提供 `DateParserContext`。clock复用 `core/env.now`，外部可注入毫秒回调。
- TZif/POSIX与is_dst查询继续复用已固定的TZif Engine；基础date不导入可选tzdb。
  tzdb仅增加 `parser_context(name)` 复用其原Bytes索引。宿主文件读取按调用惰性发生，
  不写文件、不改变系统TZ；受控测试的环境变量修改均恢复。
- 默认采用固定CPython采样profile，`with_local_info`接入另一宿主的std/dst descriptor。
  source/reference/runtime能力边界与验证见 `testdata/date_parser_README.md` 和D11检查点。

## D12 默认日期时区

复用 D11 的 host Bytes 读取和现有 TZif Engine parser；日期字符串 gettz profile
读取第一32位兼容区块，widen后交给同一checked parser，完整IANA路径继续保留原模型。
GNU TZ名称offset与dateutil相同；其calendar/weekday计算使用现有本地Gregorian日历，
按需查询目标年份，不物化万年转换表。无新增依赖或自有C代码。
可选tzdb.register_timezone只注册指定名称的原Bytes；基础date仍不生产导入tzdb。

## D13 日历相对运算

仅增加 `moonbitlang/core/bigint` 和 `core/string` 标准库导入，无外部依赖或自有C代码。
精确binary64→decimal量子→binary64复用BigInt和parse_double，避免Double先乘10^n的伪tie；
scale的截断整数通过BigInt作carry/cancellation，归一后检查typed Int64/finite Double范围。
DateTime日历/时区墙钟算术沿用既有模型，between按zone handle identity区分墙钟/instant。
原始dateutil/CPython源码和参考只用于开发验证，不在运行时加载Python或上游源文件。

## D14 rrulewrapper 与 named RRuleLocator

复用 DateParserContext、RRule/RecurrenceCache、纯 calendar candidate、DateTimeZone 与
RelativeDelta；只抽取已被两个调用链实际需要的 calendar window/dispatch。
无新增依赖、Python运行时或自有C。dateutil tzstr 的墙钟 offset 选择参考原
`tz/_common.py::tzrangebase`，与完整 TZif 及旧 instant recurrence 语义分开保留。
参考脚本使用开发依赖Python3.12.14、dateutil2.9.0.post0/NumPy2.3.5，固定源与许可见
[testdata/rrule_wrapper_README.md](../testdata/rrule_wrapper_README.md)。

## D15 自动日期 recurrence 接线

AutoDateLocator复用D14公开wrapper/locator及已decode bounds，无新依赖。
dateutil POSIX fromutc/utcoffset两次mask通过共享私有helper实现；完整TZif evaluator不变。
原源92组transition cases、旧自定义epoch及scene/pyplot回归保留在auto_locator参考指南。

## D16 命名年定位器

YearLocator与Auto年倍数分支复用RRuleWrapper/RRuleLocator/DateParserContext；wrapper仅新增
私有calendar形态标记和可选scalar参数，无新增外部依赖。共享naive host解释入口直接按固定
CPython3.12.14 local_to_seconds/两fold探测重写，并保留年界错误；不包含C实现或Python运行时。
原源、clock注入及typed范围见testdata/year_locator_README.md。

## D17 命名日历/时间定位器

六个命名类复用RRuleLocator/RRuleWrapper，只有构造默认值/None/scalar-array归一共享helper。
同级clock selector相位筛选重用本地gcd，在wrapper构造时执行，旧RRule扩展不变。
原源generator执行六class与原_get_tzinfo，控制开发时clock/hostTZ，不增加运行时依赖。
参考与typed范围见testdata/named_locator_README.md。

## D18 检查式递推迭代

复用既有24h clock slots/residue/gcd模型，候选与错误检查共享惰性slot iterator；新增opaque
RRuleDateIterator，不引入外部iterator、线程库或Python运行时。旧RRule/native Iter扩展保持。
来源、checked count签名与缓存边界见testdata/clock_iteration_README.md。

## D19 命名微秒定位器

新MicrosecondLocator与旧helper共用Double multiple/divmod kernel；whole-array日期转换
由RRuleLocator抽取复用，Auto直接传已解码字段。CPython/NumPy浮点divmod及NumPy首naive
秒级偏移截断通过固定开发运行时验证，无新增外部依赖、Python运行时或C实现。
范围、精确间隔getter与173named/72逐bit参考见testdata/microsecond_locator_README.md。

## D20 数值固定间隔定位器

数值MultipleLocator与D19微秒定位器共用新内部包`internal/tick_grid`：把既有CPython/NumPy
divmod、Edge ge及multiple grid提取并补le/offset，由数值/DataError和日期/DateError入口适配。
不增加外部依赖、运行时Python或自有C实现，旧日期helper/API保持原行为。
config增加`axes_autolimit_mode`，axis复用已有margin/sticky/shared/secondary与render链路。
参考生成仅使用既有开发Python3.12.14、NumPy2.3.5和固定Matplotlib源码；来源、typed边界
及重现命令见[testdata/multiple_locator_README.md](../testdata/multiple_locator_README.md)。

## D21 命名线性、索引和固定定位器

LinearLocator、IndexLocator和FixedLocator复用ticker/axis/render链路及既有nonsingular helper。
TickValues提供共享buffer的可变signed/nested/0stride view，Fixed.from_view与LinearLocatorPresets
set_view/get保留真实owner别名；无外部容器、运行时Python或新增C依赖。Index用core/bigint
标准库实现一次精确舍入FMA，匹配固定Darwin arm64 NumPy2.3.5 fill profile；未引入native FMA。
NumPy linspace/arange的binary64运算
及Fixed subsample/alias以固定Python3.12.14、NumPy2.3.5开发参考验证，原shape检查直接执行
固定_api.check_shape AST。Index真实artist data interval与checked轴/SVG接线状态、typed
范围和重现方式见[testdata/named_numeric_locator_README.md](../testdata/named_numeric_locator_README.md)。
原Bbox数据边界、Grouper首次join顺序、GridSpec和Axes共享绑定方法也由固定AST独立验证；
生产复用既有artist collector收集原始finite数据，并以私有rank保留共享组登记顺序。
SubFigure的行列共享组预留各自ID区间，无新增容器或第三方依赖。

## D22 MaxN 与自动数值定位器

AutoLocator只持有MaxNLocator状态并薄委托，无第二套刻度算法。共享tick_grid新增实际大offset
Edge容差，nonsingular增加tiny参数并保持旧默认；MaxN复用既有TickValues/BigInt及纯Moon
numeric_fill，把D21 Index的Darwin NumPy arange单舍入实现提取为真实共享代码。
TickValues新增真实Float64/Int64双buffer，以核心Int64保存整数别名、截断写入及view/copy类型；
Auto经典默认沿原Int64数组，不用Double buffer伪造默认dtype写入。
完整raw grid描述符用于nticks决策、prune与view端点，返回数组仍受100000前缀限制。
Axis/Secondary字号与physical tick-space复用现有scene/render/SVG尺寸和文字链路，固定
dpi72 profile；没有运行时Matplotlib、NumPy、Python、新外部库或C实现。新增classic Bool
配置、参数/数值/Auto/物理源参考及重现命令见[testdata/maxn_locator_README.md](../testdata/maxn_locator_README.md)。

## D23 自动次刻度与空定位器

AutoMinorLocator 复用真实 Float64/Int64 TickValues、nonsingular 与既有 BigInt/binary64
舍入工具，保留整数 unique/diff、任意精度 Python round 相位和 NumPy arange dtype 分支。
config 增加核心 bigint/debug 标准库导入，用于精确整数 rc 与公开 typed 参数；不新增外部库。
轴与 secondary 使用现有 provider、共享绑定、变换和 scene/render/SVG 链路；Null 按独立
刻度组跳过 getter/formatter。原源参考只依赖开发环境的固定 Python/NumPy，涵盖源 AST、
Unicode15 整数转换及 NumPy 随机 signed-zero 代表观察；生产不引入 Python、NumPy 或 C。
固定来源、typed 域与重现见[testdata/auto_minor_locator_README.md](../testdata/auto_minor_locator_README.md)。

## D24 命名对数定位器

LogLocator 复用 TickValues、BigInt、数值舍入和既有 AutoLocator fallback；参数对象、
原始网格、provider 与场景接线分别保存。局部/共享 minpos 复用 artist collector 和现有
Grouper 所有权；箱线图按固定宽度 .6/cap .2 的实际端点收集范围，参考线/跨度只更新其
数据坐标方向。Axis、secondary、contour 和 SVG 继续共用现有渲染链路。
整数幂和新decade helper的ln使用自有BigInt定向区间与已有精确binary64舍入，跨目标采用
正确舍入数学合同；Darwin libm非正确round的已知差异单独存原源/数学双值，不复制平台库。
参考生成器仅在开发环境使用固定 Python/NumPy 执行原始 AST，包括完整 autoscale_view、
Axis._set_lim、LogTransform 及真实 boxplot 路径；生产没有新增 Python、NumPy、C 或外部库。
数值门禁状态与显式范围见[testdata/log_locator_README.md](../testdata/log_locator_README.md)。

## D25 命名对称对数定位器

SymmetricalLogLocator 复用 D24 的参数预算类型、portable ln/pow、numeric_arange_fill 与
既有 nonsingular/decade helpers。新的 SymLogSubs 保留 Float64/Int64 views；仅在消费时
按源协议转换和乘法，完整负段反转与零折叠使用逻辑描述符生成有限前缀。
ticker 新导入内部 ticker/scale 包以捕获既有 Scale 值，没有外部依赖或依赖环。
Scale 两个私有数值体和 SVG secondary mapping 直接复用原链路修正；原源证据执行完整
变换树，C affine 内核以明确的矩阵乘法 sink 供应，未分发上游 C 或增加 Python 运行时。
固定输入域、源/数学差异与重现见[testdata/symlog_locator_README.md](../testdata/symlog_locator_README.md)。

## D26 命名 Asinh 定位器

AsinhLocator 复用真实 TickValues、任意精度参数、nonsingular、D24 ln/pow 和精确
binary64舍入。新asinh/sinh/log10使用BigInt定向区间与自适应精度，数学profile跨目标一致，
并保留Darwin源平台整组刻度差异。完整linspace/outer通过逻辑分段与plateau跳跃求值。
最小Scale::Asinh使用现有核心math变换，Axis/secondary/contour/SVG沿用现有链路；
没有新增外部运行时依赖。原始Python/NumPy只参与开发参考生成，独立Decimal证据与
重现见[testdata/asinh_locator_README.md](../testdata/asinh_locator_README.md)。

## D27 命名 Logit 定位器

LogitLocator 组合真实 MaxN 参数状态，重用 staircase、完整grid descriptor、prune与
checked数值体。新增私有context hooks只在原raw_step阶段读取投影并执行3d两步舍入，
旧MaxN公共接口不扩展。Logit本体复用D26 portable log10与D24整数幂；MaxN scale_range
两处十进制整数幂也复用该正确round primitive，修复nonJS pow(10,-4)低1ULP影响grid起点；
其余MaxN数值顺序不变。Scale共享limit_range_for_scale供Axis与backend按实际几何限制范围；
原源参考执行完整AST并保留raw重复/zero、单独的Data诊断与未迁移logger边界。
没有运行时Python/NumPy/C调用或新外部依赖；重现见
[testdata/logit_locator_README.md](../testdata/logit_locator_README.md)。

## D28 命名基础 Formatter

BaseFormatter 与 Null/Fixed/Func 共享真实可变对象状态，重用 TickValues 保留数值 view，
Array 则保动态长度；独立 checked 管线贯通 primary/shared/secondary 与 SVG。旧纯函数
Formatter enum 不改变接口或复制行为。unicode_minus 只在显式 fix_minus 调用时读取。
参考脚本加载完整原类、真实 _api 与固定 deprecation.py，校验源码 SHA；没有运行时
Python/NumPy/C 调用或新外部依赖。完整动态 Python、Text 缓存与默认重置单独后续迁移。

## D29 命名字符串 Formatter

FormatStrFormatter/StrMethodFormatter 复用 D28 Base 对象、借用位置、axis identity 与 checked
Scene/IR/SVG 管线。旧便利 Formatter enum 不改。共享格式数值层复用既有 BigInt 精确
binary64 ratio/ties-even helpers 与 Moon core Ryu 的 shortest digits，再按 Python 规则
排版；没有新的浮点 FFI 或 Python 运行时。Int64 view 到整数文字无 Double 中转；新
TickValues.select_mask 为主轴/secondary 次刻度提供保 dtype 的 fresh selection。
原源生成使用固定 CPython3.12.14/NumPy2.3.5 和真实 string.Formatter；Unicode15.0 的
printability 表由固定 Python API 全码点生成，用于 repr/KeyError，Invalidspec 的原字面
消息独立保持。无新外部依赖，完整 source/typed/资源范围和重现见
[testdata/string_formatter_README.md](../testdata/string_formatter_README.md)。

## D30 命名 PercentFormatter

PercentFormatter 复用 Base 对象、BigInt 精确 binary64 比例/十进制格式和 D26 可移植
log10。独立的 FormatterViewInterval 保留 Python 整数、浮点和 NumPy Float64/Int64
范围的类型；虚拟轴、真实轴与 secondary 的 live provider 复用稳定绑定。text.usetex
只提供符号动态转义设置，没有新增 TeX 运行时。原源参考使用固定 CPython/NumPy，
执行完整 PercentFormatter、真实 Axis/Bbox 与 secondary/frame 方法；NumPy 运行时警告
单独记录。没有新运行时依赖，范围和复现见
[testdata/percent_formatter_README.md](../testdata/percent_formatter_README.md)。

## D31 命名 ScalarFormatter

ScalarFormatter 复用 Base 对象、TickValues、现有精确十进制文字与 BigInt 定向区间。
Python/NumPy 数值来源分开保留；NumPy decimal round 按固定 calculation.c 的逐次乘法、
rint、除法顺序实现，整数与分数十进制幂复用可移植正确舍入数学 profile。
NumericLocale 是显式数值 locale profile，独立于 rc reset；没有 OS setlocale 或 locale
发现服务。原源参考执行完整 ScalarFormatter、真实 RcParams/FontProperties/FontManager、
固定 CPython locale.py 与真实 Axis/SecondaryAxis/draw/transform 方法。空字体目录使真实
findfont 走捕获 ValueError 分支，没有模拟查找结果或声称系统字体扫描已接入。
短标签复用现有 SVG72 几何；正逆 affine 运算分开保留，逆矩阵使用独立数学 profile，
原 Darwin NumPy/LAPACK 系数另存为证据。没有新的 Python/NumPy/C/TeX 或外部运行时依赖；
完整类型、资源与宿主边界见[testdata/scalar_formatter_README.md](../testdata/scalar_formatter_README.md)。

## D32 命名 EngFormatter

EngFormatter 复用同一 Base/Scalar 状态、checked 批量及 late-offset 接线；继承的短标签
使用原有 SVG72 像素 provider。工程数值复用精确格式、BigInt 定向区间、独立 Python/
NumPy 舍入和整数/分数幂，新增先分别舍入两个自然对数再相除的阶数计算。动态数字前缀
表保留固定 64 位 CPython 数字哈希、combined-table 探测/删除/扩容/复制与 NumPy 弱相等。
NaN 的可移植身份哈希为零，原宿主地址派生的哈希碰撞行为单列边界；不宣称地址复刻。
参考执行完整原 Eng/Scalar 类、builtin dict、实际 Axis/draw/secondary 与独立 Decimal
数学 profile。CPython v3.12.14 dictobject.c 是行为依据，未分发 Python/NumPy 运行时或
新增外部依赖。具体来源、数值差异和复现见
[testdata/eng_formatter_README.md](../testdata/eng_formatter_README.md)。

## D33 命名 LogFormatter 家族

四个命名 LogFormatter 对象复用 Base、六类 ScalarNumber、精确十进制格式、现有 Unicode
数字/printability 表与 BigInt 定向区间。新增一般正底数分数幂先处理精确有理根，再自适应
细化 ln/exp 区间；生成的完整 arange/geomspace 子标签集合使用内部逻辑表示和完整唯一值
快照。Text 底数复用 Moon core decimal parser，补原生 infinity、NaN 符号与完整错误 repr。
Axis 仅新增当前实际 transform 的 optional linthresh provider，无 Python 反射服务。
原源参考执行完整四类、真实 Formatter/RcParams/cbook/transform/Axis/Secondary/draw 与独立
Decimal 数学 profile；native libm/NumPy warning 差异保留双值。没有新增运行时依赖，
边界和复现见[testdata/log_formatter_README.md](../testdata/log_formatter_README.md)。

## D34 命名 LogitFormatter

命名对象复用 Base、LogValue、六类 ScalarNumber、BigInt 精确格式与现有可移植 ln/log10。
新增只读 Bool/UInt64/Object 数组快照桥，以及保留对象身份的 LogitKey；浅复制共享可变标签
集合。集合探测/扩容和带 NaN tuple 的 powersort 协议参考 CPython v3.12.14 的 setobject.c
和 listobject.c，以 MoonBit typed arrays 重写，不引入 Python/C 运行时依赖。许可证保留在
[LICENSE-CPYTHON](licenses/LICENSE-CPYTHON)，来源哈希与实际 builtin set/sorted 参考见
[总指南](../testdata/logit_formatter_README.md)、[集合](../testdata/logit_set_README.md)和
[排序](../testdata/logit_sort_README.md)。完整 Axis 使用既有接线，无新几何/transform provider。
Object dtype 的距离排序另按 NumPy 2.3.5 generic quicksort/introsort 与 heapsort fallback
重写，以保留 NaN 的实际部分序比较结果；NumPy BSD 许可证保留在
[LICENSE-NUMPY](licenses/LICENSE-NUMPY)。它是专用 MoonBit 协议实现，不加载 NumPy 运行时。

## D35 显式 scale 默认安装

五种既有 typed 几何的显式 scale 安装复用现有命名 locator/formatter、rc 捕获和
稳定 Axis 上下文绑定，无新数学内核或外部运行时依赖。共享 ticker holder 保存四个
对象角色、旧便利表示和四个默认标志；Asinh 新增共享不可变 Double tuple 投影。
三个独立参考执行固定 Matplotlib v3.11.2 的完整 scale/default、Axis/Ticker、
Grouper/sharex/sharey/GridSpec、移除及 draw 原源方法，宿主 autoscale 只记录调度。
完整构造/clear/units/secondary 生命周期仍在后续范围；参考依赖沿用已保留的
Matplotlib/CPython/NumPy 来源与许可证。接口变化和精确复现见
[testdata/scale_defaults_README.md](../testdata/scale_defaults_README.md)。

## D36 构造与 clear 生命周期

复用同一命名默认对象与 typed 线性 reset；新增真实有序共享组和创建 target 引用，
保留显式 handles 下的删除/rejoin状态。Axis 生命周期视图与 Scene 绘制投影分开，
显式用户 provider 仍优先并按 checked 路径传播错误。原源参考执行完整 Axis.__init__/
clear、Axes.__clear、Grouper/sharex/y/_set_lim/GridSpec 与 Figure 移除体；保留转换信息的
完整 tick 查询也有独立参考。没有新数值内核或外部运行时依赖；强 typed 引用不承诺
Python weakref 到期时序。验收和后续范围见
[testdata/initial_clear_README.md](../testdata/initial_clear_README.md)。

## D37 numeric autoscale 与缓存数据范围

本切片复用同一固定 Matplotlib v3.11.2 原源、NumPy 2.3.5 与已审计的运行时，没有新增分发依赖。
完整原 autoscale/request/unstale/bound/limit 及 Bbox 缓存算法由独立 Python generator 执行；
controlled interval/Path/ownership hosts、精确来源 hash 和边界见
[testdata/autoscale_README.md](../testdata/autoscale_README.md)。四目标行为验收已通过，nonJS 各21892项、JS21899项。

## D38 内建 Date/Category 单位接线

复用同一 MoonBit 日期/类别转换、共享 ticker holder 与 D37 缓存范围内核，无新分发依赖。
独立参考新增执行固定 v3.11.2 的 units.py 与 category.py，源码从官方固定 tag 缓存并逐字
校验 SHA256；同时执行原 Axis 单位方法、Date 具体类、真实共享 Ticker 和完整 autoscale。
来源哈希、90 个原源案例、epoch 隔离及动态协议边界见
[testdata/units_lifecycle_README.md](../testdata/units_lifecycle_README.md)。整数 formatter 来源
复用已有 BigInt/Scalar/Logit NumPy 促型代码；项目不分发 Python 或 NumPy 运行时。

## D39 Line 原始输入与单位回算

Line 原始坐标使用私有 MoonBit 数组保存，仍输出既有数值 Artist/render 模型，无新分发依赖。
独立参考新增固定 v3.11.2 的 lines.py，SHA256 为
`e928511cec1f9ce19455008c1863d337b0dbd1c71ac2b8d40224c8d5c069e05c`，
并复用已固定的 Axis、units/category/date、CallbackRegistry、共享 Ticker 与 Bbox 原源。
执行边界、受控数值 Path 宿主和未迁移的 public lazy Line API 见
[testdata/line_units_README.md](../testdata/line_units_README.md)。既有 Matplotlib 与 NumPy 许可继续适用。

## D40 次坐标轴默认对象与独立视图

复用既有 Axis 默认安装、autoscale、formatter 与 SVG 协议，没有新分发依赖。
独立参考执行固定 v3.11.2 的完整 `SecondaryAxis`，并复用真实 Axis、function scale、
Bbox 和数值 autoscale 方法；`axes/_secondary_axes.py` SHA256 为
`b2aaaae077e03ff6538d1a4bf8a69c3476eed0e27120aa567de138c794599a93`。
图形 superclass 构造和最终绘制宿主边界、53 个源观察及两个注册测试组见
[testdata/secondary_lifecycle_README.md](../testdata/secondary_lifecycle_README.md)。
不分发 Python/NumPy，也不把数值宿主视为完整 GUI 或通用 Transform 协议。

## D41 次坐标轴函数替换

复用 D40 的完整原类、Axis/scale/autoscale 与数值图形宿主，无新增源码来源或分发依赖。
独立原源记录46个观察（40参数/生命周期与6非线性阶段），其中14个动态参数明确保留为
source-only；完整来源、typed callback 边界与复现见
[testdata/secondary_functions_README.md](../testdata/secondary_functions_README.md)。
现有 Matplotlib 与 NumPy 许可继续适用，运行时仍为纯 MoonBit 实现。

## D42 次坐标轴位置与对齐

复用现有 `transforms` 的 BBox/Affine、Axis 与 SVG 管线，没有新增分发依赖。
原源参考执行完整 Secondary 位置与对齐方法、实际 locator/Bbox/aspect，并为两个空图形
宿主场景执行完整 `_AxesBase.draw` 数值控制体；该方法体 SHA256 为
`fd1ee29a1bfb093c3a42fd9ba5175c8a704c3cdc8c6cc7c985614cf379050fa9`。
56 条分项记录、41 个 typed 场景、7 条 source-only 参数记录与宿主边界见
[testdata/secondary_position_README.md](../testdata/secondary_position_README.md)。
项目不分发 Python/NumPy；既有 Matplotlib 与 NumPy 许可继续适用。

## D43 次坐标轴位置仿射

复用现有不可变 Affine2D、blended transform、BBox 和 D42 定位/渲染钩子；pyplot 仅增加
模块内 transforms 依赖，没有新增分发依赖。独立参考执行固定完整 Secondary、原生
blend factory、locator 和 Bbox；52 条记录含 38 个 typed 场景与 14 条 source-only，
其原生类来源、可变别名与非有限几何边界见
[testdata/secondary_transform_README.md](../testdata/secondary_transform_README.md)。
没有替换全局变换数学或引入新的运行时；既有 Matplotlib 与 NumPy 许可继续适用。

## D44 公开 Line 数据与延迟缓存

复用 D39 固定 `lines.py` / Artist 单位转换与 Axes relim 原源加载器、现有 TickValues
步长视图、日期/类别转换和浮点文本解析器。实现为纯 MoonBit，没有新增分发依赖。
独立参考保留 21 条数据观察与 4 组 owner=None 转换记录；15 条 typed 数据操作和
4 组 detached profiles 组成 8 个连续场景，6 条动态参数/容器/GUI/copy 记录为 source-only。
具体哈希、执行方法与受控 Path 宿主见
[testdata/line_data_README.md](../testdata/line_data_README.md)。
没有分发 Python/NumPy；既有 Matplotlib 与 NumPy 许可继续适用。

## D45 Line 句柄移除

复用 D44 稳定 Line 身份与延迟绘制桥，无新增分发依赖。独立参考执行固定 v3.11.2 的
完整 Artist.remove、Axes.add_line/clear、Figure.delaxes 与既有 Line 缓存方法；15 条记录
中 10 条 typed 操作组成 4 个连续场景，5 条查询/重接入记录保留为 source-only。
来源哈希、图形宿主和移除绑定边界见
[testdata/line_remove_README.md](../testdata/line_remove_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。

## D46 Line 可见性

复用稳定 Line 状态和既有 late-provider 协议，无新 IR/backend 类型或分发依赖。
独立参考执行固定 v3.11.2 的 Artist.get_visible/set_visible 及完整 Line.draw 控制体，
仅去除 rasterization 呈现 decorator；no-line-style/no-marker 宿主执行实际早退、缓存和
完成阶段。15 条原源操作保留为一个连续 typed 场景，具体来源哈希与边界见
[testdata/line_visible_README.md](../testdata/line_visible_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。

## D47 relim 的可见性过滤

复用 D37/D44 的范围内核、稳定 Line 身份与 D46 可见性，无新运行时或分发依赖。
独立参考执行完整固定 Axes.relim、Bbox 更新/重置及 Line cache，9 条原源记录保留为
一个连续 typed 场景。来源哈希、非有限值表示与 ordinary in_autoscale 边界见
[testdata/relim_visible_README.md](../testdata/relim_visible_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。


## D48 Line 线宽与当前样式

复用稳定 Line、不可变 core.Style 与现有 SVG 编码器；late-provider 同时传递点、当前
样式和完成回调，没有新增分发依赖。参考脚本执行固定 v3.11.2 的完整 linewidth 方法、
真实 RcParams bool validator 及独立 GC/SVG 样式方法，额外三个官方源码下载均须通过
固定 SHA256。28 条 setter 记录投影为两个连续 typed 场景；11 条 SVG 样式记录保留
为 source-only。来源哈希、NaN 与 SVG 数字格式边界见
[testdata/line_width_README.md](../testdata/line_width_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。


## D49 Line 字符串颜色

复用稳定 Line/Style、D48 late-provider、既有 Python 浮点文本和字符串表示，以及
core.colors 的 RGBA/CSS 输出。完整命名表从固定 v3.11.2 的 `_color_data.py` 和原始
colors.py 合并/别名语句及 `to_rgba` 生成；两个官方文件均强制 SHA256 校验。
没有新增分发依赖。参考脚本另保留原 getter/setter、独立 RGBA primitive 与完整
solid/no-marker Line.draw 的实际观察；来源、计数与边界见
[testdata/line_color_README.md](../testdata/line_color_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。


## D50 Line 可选透明度

复用不可变 Style、既有 Python 浮点文本表示和 D49 颜色转换，增加 Line-only alpha
载荷及 SVG stroke-opacity 传输，没有新增分发依赖。参考脚本执行固定 v3.11.2 的
完整 Artist alpha 方法、颜色 helper 和 solid/no-marker Line.draw。59 条实际观察中
55 条 typed、4 条私有缓存先后顺序记录保留为 source-only；完整字段与原 bits 不改。
来源、mandatory hash、None/Double 域和 portable cache 边界见
[testdata/line_alpha_README.md](../testdata/line_alpha_README.md)。
项目不分发 Python/NumPy，既有 Matplotlib 与 NumPy 许可继续适用。

## D51 Line 线型与虚线模板

复用不可变 Style、稳定 Line、现有 late-provider 与 SVG writer。四项 typed 配置
复制模板和快照，Line 保存必要的未缩放历史，effective stroke 以不可变载荷传递。
私有固定十一项建议 matcher 与 Float64 补偿求和改写自固定 CPython 3.12.14 源码；
没有加入运行时依赖，许可与哈希列于 docs/THIRD_PARTY_NOTICES.md。独立参考执行原始
setter、RcParams validator、完整 no-marker draw、GC 校验及真实 difflib/builtin sum，
76 条原源记录中的七条原生容器行为保留为 source-only。来源、重现和各投影边界见
[testdata/line_style_README.md](../testdata/line_style_README.md)。

## D52 Line 阶梯路径

复用 D44 的 Float64 步长视图、稳定 Line、现有单位回算和 SVG/relim 桥，无新增运行时。
路径展开依据固定 Matplotlib v3.11.2 的 cbook 三个完整 step 函数；独立参考执行完整
所选 Line 方法和真实 Path 构造/属性方法，并对官方 path.py 下载强制 SHA256 校验。
默认路径的共享和阶梯路径的独立代均来自实际原源观察，未用简化 PathStorage 替代。
75 条原源记录保留完整字段，String 域投影 74 条，原生 None 一条为 source-only。
来源、数值/布局/警告边界和复现见
[testdata/line_drawstyle_README.md](../testdata/line_drawstyle_README.md)。

## D53 Line 间隙色

复用不可变 Style、既有颜色转换、缓存路径与 SVG writer；一个命名 LineDrawingContext
承载按顺序执行的间隙与前景绘制，没有新增分发依赖。私有逆虚线 helper 依据固定
Matplotlib v3.11.2 原方法重写。独立参考执行完整 gapcolor setter、is_dashed、逆虚线
及 no-marker Line.draw，保留全部 54 条原观察；52 条 typed、两条原生可变 RGB 为
source-only。完整 payload 有强制哈希，来源、重现与实际绘制阶段见
[testdata/line_gapcolor_README.md](../testdata/line_gapcolor_README.md)。

## D54 Line 自定义虚线序列

复用现有 captured pattern、CPython 浮点补偿求和、不可变 Style 和两笔描边链，
没有新增运行时依赖。数值数组在调用时快照，明确映射固定原源不可变 tuple 输入；
原生 list 的引用/变动和 None-pair 作为完整 source-only 记录保留。独立参考执行
完整 set_dashes 委托链及 no-marker draw，54 条原观察中的 44 条属于该 typed 域。
来源、哈希与复现见 [testdata/line_dashes_README.md](../testdata/line_dashes_README.md)。
