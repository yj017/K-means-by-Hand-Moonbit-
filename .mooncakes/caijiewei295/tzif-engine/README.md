# TZif Engine

面向 MoonBit 的 IANA TZif v2/v3 解析与时区转换库。它从 `Bytes` 读取 TZif
数据，提供 UTC 与本地时间之间的双向转换，并处理 DST 跳跃、重叠以及 TZif
文件中的 POSIX TZ footer。核心库不依赖文件系统或 libc 时区 API。

## 功能范围

- 解析 TZif v2/v3 的双数据块、transition、time type、designation、leap record、
  `ttisstd` / `ttisut` 指示器和 POSIX TZ footer；
- 校验 header 计数、数据长度、transition 顺序、UTC offset、leap record、指示器和
  footer 一致性，并对输入规模设置解析上限；
- 支持 UTC → 本地时间，以及本地时间的 unique、gap、overlap 判定；
- 对 overlap 提供全部 UTC 候选或 `PreferEarlier` / `PreferLater` 选择策略；
- 使用 `Int64` 处理时间戳，支持历史秒级偏移和 2038 年之后的转换；
- 解析 POSIX TZ 的 `J<n>`、`n`、`M<m>.<w>.<d>` 规则与 wall、standard、UTC
  时钟基准，用于显式 transition 范围外的外推；
- 提供 ISO-8601 解析与格式化、活动 offset 来源、transition 明细和区间查询；
- 提供十六进制 TZif 输入的命令行工具，便于在不引入文件系统依赖的情况下检查数据。

核心库在 Native、Wasm、Wasm-GC 和 JavaScript target 上检查与测试。

## 快速开始

在项目根目录运行内置示例：

```bash
moon run examples --target native
```

输出：

```text
1970-01-01T00:00:00Z becomes 1970-01-01T08:00:00+08:00 CST
embedded America/New_York: 2026-03-08T03:00:00-04:00 EDT
```

命令行工具接收 TZif 文件内容的十六进制表示。例如在带有系统 zoneinfo 的环境中：

```bash
TZIF_HEX=$(xxd -p /usr/share/zoneinfo/America/New_York | tr -d '\n')
moon run cli --target native -- utc-to-local "$TZIF_HEX" 1772953200
```

输出：

```text
2026-03-08T03:00:00-04:00 EDT
```

CLI 还提供 `info`、`local-to-utc`、`resolve-local`、`transition` 和
`transitions` 子命令。运行 `moon run cli -- --help` 查看完整参数。

## 库 API

消费方需要导入 facade 与公开类型包：

```moonbit
import {
  "caijiewei295/tzif-engine" @tzif,
  "caijiewei295/tzif-engine/types",
}
```

解析 TZif 并进行 UTC → 本地时间转换：

```moonbit
fn convert(
  tzif_bytes : Bytes,
  utc_time : Int64,
) -> Result[@types.LocalDateTime, @types.TzifError] {
  let timezone = match @tzif.load(tzif_bytes) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  @tzif.utc_to_local(timezone, utc_time)
}
```

本地时间可以先通过 `resolve_local` 分类为 `Unique`、`Gap` 或 `Ambiguous`；
需要直接得到 UTC 时间戳时，可使用 `local_to_utc` 并传入 overlap 选择策略：

```moonbit
fn choose_later_overlap(
  timezone : @types.TzifData,
) -> Result[Int64, @types.TzifError] {
  let local_time = match @tzif.parse_iso_local("2026-11-01T01:30:00") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  @tzif.local_to_utc(timezone, local_time, @types.PreferLater)
}
```

`load` 会校验解析结果。调用方若直接构造公开的 `TzifData`，应在查询或缓存前调用
`validate`。

## 嵌入时区数据

核心 API 接收 `Bytes`，调用方可以在宿主侧读取 TZif 文件，也可以在编译期嵌入所需的
zone。本仓库的 [`golden/america_new_york_2026b.mbt`](golden/america_new_york_2026b.mbt)
包含 tzdb 2026b 的 `America/New_York` 样例，并记录了来源、SHA-256 和许可证信息。

应用只需嵌入实际使用的时区。更新数据时，应同时记录 tzdb release、源路径、校验值和
许可证。

## 验证

```bash
moon fmt --check
moon check --target all --warn-list +73 --deny-warn
moon build --target all --warn-list +73 --deny-warn
moon test --target all --warn-list +73 --deny-warn
moon info --target all
```

测试包括格式与模型校验、UTC/local 转换、DST gap/overlap、POSIX footer、ISO-8601、
transition 查询、真实 IANA 数据互操作向量，以及截断和单字节 mutation 输入。测试所需的
TZif fixture 均在仓库内构造或固定，不依赖运行时系统时区数据库。

## 设计边界

- 只解析 TZif v2/v3；不提供时区名称到文件路径的查找；
- 不下载或自动更新 IANA 时区数据库，文件读取和输入大小策略由宿主负责；
- leap record 会被保留和校验，但不参与 POSIX civil-time 计算；
- 不提供本地化时区名称；
- ISO-8601 文本接口限定四位年份和可互操作的 numeric offset，底层 TZif reader
  仍接受 RFC 9636 允许的更宽 offset 范围；
- 仓库中的 `America/New_York` 仅用于示例、测试和基准，不是完整 tzdb 分发。

## 文档

- [架构设计](docs/架构设计.md)
- [项目申报书](docs/项目申报书.md)

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
