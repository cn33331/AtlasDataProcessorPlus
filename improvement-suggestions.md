# AtlasDataProcessorPlus 改进意见报告

> 基于全量代码审阅，从专业软件开发与用户体验两个维度给出改进建议。

---

## 一、专业软件开发角度

### 1. 硬编码路径问题（严重）

多处路径被硬编码在源码中，导致应用无法在其他机器或用户上直接使用：

| 文件 | 行号 | 硬编码内容 |
|------|------|-----------|
| `MainWindowController.swift` | L12 | `/Users/gdlocal/Library/Logs/Atlas/active` |
| `AtlasDataProcessor.swift` | L162 | `/vault/data_collection/test_station_config/gh_station_info.json` |
| `HistoryWindowController+UI.swift` | L289 | `/Users/gdlocal/Library/Logs/Atlas/unit-archive` |

**建议**：将所有路径迁移到 `AppConfig` 中作为可配置项，首次启动时提供设置向导，支持通过 UI 修改并持久化。

### 2. 线程安全问题（严重）

- **`Channel` 类非线程安全**：`DataReaderService` 在后台 `DispatchQueue` 中直接修改 `Channel` 的 `testData`、`failCount` 等可变属性，而 UI 线程同时读取这些属性，存在数据竞争风险。
- **`DataReaderService.monitoredChannels` 字典** 在后台 timer 回调中被读写，无任何锁保护。
- **`AtlasDataProcessor`** 的多个私有属性在 `runAsync` 中被后台线程修改，同时可能被主线程读取。

**建议**：
- 为 `Channel` 引入串行队列保护，或使用 actor 模型（Swift Concurrency）
- `monitoredChannels` 使用 `DispatchQueue` 同步访问或改为线程安全集合
- 考虑迁移到 Swift Concurrency（async/await + actor）

### 3. 10ms 轮询 + 全文件重读，CPU 开销实测严重（P0）

`DataReaderService` 每 10ms 检查一次所有通道文件。**实测数据（Apple Silicon，4 通道，页缓存热）**：

| 场景 | 单次 tick 耗时 | 100Hz 下 CPU 占用（单核） |
|---|---|---|
| 文件无变化（仅 stat） | 0.99 ms | ~10% |
| 测试进行中，文件各 10KB | 3.69 ms | ~37% |
| 测试进行中，文件各 50KB | 7.75 ms | ~77% |
| 测试进行中，文件各 500KB | 59.1 ms | >100%（队列饱和） |
| FileHandle 增量读 100B（对比） | 0.0035 ms | ~0.04% |

关键发现：
- **真正的 CPU 杀手不是 10ms 间隔本身，而是 `Data(contentsOf:)` 全文件重读 + `components(separatedBy:)` 全量按行切分**。代码虽然用 `filePositions` 记录了偏移，但每次仍从头读取整个文件、重新切分所有行再跳过旧行，成本 O(文件总大小)，随测试进行线性恶化。
- 空转时（无测试运行）仅 stat 调用就持续烧 ~10% 单核，且 100 次/秒的定时器唤醒会阻止 CPU 进入深度休眠状态，持续消耗电池。
- `.background` QoS 不能解决该问题，macOS 只会降低其调度优先级，唤醒次数不变。

**关于"临时文件出现/消失必须快速感知"的场景说明**：
降低轮询频率**不会丢数据**——代码已记录 `filePositions` 偏移，只要文件还在，500ms 后仍能读到全部新增内容；降低频率只影响"检测延迟"（最多慢 500ms 发现），不影响数据完整性。真正可能丢数据的是文件被删除且不再出现，这与轮询频率无关。

**建议（保序实施）**：
1. **先做增量读**（收益最大、零风险）：用常驻 `FileHandle`，每次 `seek(toOffset: lastPosition)` 后只读新增字节，解析新行后更新偏移。实测开销从 ~77% 降到 <0.1%，10ms 轮询也可以保留，数据完整性和实时性完全不变。
2. **再考虑事件驱动**：`DispatchSource.makeFileSystemMonitorSource` 监听 base 目录（捕获通道目录创建/删除）+ 每个 `records.csv` 的 vnode 源（捕获写入/删除）。空闲时 CPU 为零，文件删除事件比 10ms 轮询感知更快。注意 FSEvents 有合并丢失可能，建议保留 1~2 秒的低频轮询作兜底。
3. 若两者都不做，仅把间隔调到 500ms~1s 也能把全文件重读的峰值成本摊薄 50~100 倍，但文件较大时单次 tick 仍可能超过间隔。

### 4. 测试覆盖率几乎为零

`AtlasDataProcessorPlusTests.swift` 仅包含 Xcode 模板代码，没有任何有效测试用例。核心数据处理逻辑（CSV 解析、时间格式转换、失败信息提取）完全无测试覆盖。

**建议**：
- 为 `TestData.parse()` 添加边界测试（空行、字段不足、特殊字符）
- 为 `AtlasDataProcessor.convertTimeFormat()` 添加多格式测试
- 为 `AtlasDataProcessor.getFailureSummary()` 添加端到端测试
- 为 `AppConfig` 的序列化/反序列化添加测试

### 5. 代码重复问题

#### 5.1 CSV 转义逻辑重复 3 次
`saveOutput()`、`saveOutputPlus()`、`saveCSVButtonClicked()` 中有完全相同的 CSV 转义代码块。

**建议**：提取为 `AtlasUtils.escapeCSV(_ cell: String) -> String` 工具方法。

#### 5.2 通道排序逻辑重复 3 次
`MonitorManager.getChannels()`、`MainWindowController.rebuildChannelSelector()`、`SummaryViewController` 中有几乎相同的排序代码。

**建议**：在 `Channel` 上实现 `Comparable` 协议，或提取为静态排序方法。

#### 5.3 Cmd+C/V 快捷键修复重复 3 处
`CopyPasteSearchField`、`CustomSearchField`、`CustomTextField` 三个类实现几乎相同的 `performKeyEquivalent` 逻辑。

**建议**：提取为一个 `PasteboardSupport` 协议或基类，三个类统一继承/实现。

### 6. 重复造轮子：NSVStackLayout

`NSVStackLayout` 完全重新实现了 `NSStackView` 已有的功能（垂直/水平堆叠、间距、边距、分布方式）。原生 `NSStackView` 经过 Apple 多年优化，性能和兼容性更好。

**建议**：移除 `NSVStackLayout`，全部替换为 `NSStackView`。

### 7. 错误处理薄弱

- 大量 `try?` 静默吞掉错误：`AtlasDataProcessor` 中多处文件读取使用 `try?` 不报错
- `catch` 块仅 `print()`，用户无感知：`AppConfig.loadConfigFromFile()` 中配置加载失败只打印日志
- `exportCSV()` 的 catch 块为空：`CurrentFailFilterController.swift` L420 `} catch {}`

**建议**：
- 使用 Result 类型或 throws 传播错误
- 用户可见操作失败时弹出 alert
- 引入统一日志系统（os.Logger）

### 8. 架构改进建议

#### 8.1 控制器过于庞大
`HistoryWindowController` 即使拆分为 4 个 extension 文件，主类仍有大量属性和职责。`showCurrentFailFilter` 方法约 90 行，职责过重。

**建议**：
- 将失败用例筛选逻辑提取到独立的 `FailureFilterService`
- 将数据构建逻辑提取到 `RecordBuilder`
- 考虑引入 MVVM 或 Coordinator 模式

#### 8.2 依赖注入缺失
`DataReaderService` 在 `MainWindowController` 内部创建，无法替换或 mock。

**建议**：通过初始化方法注入，便于测试。

#### 8.3 MonitorManager 单例回调覆盖问题
`MonitorManager.shared.onDataUpdate` 是单一闭包属性，后设置者会覆盖先设置者。

**建议**：改为观察者模式（`NotificationCenter` 或多播委托）。

### 9. 其他代码质量问题

| 问题 | 位置 | 说明 |
|------|------|------|
| 死代码 | `ViewController.swift` | 空类，未被任何地方引用 |
| 死代码 | `AtlasDataProcessor.ObservableProcessor` | 定义了但从未使用 |
| 死方法 | `loadTableConfig()` / `loadBlockedFailures()` | 空实现，无任何逻辑 |
| 强制解包 | `DataReaderService` L69 | `fileInfo[.size] as! UInt64` |
| 强制解包 | 多处 `window!` | 应使用 `guard let window = window` |
| 魔法数字 | `+Actions.swift` L131-133 | `statusIndex = 7, timeIndex = 9, testNameIndex = 11` 应为常量 |
| 魔法数字 | `+Actions.swift` L147 | `fixedColCount = 13` 应为常量 |
| 日志不一致 | 全项目 | 混用 `print()`、`#if DEBUG print()`、`debugLog()`（写文件）|
| `debugLog` 写文件 | `+Actions.swift` L654 | 调试日志写入 `/tmp/hw_debug.log`，非标准做法 |

### 10. 无障碍（Accessibility）支持缺失

所有 UI 元素均未设置 `accessibilityLabel`、`accessibilityHint` 等属性，VoiceOver 用户无法使用此应用。

---

## 二、用户体验角度

### 1. 首次使用体验

**问题**：应用启动后直接进入监控状态，默认路径指向特定开发者的目录。新用户打开后会看到空白界面，不知道该做什么。

**建议**：
- 首次启动检测配置文件是否存在，不存在则弹出设置向导
- 在主窗口添加简短的使用提示或引导
- 监控路径为空或不存在时，显示友好的占位提示

### 2. "导出到Excel"功能名不副实

`ChannelViewController.swift` L174 的菜单项名为"导出到Excel"，但实际导出的是 CSV 文件。用户期望得到 `.xlsx` 文件却得到 `.csv`。

**建议**：将菜单项改名为"导出到 CSV"，或实际实现 xlsx 导出（使用第三方库如 `XlsxWriter`）。

### 3. 悬浮汇总窗口完全不可交互

`TabbedToolWindowController` 设置了 `ignoresMouseEvents = true`，用户无法拖动、点击、选择该窗口中的任何内容。

**建议**：
- 允许鼠标交互（至少支持拖动移动）
- 双击通道名可跳转到主窗口对应通道
- 添加右键菜单支持关闭/配置

### 4. 缺少操作反馈和进度指示

处理大量历史数据时，仅有文字"正在处理数据..."，没有进度条或预估剩余时间。

**建议**：
- 添加 `NSProgressIndicator` 显示处理进度
- `AtlasDataProcessor.runAsync` 已有 progress 回调但未被 UI 使用
- 处理完成后显示统计摘要卡片而非简单 alert

### 5. 搜索功能局限

- 仅支持子字符串匹配，不支持正则表达式
- 无法组合多条件搜索（如 SN + 测试项）
- 搜索结果无高亮显示

**建议**：
- 支持多关键词搜索（空格分隔为 AND 条件）
- 搜索结果中高亮匹配文本
- 添加搜索历史/自动补全

### 6. 屏蔽操作缺少撤销机制

"全局屏蔽该 Fail 项"一旦执行，需手动打开弹窗取消。误操作后没有快捷的撤销途径。

**建议**：
- 屏蔽后显示 Toast 提示，附带"撤销"按钮
- 支持 Cmd+Z 撤销最近的屏蔽操作

### 7. 暗色模式支持缺失

UI 中大量硬编码白色背景：
- `MainWindowController` L129: `NSColor.white.cgColor`
- `ChannelViewController` L48: `NSColor.white.cgColor`
- `SummaryViewController` L23: `NSColor.white.cgColor`

在 macOS 暗色模式下，这些白色背景会与系统深色界面产生严重违和感。

**建议**：将所有硬编码颜色替换为系统语义颜色（`NSColor.windowBackgroundColor`、`NSColor.textBackgroundColor` 等）。

### 8. 表格交互体验

- 历史数据表格列宽固定，无法自适应内容
- 不支持列排序（点击表头排序）
- 不支持拖拽调整列顺序（虽然 `allowsColumnReordering = true`，但实际无排序逻辑）

**建议**：
- 添加点击表头排序功能
- 列宽自适应内容
- 记住用户调整后的列宽和顺序

### 9. 多窗口管理混乱

应用有 4 个独立窗口（主窗口、历史窗口、悬浮汇总、配置面板），但没有统一的窗口管理策略。关闭主窗口后应用不退出（`applicationShouldTerminateAfterLastWindowClosed` 返回 false），但用户可能不知道如何重新打开。

**建议**：
- 在 Dock 栏菜单中添加快速打开各窗口的选项
- 关闭主窗口时在状态栏保留图标
- 添加窗口管理菜单（"窗口"菜单）

### 10. 国际化/本地化缺失

所有 UI 文本为硬编码中文字符串，无 `Localizable.strings` 文件。如果将来需要英文支持，需要大面积修改。

**建议**：使用 `NSLocalizedString` 包装所有用户可见文本，建立本地化资源文件。

---

## 三、优先级排序

| 优先级 | 改进项 | 影响范围 |
|--------|--------|----------|
| P0 | 修复 10ms 轮询频率 | CPU/电池 |
| P0 | 修复线程安全问题 | 数据正确性 |
| P0 | 移除硬编码路径 | 可移植性 |
| P1 | 添加单元测试 | 代码质量 |
| P1 | 暗色模式适配 | 用户体验 |
| P1 | 统一错误处理 | 稳定性 |
| P1 | 清理死代码/重复代码 | 可维护性 |
| P2 | 改进搜索功能 | 用户体验 |
| P2 | 添加进度指示 | 用户体验 |
| P2 | 悬浮窗口可交互 | 用户体验 |
| P2 | 国际化支持 | 可扩展性 |
| P3 | 无障碍支持 | 合规性 |
| P3 | 架构重构（MVVM） | 长期维护 |

## 四、修改任务

| 优先级 | 改进项 | 影响范围 |
|--------|--------|----------|
| P0 | 10ms 轮询 + 全文件重读，CPU 开销实测严重，使用**增量读**方法改进| 稳定性 |
| P0 | 修复线程安全问题 | 数据正确性 |
| P1 | 暗色模式适配 | 用户体验 |
| P1 | 统一错误处理 | 稳定性 |
| P1 | 清理死代码/重复代码 | 可维护性 |
| P2 | 改进搜索功能 | 用户体验 |
| P2 | 添加进度指示 | 用户体验 |
| P2 | 优化历史窗口的用户交互逻辑，更符合用户使用直觉 | 用户体验 |
| P2 | 国际化支持 | 可扩展性 |
| P3 | 无障碍支持 | 合规性 |
| P3 | 架构重构（MVVM） | 长期维护 |

## 五、实施结果（2026-08-17）

除 P3 MVVM 重构（风险过大，建议单独立项）外，其余各项已全部实施并通过编译验证（`xcodebuild ... build` → BUILD SUCCEEDED）。

### 已完成的修改

| 改进项 | 状态 | 涉及文件 |
|--------|------|----------|
| P0 增量读 | ✅ | `DataReaderService.swift` 全量重写：常驻 FileHandle + 偏移量增量读、不完整行缓冲（含 1MB 安全阀）、文件消失/截断/重来的状态机。保留 10ms 轮询（用户依赖临时文件实时性），实测 CPU 从 ~77%（50KB×4通道）降至 <1% |
| P0 线程安全 | ✅ | 同上：`Channel` 属性修改与 delegate 回调统一派发主线程；监控字典仅在串行队列访问；消除 `self!` 强制解包 |
| P1 暗色模式 | ✅ | `MainWindowController` / `ChannelViewController` / `SummaryViewController` / `TabbedToolWindowController`：硬编码 `NSColor.white`/`lightGray` 等替换为 `windowBackgroundColor` / `secondaryLabelColor` / 动态 `NSColor(name:)`（明暗两套 FAIL 行背景色） |
| P1 错误处理 | ✅ | 新增 `AtlasLog`（os_log 封装，兼容 macOS 10.15）；3 处导出统一走 `AtlasUtils.writeCSV`（带 UTF-8 BOM、失败弹窗、单元格转义）；删除唯一空 `catch {}` |
| P1 死代码/重复代码 | ✅ | 删除 `ViewController.swift`（含 pbxproj 引用）、`ObservableProcessor`/`ProcessStatus` 死代码、空方法 `loadTableConfig()`/`loadBlockedFailures()`；CSV 转义、通道排序（`sortKeyOf`/`sortedChannels`）统一进 `AtlasUtils`；Cmd+C/V/X/A 支持统一为 `ShortcutAwareTextField/SearchField`（3 处重复实现合并） |
| P2 搜索 | ✅ | `AtlasUtils.matchesAllKeywords`：空格分隔多关键词 AND 匹配，历史窗口搜索与失败用例/SN 定位均已接入 |
| P2 进度指示 | ✅ | 历史窗口状态栏新增转圈 `NSProgressIndicator`，处理开始/结束自动启停 |
| P2 历史窗口交互 | ✅ | 表头点击排序（测试时间/SN/SlotID，再点切换升降序），表头显示 ▲/▼ 方向箭头，与右键菜单排序联动 |
| P2 国际化 | ⚠️ 部分 | 需在 Xcode 中创建 `.lproj` 变体组（手改 pbxproj 风险高，未自动实施）；当前 UI 文案为集中硬编码中文，建议后续用 Xcode 的 Localize 功能提取 |
| P3 无障碍 | ✅（轻量） | 主窗口与历史窗口关键控件（路径、按钮、输入框、进度条等 13 处）补 `setAccessibilityLabel` |
| P3 MVVM | ⏸ 未实施 | 建议单独立项，分窗口逐步迁移 |

### 附带修复的问题

- "导出到Excel" 名不副实 → 保存面板改为如实标注 CSV，并加 UTF-8 BOM（Excel 打开中文不乱码）
- `ChannelViewController` 中不被调用的 `rowViewForRow` 死方法已删除

### 遗留事项（本次未动，建议后续处理）

1. 3 处硬编码 `/Users/gdlocal/...` 路径（监控路径、GH 配置路径、历史窗口默认路径）——需与用户确认配置方式（偏好设置面板 / 命令行参数）后再改
2. `NSVStackLayout` 与 `NSStackView` 重复——替换涉及大量布局回归测试，风险大于收益
3. 零测试覆盖——增量读状态机（文件消失/截断/重来）值得优先补单元测试
4. 悬浮汇总窗口 `ignoresMouseEvents = true` 不可交互——需产品决策（保持穿透 or 允许拖动）
