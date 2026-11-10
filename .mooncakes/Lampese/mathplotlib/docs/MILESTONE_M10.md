# M10：Barbs 风羽图交互

创建日期：2026-10-25。状态：**已验收交付0.11.0**。Mooncakes与GitHub实际发布及全新安装核验通过。
只扩已有barbs及barbs_with_options，不扩Streamplot、一般样式参数或Matplotlib完整API。

## 固定合同

- [x] 保留旧签名、Unit、实际component顺序和无Container；后项无效数据保留有效前缀，不改为全call原子验证。
- [x] 仅新增HitKind::Barbs，复用只读VectorInfo U/V，value原V、原输入i、原pivot前x/y及call label；middle/tip位置不冒充tail。
- [x] shaft/羽枝捕获实际非零Segment；旗面复用真实三角形Quadrilateral(a,b,c,c)，可见描边收三真实edge Segment；calm复用实际filled disk的全Sector，无新Shape或Part。
- [x] 两mode均physical；无通屏XNearest、虚构风根/端点观测或三角bbox；保留实际component artist身份与索引洞。
- [x] 共享call表与常数component view，O(N+P)，每part只校验自己的1/2/3点；不能每component全量复制/扫描N，也不能因后项无效移除有效前缀。
- [x] Line prepared-context匹配source才给语义；变更path/identity或缺context provenance保守static，不退回错误的generic Line/Scatter端点提示。

## 两个已证实修复

- [x] zero/empty/fill_empty=false无新component时，不串改前一普通Line或旧Barbs的series；保留旧静态auto-legend条目与颜色行为。46e5e3b及公开SVG逐字控制已验证。
- [x] advanced在to_int与展开循环前拒绝非finite派生magnitude/effective值、不可表示的flag/full/总component计数，复用InvalidQuiver错误。正常计算顺序/正常SVG不变；不新增任意小数量cap。f586978，相关四目标各8项通过。
- [x] basic有限U/V导致norm溢出时仍保留实际合法shaft；tiny norm underflow、无效scale与calm原行为保持，不修造不存在的羽枝。

## 验收与交付

- [x] basic/options原数据、tail/middle/tip、flip、flag/full/half/rounded calm、zero/length0和width0的真实几何。
- [x] 旗面fill/stroke与calm填充分别按实际paint判断；one-vertex polyline无Segment，Log仅羽枝合法、clip/反轴/非线性按实际capture。
- [x] input副本/identity/content/旧Drawing、samecolor/多panel、图像/contour/Line移除、有效prefix与既有Line行为。
- [x] 每target旧/新SVG逐字基线、独立实际XML/公开consumer复审、必要四目标与adapter测试。
- [x] 可运行DOM，真实shaft/羽枝/旗面/圆内触发原X/Y/U/V、独立显隐/更新/重挂载、CSS/letterbox与375px。
- [x] 中央info/fmt/结构/全套与既有浏览器回归；clean包、实际Mooncakes/registry与GitHub四附件完整下载。

## 已运行依据与待办

- 核心cd0319d（Root48f8cb4）：Native84705的14项与8旧SVG逐字控制通过；公开只追加Barbs kind，复用VectorInfo。
- Root公开Native50470：basic/反轴8Segment、advanced15或width0仅4填面目标，原数据与两mode物理命中通过；五SVG与正式0.10.0逐字。
- 双卡UI：Chrome62943的12项、46真实整数命中、375px与CSS映射通过；Root目视桌面与移动端，真实截图与七文件SHA已冻结。
- 外部dirty消费32443：四目标static与Chrome32项通过，含8个精确整数风羽事件；只用于开发验证，未上传。
- Root组合19355：四目标各3项通过，覆盖flag/Area、calm/Hex和普通Line既有XNearest优先规则。
- 独立Native69717发现同值points.copy导致Scene identity miss后退generic Line/Scatter端点。edb6559（Root7fcb70c）已合入O(1) known-slot intent/disabled共享view；Native43项及独立Native/JS各4组复审通过，唯一blocker解除。
- 最终专项Native197、W/WG/JS各195与Rabbita42全部过；32份同target旧新SVG逐字。Root29文件SHA精确匹配最终producer。
- 中央四目标全套通过：W/WG各22543、Native22545、JS22592；11页面Chrome134项/0errors、info/fmt/11JS、三静态SVG和结构通过。首Barbs runner的legend即时count失败已保留；真实异步时序证实为runner race，状态/DOM完成等待后12项通过，未重跑已过full。
- 正式源0177b0cd77cc3cb05f108a2af49f561e3a0fd036；clean41056与registry75023均静态四目标/Chrome32通过，573安装源逐一相同。publish10237实际200/公开success/haspackage/notyanked/checksum相同；GitHub四附件整下载68272后字节/digest/size/tagSHA全过。
- 正式builder至网络闭环Root HEAD0177及gitclean保持，无tracked写入或commit，dirty演练未上传。[发布记录](PUBLISHING.md#0110-barbs-发布验收)与[GitHub v0.11.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.11.0)。

定点只读Native62148与独立98036保存正式c9旧SVG及prefix/label/count controls，它们属于旧generic基线，不算新语义验收。
高级Inf→Int2147483647仅安全计数probe，未实际运行巨量循环；累计计数边界测试也只检查计数，不展开。
producer负责core/IR/backend/own tests与Barbs指南；Root负责版本、中央文档、consumer、UI及最终交付；独立review复核精确源码和实际几何。
详见[执行检查点](MIGRATION_STATUS.md)、[能力](CAPABILITIES.md)与[安装](PUBLISHING.md)。
