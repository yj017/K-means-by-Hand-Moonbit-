# M14：连续流线与生成场值提示

2026-10-25启动，2026-10-26实际交付0.15.0。精确基线
`1215721c9e63e7036be9580ecd1560e7eabe0be3`。核心、独立复审、外部接入、中央验收与实际分发全部通过。

沿现有流线的实际连续线段查看双线性采样的U/V与可选颜色标量，保留原种子尝试槽和生成边编号。
复用既有streamplot/mesh/style-grids入口和积分器；不复制完整Matplotlib参数集。

## 能力与边界

- [x] `HitKind::Streamplot`、readonly `StreamplotInfo`（seed_index/u/v/color_value?）、
  `HitInfo.streamplot`与facade factory；通用value恒为V。默认提示U/V与真实存在的Color value，
  自定义提示可格式化中文与单位。字段表示生成边中点的采样，不冒充原始网格观测或速度模长。
- [x] 保原seed尝试槽与joined trajectory的原edge槽，包括被拒绝seed与样式空洞；
  artist_index是实际body Line，series为原调用。实际成功写出的非零线段在plot内物理命中，
  两mode不按横轴跨空白吸附；preclip数据采样中点和clipped屏幕锚点分别保留。
- [x] 保旧有限 `(a+b)/2` 与原双线性采样运算；颜色标量来自同次旧style评估，
  不从色值反推或在鼠标处重采样。无法有限证明的新增语义保持静态，不新增异常。
- [x] 一份共享轨迹/edge数据，whole-Line一次identity/content检查、split Line只查本段，
  constant offset对齐actual valid runs；保持known-slot/cursor、旧Drawing和全部现有图类。
  geometry/guard/capture保持O(points+edges)，新增场采样仍使用既有线性axis locator，
  lookup成本单独为O(edges*(nx+ny))，不宣称整个构造严格线性。
- [x] 实际箭头shaft/head/bar（含Set未返回的shaft）统一owned-static，阻断旧generic y Point提示；
  保全部样式/paint/返回Set与一个完整Container。箭头组件语义留后续片。
- [x] 不匹配或未知prepared context保守静态并保provider completion，不扩LineContext API；
  维护image/inline/remove/clear与跨type/跨kind归属。旧integrator、seeding/occupancy、
  style/norm、签名/返回值、Container与同目标SVG保持。

## 当前实施与验收

- [x] 只读准备：精确121 Native98134/JS27224各三旧fixture、六actualXML/SVG通过；
  旧generic Point目标14/18/17、value为生成y，各1Container；返回数组与实际paint有不同索引。
  不是新语义验收，也没有把旧87a Native重标为121。
- [x] 实证空/拒绝stream调用串改前series：owner beforeNative87412 terminal2；
  窄修09b6353后82399 terminal0（stagnant/过短两子例），保空Set/1Container/静态legend。
  Root已在 M13 实际 audit 结束后审合为 99ea119。
- [x] producer首coherent Native core与三个场景12/12/6真实body Segment、原seed/edge/U/V/color及旧SVG。
- [x] owner bounded 四目标：Native59，其余各58，Rabbita50；12 次同目标旧新 SVG 逐字一致。独立 Native/JS public 三例各12/12/6 Segment、六 XML/六旧 SVG、240 次物理检查与 Scene6/Backend2 各8/8，通过 alias/生命周期/paint/prepared 控制。
- [x] 双卡真实 Chrome14、26 次整数事件/20 callback/12 geometry frame/6 negative、0 errors；默认/中文提示、更新/颜色可选/原 seed 空位/箭头静态、legend/remount/CSS375 通过。UI commit41e7977；实际 PNG56728bytes 已目视。
- [x] 外部 consumer 实际 Native65048、JS25542/e85669、Chrome73264：51 项、13 次新流线整数事件、0 页面错误；info/fmt 与两个 private 接口未变。
- [x] 一次中央 prelude87978→唯一 full73204/265.69s→postlude40698，全部 terminal0。Wasm/WG 各22631、Native22635、JS22688；15 页面 Chrome190/0errors，三静态 SVG/52MD576links/structure/diff 通过，无额外接口变更。最终流线 PNG 与已提交56728bytes逐字相同。
- [x] 正式 clean82436、actual publish93030/public35351、全新 registry16095 与 GitHub create54326/完整下载40546均terminal0；601安装源逐一同ZIP、四静态/Chrome51、四附件bytes/digest/size/tag一致。finalaudit290642确认正式67全过程HEAD/gitclean未变，之后解除freeze。

producer在独立managed branch `codex/m14-streamplot`负责core/own tests/专项指南；
Root负责中央文档、版本、外部接入与发布。首核心 b29（Root59888a2）已完整 source/interface 审核，追加 owning tests 与指南 807（Rootb1acc2e）不改生产代码。
reviewer 精确 b29 的 Native/JS public 与有限反例复审无 blocker；browser 七文件已提交为 41e7977，最终真实截图及接口均核对；Rootconsumer b3ddbc5。Root 已核对34owner源/75proof、22review源接口/46proof和六旧数学块，独立两个 archive SHA在原处核验。

[执行检查点](MIGRATION_STATUS.md) · [能力](CAPABILITIES.md) · [既有流线输入与积分](STREAMPLOT_PARITY.md)

中央之后只补发布忽略：科学图示例的八份开发 HTML/CSS 不进入库模块；Git 仓库保留这些开发页面。
发布源码包包含库与独立 consumer 示例。
它不改变 build/test 输入；没有为文档或发布忽略重复已通过的整库回归。
正式源提交后保持 Root tracked 文件和 HEAD 不变，直到实际网络交付核验结束。

正式源 `67c095118a45d27f6f3ab3d8fb3d3dff2a0e8877`；[GitHub v0.15.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.15.0)。
[完整历史与实际交付](archive/migration-status-through-2026-10-26-m14.md)保留原始失败、文档更正和精确证据。
