# M11：线等值线级别与 inline 标签

创建日期：2026-10-25。状态：**已完整验收并正式交付**。正式版本0.12.0。
从正式源`0177b0cd77cc3cb05f108a2af49f561e3a0fd036`继续；只补已有regular contour、tricontour及委托wrapper，不扩filled等值区或完整Matplotlib参数。

## 固定合同

- [x] 仅追加`HitKind::Contour`；`value`为精确resolved level，`series`为不可变call label；不新增ContourInfo或伪网格cell/vector/band/error/fraction数据。
- [x] `point_index`是原`ContourSet.segments()`生成path槽，inline两片保留同槽；`artist_index`属于当前实际片段，不冒充原网格观测索引。
- [x] `data_x/y`为实际emitted valid-run边在viewport clip前的安全几何中点；screen锚点为可见clip中点。它们描述生成线的几何，不是原样本或指针插值。
- [x] 只捕获实际非零Segment，两mode均physical；无生成端点Point、全panel XNearest、跨无效/Log gap连线、闭环内部填面或bbox命中。
- [x] 保留旧签名、ContourSet复制getters、levels/paths/stitch/mask/locator、Container、静态legend/颜色及正常SVG；不重算轮廓。
- [x] 默认inline clabel保原按几何相等擦线范围，迁移每个已证明Contour自己的level/槽/label；其他call、普通Line或Barbs不串贴，失效intent不能因新fragment复活。
- [x] identity/content/prepared-context provenance失配保守static且无generic Line回退；clear/remove/image/inline重排仍对齐，旧Drawing保持不可变。
- [x] 共享小lineage、每fragment一次几何快照/guard和每edge O(1)回调；准备cursor保持线性，无每边完整path扫描或每fragment复制全grid。
- [x] 两线API空/无path时不改前一series，保留静态legend/颜色及空Container行为；不趁机修改filled入口。

## 验收与交付

- [x] regular/tri/wrapper、非均匀grid、同level多path、mask/corner_mask、反轴/Log/clip与真实paint。
- [x] inline两片、实际擦除gap、inline=false、Text无target、同色/同几何calls、普通Line/Barbs及Area组合。
- [x] 原path/level复制、当前identity/content/失效lineage、移除与清空、旧Drawing及有界多边压力。
- [x] 精确旧源的同target SVG逐字、独立实际XML/公开consumer复审、必要四目标与Rabbita。
- [x] 真实双卡DOM、级别默认/自定义提示、更新/图例/重挂载、CSS与375px；源码与截图均须真实编译/运行。
- [x] 中央info/fmt/结构/全套和既有Chrome；clean包、实际Mooncakes/registry与GitHub完整下载。

只读准备已运行正式c9六个小公开Native场景：旧regular/tri是generic几何Y提示，仅末path有call label；inline后七片都丢失series。filled双环保留真实evenodd孔洞且无目标，后续独立处理。此旧基线不算新语义验收。

首核心4717ae9已合为Root7f9c8f0；规则/三角/inline首Native6/6和24份四目标同target旧SVG逐字通过。真实七文件UI已提交e3901c3，隔离构建/info与Chrome14/14、0errors及真实桌面/375px截图通过。Root公开consumer925d742：Native、JS编译及Chrome36项/0errors通过，含inline双片、tri裁剪锚点、默认/自定level和Area绘制顺序。

producer的bounded guards/paint/lifecycle、四目标/adapter及指南已合入，独立复审按精确4717及最终无行为变化的priv修正核验。中央37734 terminal0：W/WG22564、Native22566、JS22615，12页面Chrome148项/0errors、三静态SVG、真实info/fmt/结构与本地链接检查全部通过。独立Native/JS各11公开组与4白盒全部通过，无blocker；16实际XML与16同target旧SVG一致。正式clean39728、actualpublish40580/API38331、freshregistry28365及GitHub四附件整下载61598全部通过。581份安装源逐一匹配正式ZIP，四目标静态/Chrome36通过；正式源ae1ce6b4c45d17fd2c1fbee388525f5c7f713307从builder至网络闭环HEAD不变且gitclean，无tracked写入或commit。

[GitHub v0.12.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.12.0)已交付；下一片[M12](MILESTONE_M12.md)继续填色等值区，不重复M11验收。

[执行检查点](MIGRATION_STATUS.md) · [能力](CAPABILITIES.md) · [路线图](MIGRATION_PLAN.md)
