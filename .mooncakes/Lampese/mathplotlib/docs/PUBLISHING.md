# 安装与发布

仓库源码正在验收 **0.18.0** 极坐标柱形／玫瑰图；本次实际发布尚待完成。
下述0.17.0为最近已核验的公开版本，完成正式分发核验后更新。

当前分发为 **`Lampese/mathplotlib@0.17.0`**，新增[极坐标原始数据提示](POLAR.md)、
雷达类别、逐面板圆盘命中与高亮。示例为 `rabbita/polar.html`。
已实际发布Mooncakes与[GitHub v0.17.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.17.0)；
612份全新安装源逐一同正式ZIP，四目标静态/Chrome59及GitHub四附件完整下载核验通过。
核心绘图与 Rabbita 组件仍是一个 module。

0.15.0的[连续流线生成场值](STREAMPLOT_INTERACTION.md)已实际发布Mooncakes与GitHub；
公开构建成功、601份全新安装源逐一同正式ZIP，四目标静态/Chrome51及GitHub四附件完整下载通过。

新增[图表悬停与提示](TOOLTIPS.md)包括柱形、直方图、饼图、折线横轴吸附和自定义格式。
0.4.0 接续[热图单元格、分组/堆叠柱与环形图](M3_CHARTS.md)，新示例为 `rabbita/charts.html`。

0.5.0 接续[统计图与区间交互](STATISTICS.md)，新示例为 `rabbita/statistics.html`。
0.6.0 接续[矩形网格与二维计数交互](MESH_INTERACTION.md)，新示例为 `rabbita/grids.html`。
0.7.0 接续[六边形分箱](HEXBIN_INTERACTION.md)与[小提琴分布](VIOLIN_INTERACTION.md)，
同时修正旧 hexbin 分桶与轮廓错位；新示例为 `rabbita/distributions.html`。
0.8.0 接续[Step](STEP_INTERACTION.md)、[Stairs](STAIRS_INTERACTION.md)与[ECDF](ECDF_INTERACTION.md)的原采样、区间及概率提示，
新示例为 `rabbita/discrete.html`。0.9.0接续[Stem原样本、实际杆段与圆头](STEM_INTERACTION.md)，新示例为 `rabbita/stems.html`。0.10.0接续[Quiver原位置与U/V分量](QUIVER_INTERACTION.md)，新示例为 `rabbita/vectors.html`。0.11.0接续[风羽原位置、U/V、旗面及静风圆](BARBS_INTERACTION.md)，新示例为 `rabbita/barbs.html`。0.12.0接续[线等值线精确级别与inline标签](CONTOUR_INTERACTION.md)，新示例为 `rabbita/contours.html`。0.13.0接续[填色等值区、多环与孔洞](CONTOURF_INTERACTION.md)，新示例为 `rabbita/filled-contours.html`。下方安装命令对应0.17.0；使用 [Mooncakes 模块页](https://mooncakes.io/docs/Lampese/mathplotlib)
查看 registry 版本。维护者使用 `tools/verify_registry.py` 从全新、无 `moon.work` 的应用
安装并验证静态四目标和真实浏览器交互。
GitHub [v0.2.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.2.0)
是此前两个模块的源码版本包，原附件与历史记录保留不变。

## 安装一个模块

在应用的模块目录运行：

```sh
moon add Lampese/mathplotlib@0.17.0
```

静态出图只需在对应 executable 的 `moon.pkg` 导入根包：

```moonbit nocheck
import {
  "Lampese/mathplotlib",
}
```

```moonbit nocheck
fn main raise {
  let fig = @mathplotlib.figure(width=640, height=400)
  fig.set_title("Measurements")
  fig.plot([1.0, 2.0, 3.0], [2.0, 5.0, 4.0])
  println(fig.to_svg_checked())
}
```

将示例放入应用的 main package 后，按实际路径运行，例如：

```sh
moon run cmd/main --target native > chart.svg
```

运行 native 需 C 编译器；Wasm、Wasm-GC、JS 静态输出可按应用目标选择。
Python 不属于绘图库运行时依赖。

## 同一模块中的浏览器组件

浏览器应用会直接调用 Rabbita 框架 API。若应用尚未声明 Rabbita 框架，先运行：

```sh
moon add moonbit-community/rabbita@0.16.7
```

这声明的是应用直接调用的框架 API；MoonPlot 自身仍只发布一个模块。
Moon 不允许应用仅凭传递依赖直接导入框架。随后在 `moon.pkg` 中导入：

```moonbit nocheck
import {
  "Lampese/mathplotlib",
  "Lampese/mathplotlib/drawing",
  "Lampese/mathplotlib/rabbita" @plot_dom,
  "moonbit-community/rabbita",
  "moonbit-community/rabbita/html",
}
```

`@plot_dom.view(figure.to_drawing(), id=..., on_event=...)` 返回可组合的 Rabbita `Html`。
Rabbita 子包及其 browser executable 声明 `supported_targets = "js"`，静态 facade、
Scene、Drawing 与 SVG renderer 不导入 UI 包，公开模型中没有 UI 类型。

Mooncakes 的依赖声明在 module 层。因此安装统一模块时也会解析 Rabbita 及其传递依赖；
选择静态根包不会编译或链接 JS 组件。统一 module 不再使用独立 adapter 的依赖缓存或局部 `moon.work`。
固定 Rabbita `0.16.7`；其传递依赖会将统一依赖图中的 `moonbitlang/x` 解析到至少 `0.5.1`。
这不改变静态绘图 API 的平台边界。

应用负责 hover/selection/visibility/data 状态，并在 `rabbita.new` 的 builder 内创建状态。
样式可从安装包的 `rabbita/moonplot.css` 复制到应用静态资源；路径由应用的服务方式决定。
完整接入、事件、坐标与资源隔离契约见 [组件指南](../rabbita/README.md)。

## 从仓库运行示例

从仓库根目录运行，无需建立额外 workspace：

```sh
moon run cmd/preview --target native > chart.svg
moon build rabbita/cmd/demo --target js
python3 -m http.server 8765 --bind 127.0.0.1
```

打开 [双图交互示例](http://127.0.0.1:8765/rabbita/)。资源冲突专项示例先运行
`moon build rabbita/cmd/resources --target js`，然后打开
[资源隔离示例](http://127.0.0.1:8765/rabbita/resources.html)。
HTTP 服务的根目录必须是仓库根目录，示例会从根目录的 `_build` 读取 JavaScript。

## 从源码版本包运行

源码版本包包含唯一库归档的解压目录 `library/` 和独立应用 `example/`。
根 `moon.work` 显式列出 `library`、`example`，不指向原仓库，也不包含隐藏的 adapter workspace。
从解压根目录运行：

```sh
moon run example/cmd/static --target native > chart.svg
moon build example/cmd/app --target js
python3 -m http.server 8765 --bind 127.0.0.1
```

打开 [独立应用](http://127.0.0.1:8765/example/)。应用使用公开版本依赖与包导入，
组件 CSS 来自 `library/rabbita/moonplot.css`。这是显式源码 workspace 路线；
Mooncakes 安装路线只依赖 registry，不需要这个 workspace。
独立消费验收应分别检查实际源码归档和无 `moon.work` 的全新 registry 应用。

## 从早期模块路径迁移

| 早期路径 | 当前路径 |
| --- | --- |
| `mathplotlib/mathplotlib` | `Lampese/mathplotlib` |
| `mathplotlib/mathplotlib/drawing` | `Lampese/mathplotlib/drawing` |
| `mathplotlib/mathplotlib/scene` 等子包 | `Lampese/mathplotlib/scene` 等相同后缀 |
| `moonbit-community/moonplot-rabbita` | `Lampese/mathplotlib/rabbita`，建议别名 `@plot_dom` |
| 仓库 `adapters/rabbita/` | 仓库 `rabbita/` |

更新应用的 `moon.mod`，移除两个旧模块依赖，改为单个 `Lampese/mathplotlib@0.17.0`；
同步更新 `moon.pkg` 的包前缀。根包默认 alias 仍是 `@mathplotlib`，已有绘图方法调用无需改名。
浏览器组件显式写 `"Lampese/mathplotlib/rabbita" @plot_dom`，避免与 Rabbita 本身的 alias 冲突。
移除仅为两个旧模块建立的 workspace 条目；自己的其他 workspace 成员照常保留。

这次合并调整分发单位与导入路径，M2 的绘图、命中、SVG 资源作用域和交互范围保持不变。
[M2 验收记录](MILESTONE_M2.md)的 0.2.0 测试结果属于历史版本，不自动作为 0.2.1 发布证据。

## 历史：0.2.1 发布验收

- 合并后 `moon check --target all`、`moon info --target all`、`moon fmt` 通过。
- 全套测试：Wasm / Wasm-GC / Native 各 **22,264/22,264**，JS **22,285/22,285**（含 14 个交互适配测试）。
- 51 份接口仅模块路径变化，907 份 MoonBit 源码内容与合并前逐字节一致。
- Chrome 155 原双图 11 项、资源隔离 7 组通过，页面错误为 0；两份截图与原验收逐字节相同。
- 实际生产 ZIP 在仓库外的显式 workspace 中通过静态四目标与浏览器 5 项验收。
- dry-run 的解包 check 通过，服务端返回 `202 Accepted` 并明确说明 `No changes were made`。
  当前 CLI 将该非 200 状态误报为失败，日志退出码为 255；不把此预检记录为实际发布。

### 实际发布与 registry 验收

`Lampese/mathplotlib@0.2.1` 已于 2026-10-24 实际发布，服务器返回 **200 OK**。
公开 manifest 返回版本 0.2.1、构建成功、包可用且未撤回。

全新的仓库外项目在没有 `moon.work` 的情况下执行 `moon add`，安装到的 **486 个文件**
与正式生产 ZIP 逐一相同。纯静态应用只声明 MoonPlot，四目标 SVG 通过；
独立浏览器应用声明其直接使用的 Rabbita 框架，JS 构建和 Chrome 155 的 **5 项**交互/响应式检查通过，页面错误为 0。

正式包源码提交为 `e5393b9cffacb84105e947adb8c8e81776af083b`。
registry 验证工具随后补齐了应用框架声明的检查；绘图与交互源码没有后续修改。
本地证据保存在忽略目录 `.moonagent/checkpoints/Mooncakes-0.2.1/`。
复现 registry 消费时，下载对应版本的模块 ZIP 作为 `--expected-archive`，并从当前仓库运行：

```sh
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
  python3 tools/verify_registry.py --expected-archive /path/to/Lampese-mathplotlib-0.2.1.zip
```

工具需要 Playwright 和已安装的 Google Chrome（或 `BROWSER_CHANNEL=bundled`）。
它分别建立纯静态和浏览器消费者，真实安装 registry 包，核对源文件并运行应用；
不会用本地库 workspace 替代 registry。测试临时 HTTP 与浏览器均会关闭。

## 0.7.0 分布图发布验收

2026-10-25 已实际发布 `Lampese/mathplotlib@0.7.0`，服务端200 OK，公开构建成功且包可安装。
正式源码提交 `f5b55cda898e359cc839109c19044d73131e59b5`；[GitHub v0.7.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.7.0)
的模块ZIP、独立源码应用ZIP、manifest和SHA256SUMS均已完整回下载，逐字、远端摘要/大小与tag提交核对通过。

- 全套：Wasm/Wasm-GC/Native各22452/22452，JS22489/22489；新分布图Chrome13项与既有四例53项通过，均0页面错误。
- clean正式包在仓库外通过静态四目标与Chrome17项；实际registry全新应用同样通过，543份安装源文件与正式模块ZIP逐一相同。
- 模块ZIP：1980179 bytes，SHA256 `920a2a33c74f2797879ac295e76ccffd9289bb02af8bca6511d2afd6361fc2db`。
- 独立源码ZIP：2005511 bytes，SHA256 `3b83615a8969d2ae7c8afb93465ae68a49d800af79c6f6461333274ddb210e7e`。

[六角格](HEXBIN_INTERACTION.md)修正了旧真实分箱错误，中心、计数、聚合组与SVG会必要变化；
[小提琴](VIOLIN_INTERACTION.md)的KDE采样与各统计部位有独立身份。静态入口签名保留，穷尽匹配HitKind需处理新增分支。

## 0.8.0 离散曲线发布验收

功能、独立复审与中央验收已完成；2026-10-25实际发布返回200，公开构建成功且包可安装。
静态签名和14份旧SVG保持；Step原sample、Stairs原interval与ECDF实际returned slot通过同次绘制进入提示。

- 全套：Wasm/Wasm-GC/Native各22488/22488，JS22531/22531；info/fmt、八JS构建、结构与文档链接通过。
- 八个Chrome示例98项通过，页面错误为0；新离散例14项含实际整数事件可定位的原端点、横竖/填充切换、压缩、独立显隐/更新/重挂载、375px与CSS半径。
- 修复后仓库外dirty演练静态四目标+Chrome23项通过；包含两/三重复Step的物理命中与横轴吸附、ECDF末尾零权重重合返回槽。
- 独立复审：Step端点往返Native/JS各810次与各12控制；Stairs各29组、22实际XML/5000几何包含；ECDF各28组/26实际XML及最终source-tie bounded各26组。

正式源码提交`2f7aeb77c70499979b43273d1ea8a0b0504ba040`；clean正式包与全新registry应用均通过静态四目标/Chrome23，555份安装源逐一相同。
[GitHub v0.8.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.8.0)四附件已完整下载并核验逐字、远端digest/size与tag源码提交。

- 模块ZIP2087347 bytes，SHA256 `4588b872d933110fec36b2498ff30bcf96d61d2ae570b5532c7dbf33d0b7be43`。
- 独立源码ZIP2117382 bytes，SHA256 `e4e18ace990bdb00af49aec8a5aa870acd67a9a19419d883dd85681ebcd02367`。

所有dirty演练包仅保留开发记录，实际发布只使用clean正式归档；旧版本tag和附件不变。

## 0.9.0 Stem 发布验收

Stem原样本、真实杆段和圆头通过既有字段进入默认/自定义提示；旧签名、Unit返回、Container/N+2 artist及10份旧Stem/14份离散SVG保持。

- 四目标定向各133/133、adapter38/38；Root三组合四目标各3/3与dirty包静态四目标/Chrome25通过。
- 中央全套Wasm/Wasm-GC/Native各22505/22505、JS22550/22550；info/fmt/九JS构建、结构和40份MD/488本地链接通过。
- 九个真实Chrome示例110项通过、0errors；新Stem三卡12项含原索引洞、非零起点正负值、actual rod/head组件、clip、Area、显隐/更新/重挂载、CSS与375px。
- 独立Native/JS各23公开组、各8实际SVG与23个真实primitive匹配、旧Native8份SVG逐字、Scene2+context1组全部通过，11个生产源hash与中央匹配。
- 正式源码`95a34c3dc154f48fb3b83b7f37ecad3a0e8273c8`，clean包与全新无workspace registry均通过静态四目标/Chrome25；560份安装源与正式ZIP逐一相同。
- 实际publish200、公开success/has_package=true/yanked=false；[GitHub v0.9.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.9.0)四附件完整下载逐字、远端digest/size与tag源码SHA全部通过。
- 模块ZIP2179542bytes，SHA256 `352a7d165124952f0d13bf988e60c9927991c88a1a1d8fbcced6fbfa008562c5`。
- 独立源码ZIP2212594bytes，SHA256 `99934cca03b701938b30fe18acf0a42844b5ffb9fa6509002b3acf26e52d3a39`。

正式构建至网络验收闭环未改tracked文件；dirty演练包未上传。

## 0.10.0 Quiver 发布验收

实际箭杆与双箭翼带原tail X/Y、原i和只读VectorInfo U/V；通用value明确原V。双mode只physical，open head不增加填面或横轴吸附。原签名/Unit/Container/非finite整call校验与旧SVG保持。

Root外部dirty演练静态四目标/Chrome28项、三组合四目标各3/3、三个独立旧SVG逐字已通过；dirty包不上传。
- 定向W/WG/JS各155、Native156、Rabbita40全部通过；24份同target旧/新SVG逐字。Native golden限定本target，未以libm末位差误报生产回归。
- 独立Native/JS各18公开组、各8XML41targets、Native8旧SVG、Scene2+Backend2通过；14生产SHA与中央匹配。
- 中央Wasm/Wasm-GC各22520、Native22521、JS22567；十页面Chrome122项/0errors、三个SVG、42MD/498本地链接、info/fmt/10JS builds和结构全部通过。
- 正式源码`c9eb6bec526a2f6d2b1f6330a60ef616dd83a16a`，clean包和全新无workspace registry静态四目标/Chrome28通过；566安装源与正式ZIP逐一相同。
- 实际publish200，公开success/has_package=true/yanked=false；[GitHub v0.10.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.10.0)四附件完整下载逐字、远端digest/size与tag源码SHA全部通过。
- 模块ZIP2258118bytes，SHA256 `1bea6b23cbce9a240e004e22be02fbfbe7c70e335173ad8d132cf66eb7e9968f`。
- 独立源码ZIP2294805bytes，SHA256 `4f1552295d07ff44b02383d0b5e83ff200a823abaf1bf42cf6788aa449cf73dd`。

正式构建至网络闭环未tracked写入或commit；dirty演练未上传。

## 0.11.0 Barbs 发布验收

风羽实际shaft/羽枝、旗面及三边、完整calm disk携带原输入位置、原i和U/V，value明确为原V；middle/tip及rounded calm不改变原数据语义。两个旧入口签名、Unit、无Container、有效错误前缀与正常静态SVG保留。

- 空/zero无component不再改前一series；高级派生计数在转换及循环前检查finite/可表示总量，无任意小cap。
- identity失配的generic回退缺陷已修：known-slot共享disabled intent保持static；独立Native/JS各4组复审通过。原有限表各17组、每端10XML/36targets与20份同target旧SVG保留，16生产SHA与中央一致。
- 定向Native197、W/WG/JS各195、Rabbita42全过；immutable c9八fixture×四目标32SVG逐字，未复制旧writer或改golden。
- 中央W/WG各22543、Native22545、JS22592全过；info/fmt/11JS builds、11页面Chrome134项/0errors、三SVG与结构通过。
- 首Barbs浏览器runner即时读legend DOM导致失败，原证据保留；真实3→0/0→3响应式时序已记录，改为状态/DOM条件等待后12项通过，无sleep/生产改动或放宽断言，已过全库未重复。
- 外部dirty演练静态四目标/Chrome32与8真实整数风羽事件通过，未上传。正式clean41056和无workspace全新registry75023均静态四目标/Chrome32通过；573份安装源逐一匹配正式ZIP。
- 正式源码`0177b0cd77cc3cb05f108a2af49f561e3a0fd036`；实际publish10237 terminal0/200，公开success/has_package=true/yanked=false且checksum相同。
- [GitHub v0.11.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.11.0)四附件整下载68272 terminal0，字节/远端digest及size/tag源码SHA全部通过，未在下载中途比较。
- 模块ZIP2346216bytes，SHA256 `b87b76d3471b185124458e5b992dba1983456d47cde679b0632ef4aae48520e0`。
- 独立源码ZIP2386461bytes，SHA256 `ab9188c5c881f8c46f4176de83342c904067a289631328750ed44d08087ecc9d`。

正式builder至实际网络闭环Root HEAD保持0177且gitclean，无tracked写入或commit；dirty演练未上传。

## 0.12.0 线等值线发布验收

规则网格与三角网格等值线提供精确level、call series及原生成path槽，默认inline拆线两片保留归属。数据坐标表示clip前实际生成边的安全中点，屏幕坐标表示可见片段中点；两个hit mode均要求真实线段邻近。原签名、返回paths、Container与静态SVG保持；filled多环/孔洞留给下一片。详见[等值线交互](CONTOUR_INTERACTION.md)。

- producer限定Native199、其余三目标各198、Rabbita44通过，24份同target旧SVG与正式0177逐字相同。
- 首核心4717已合Root7f9c8f0；最终b71cc1c已合304d3f8，27owner文件（16production/3interfaces）逐一SHA一致。除BarbIntent私有类型可见性外，Contour生产自首核心未变。
- 真实双卡Chrome14项、0errors；31整数事件验证inline gap、mask、替换、独立图例、重挂载、CSS/letterbox及375px。外部public consumer Native/JS与Chrome36项、0errors通过。
- 中央W/WG22564、Native22566、JS22615与12页面Chrome148项/0errors全部通过；真实info/fmt/静态三SVG/docs/结构/diff过，无意外mbti。独立Native/JS各11公开组与4白盒、16实际XML与16旧SVG通过且无blocker。正式clean39728与无workspace全新registry28365均四静态/Chrome36通过，581份安装源逐一匹配。
- 正式源ae1ce6b4c45d17fd2c1fbee388525f5c7f713307/push41390；actualpublish40580 terminal0/200，公开API38331版本0.12/buildsuccess/haspackage/notyanked，metadata.checksum与正式module相同。
- [GitHub v0.12.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.12.0)创建39288与四附件整下载61598均terminal0，字节/远端digest/size/tag源码SHA全过；从clean builder至最终网络审计Root HEAD ae1不变且gitclean，无tracked写/commit。
- 模块ZIP2433308bytes/581files，SHA256 `ada8b34efaa9e013c285043fba697a7eb5696c16bc4c2f5aed5c5ee050a76666`；源码ZIP2476895bytes/604files，SHA256 `15584bc5159d339d5f23feda5e62e4ec0d4357a835fb0569d7982dc1dae8663e`。

## 0.13.0 填色等值区发布验收

规则与三角网格的填色区保留真实whole-region nonzero/evenodd规则、孔洞和分离岛间空白。提示含有限clip区间、旧有限代表值和原call系列；band索引保留requested空extension槽。两mode只在plot内实际填面命中，旧SVG margin paint保持静态；几何锚点不表示网格观测或指针处标量场值。详见[专项指南](CONTOURF_INTERACTION.md)。

- producer四目标各184/184、adapter46/46、8份同target旧SVG通过；31owner文件含18production/3interfaces与Root全同。三个真实反例均保留失败证据并修复。
- 独立Native/JS各9 public与5 Scene组通过；18实际XML/18份旧SVG、432独立几何查询一致，精确14a Native/JS各3组delta通过，无剩余blocker。
- 真实双卡Chrome14项/0errors，外部consumer Native/JS/actualinfo/fmt与Chrome41项/0errors通过。
- 中央唯一full30284 terminal0/268.45s：W/WG22589、JS22642、Native22591；actualinfo/fmt、13JS、13页面Chrome162项/0errors、三静态SVG/docs/结构/diff全部过，无意外mbti。
- 正式源87a3280f31fb3ba043da415f89eab6ad5a8ef59e/push68683；clean20806 terminal0、dirty=false，四静态/Chrome41过。
- actualpublish46591 terminal0/200；首API构建queued的snapshot/log保留，后API64558 terminal0版本0.13/buildsuccess/haspackage/notyanked、metadata.checksum与正式module相同。全新无workspace registry60742 terminal0，590安装源逐一匹配、四静态/Chrome41过。
- [GitHub v0.13.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.13.0)创建21562与四附件整下载72398 terminal0，bytes/digest/size/tag87a全过。最终audit2026-10-25T14:19:05.947223Z，Root从clean builder至网络闭环HEAD固定87a且gitclean，无tracked写/commit，之后明确解除freeze。
- 模块ZIP2503930bytes/590files，SHA256 `7372afea56bda7a91464f507da5bf61495958355914290a0eb4fc4ad947ae3e1`；源码ZIP2551348bytes/615files，SHA256 `ec030e46c161077851991d45396dce28d2618bd0803f9f26a75bf5780f8155a4`。

## 0.14.0 Tripcolor 发布验收

新增原面槽、真实有序顶点和逐面标量/顶点均值提示；保mask洞、全输入norm、原均值位模式与溢出省略、Unit/0Container和旧SVG。
默认Value/Vertex mean与中文自定义提示使用同一元数据。两个实际反例已修复：
源共线被屏幕舍入打开，以及共同scale丢失异量纲合法面；两轴独立2幂证明不改变静态writer。

中央唯一全套：Wasm/Wasm-GC各22611、Native22614、JS22666；14真实Chrome示例176项/0errors，info/fmt、14JS构建、三静态SVG、50MD/562本地链接和结构均通过。

正式源1215721c9e63e7036be9580ecd1560e7eabe0be3，实际publish200、公开success/has_package/未撤回/checksum一致；600份全新安装源、四静态/Chrome46以及GitHub四附件bytes/digest/size/tag全部通过。
模块ZIP2576088bytes/SHAad6d8b29519c75f25039e961daa2f9a74127bfc05b510fe1ba11a3d457f8c51f；source2627432bytes/627files/SHAa4700d81c5f3d26fa0912e9dcd9b80090e88a24d6eb62df90435a56dbc60ff76。
[GitHub v0.14.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.14.0)已完整下载核验。
完整验收与网络交付结果记录于[M13](MILESTONE_M13.md)和[执行检查点](MIGRATION_STATUS.md)。

## 0.15.0 Streamplot 发布验收

现有 streamplot、mesh 和 style-grid 入口保留旧积分、样式、返回 Set、Container 和 SVG。
新增连续线身的原 seed/edge、有限中点 U/V、同次样式原颜色标量及默认/自定义提示。
箭头仍静态，无法证明的样本和 prepared Line 不生成推测数据。
外部 consumer 已通过 Native/JS、真实 Chrome51（13 次流线整数事件、0 页面错误），
实际 info/fmt 与两个 private 接口核对通过。中央 prelude87978、唯一 full73204（265.69s）、postlude40698 全部通过：Wasm/Wasm-GC22631、Native22635、JS22688；15 页面 Chrome190/0errors，三静态 SVG、52 文档576本地链接、结构与差异检查通过，无额外接口变化。正式源67c0951：clean82436、actual publish93030/public35351、全新registry16095、GHcreate54326/完整下载40546均terminal0，601安装源与四附件逐一核同。finalaudit290642确认整个正式交付期HEAD/gitclean未变。
[GitHub v0.15.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.15.0)与[M14](MILESTONE_M14.md)记录结果。

## 0.16.0 Polar / Radar 发布验收

新增 typed `PolarAxes` 与 `Figure.add_polar_axes`，支持弧度输入的极坐标折线、散点和闭合轮廓雷达。
原theta/r及N点保持，数据独立圆形裁剪；非方形面板仍为真圆。显式方向/角偏移、径上限、刻度、
分类标签、标题与图例可设置。首片SVG和RabbitaDOM均可用，应用可更新数据和切换系列；极坐标悬停留后续片。

外部consumer Native/JS、Chrome56及真实SVG栅格裁剪检查已通过。中央唯一完整回归93615
在264.29秒内通过W/WG22644、Native22648、JS22701；16页面Chrome204/0errors、
三静态SVG、54份文档594本地链接、结构与预期接口检查均通过。正式clean5127、actualpublish89744、公开buildsuccessa46bad、全新registry61533和GitHubcreate9181/完整下载47226均0。607源同正式ZIP，四static/Chrome56；formal999至finalaudit30f5fc全程HEAD/gitclean不变，之后解除冻结。当前进度见[M15](MILESTONE_M15.md)与[执行检查点](MIGRATION_STATUS.md)。

## 0.17.0 Polar / Radar 原始数据提示发布验收

保留原弧度、半径与雷达类别；两种模式均需真实圆内物理近点。Rabbita默认及自定义提示、
均匀CSS缩放/letterbox坐标映射、圆形hover/selection高亮已验收。
中央W/WG22658、Native22662、JS22718及16页面Chrome204/0errors通过。
正式源`cedbf1651a8645fe3b77cce91fdfaa708437bdd0`，模块612源/2766969字节，SHA256为
`8102bd928f9c46189d3a3c4d0f2286043549a9e91a456b29cf221f758a2503f2`。
clean22726、actual publish92686、public success935e50、fresh registry37462、GitHub create44289
与四附件完整下载92054均终0。registry无workspace覆盖，612安装源逐一同ZIP、四static/Chrome59；
finalaudit2bb881确认formal builder至网络audit全程HEAD/gitclean不变后解除冻结。
