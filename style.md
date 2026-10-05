# 删图 · 设计规范（Design Spec）

> **本文件是 PhotoDelete 的唯一设计规范，后续 UI 一律严格按此执行。**
>
> 三方对应关系（改 UI 前先读本文件）：
> - 视觉基准（细节以实际渲染为准）：`designs/home-prototype.html`
> - 代码实现（token 与组件，禁止绕开）：`PhotoDeleteTheme.swift` / `DesignSystem.swift` / `HomeView.swift`
> - 文案：`Localizable.xcstrings`（源语言 zh-Hans，key 即中文原文）
>
> 最近更新：2026-10-05（首页改造落 SwiftUI 后同步）。旧版 style.md 的基础 token 表已按实际代码重写。

---

## 1. 设计语言总览

- **近黑画布 + 中性暗面**：背景 `#0A0A0D`，卡片 `#16161A`，浮层 `#1E1E24`。不用蓝调、不用半透明白叠加出灰雾。
- **单一琥珀行动色**：琥珀（`#F3B14C`）只负责「主操作 / 选中 / 导航 tint / 合计价值」。
- **两张暖色渐变入口卡**：珊瑚（待整理）与琥珀（随机整理），深色墨字。
- **两套卡片语言，不混用**：
  - **彩色入口卡** = 渐变填充 + 深色墨字 + 同色系进度条（卡内不出现琥珀）；
  - **深色数据卡** = `#16161A` + 白字 + 至多一个琥珀「合计值」，明细数值一律中性灰。
- **数字一律无千分位**（2974 / 1470 / 1024，不是 2,974）。
- 界面安静、照片优先；层级靠表面明度差与留白，不靠描边和阴影堆叠。

## 2. 色彩

### 2.1 基础 token（`PhotoDeleteTheme.moonly`，dark 值）

| Token | 值 | Hex | 用途 |
| --- | --- | --- | --- |
| `backgroundTop` | 0.039/0.039/0.051 | `#0A0A0D` | 页面背景上端 |
| `backgroundBottom` | 0.031/0.031/0.039 | `#08080A` | 页面背景下端、UIKit 背景 |
| `surface` | 0.086/0.086/0.102 | `#16161A` | 普通卡片、分组列表（`.photoDeleteCard`） |
| `elevatedSurface` | 0.118/0.118/0.141 | `#1E1E24` | 浮层、输入框、次级按钮、Toast |
| `cardStroke` | 白 9% | — | 卡片描边（`.photoDeleteCard` 自带，克制使用） |
| `hairline` | 白 7.5% | — | 分割线 |
| `floatingShadow` | 黑 30% | — | 浮层阴影 |
| `primaryAccent` | 0.953/0.694/0.298 | `#F3B14C` | 琥珀：主操作、选中、导航 tint、合计值 |
| `primaryAccentPressed` | 0.788/0.541/0.196 | `#C98A32` | 琥珀按下态 |
| `primaryAccentOnFill` | 0.04/0.035/0.03 | — | 琥珀填充上的文字 |
| `secondaryAccent` | 1.00/0.78/0.48 | `#FFC77A` | 次级暖色 |
| `success` / `warning` / `danger` / `favorite` | — | — | 语义色：完成 / 注意 / 删除 / 收藏，按语义使用不装饰 |

文字色（`PhotoDeleteStyle`，不随主题变）：
`primaryText` 白 96%、`secondaryText` 白 62%、`tertiaryText` 白 42%。

### 2.2 渐变入口卡 token（`PhotoDeleteTheme`，明暗一致）

| Token | 值 | Hex |
| --- | --- | --- |
| `coralGradientTop` | 1.00/0.62/0.49 | `#FF9E7D` |
| `coralGradientBottom` | 0.949/0.439/0.290 | `#F2704A` |
| `coralInk` | 0.180/0.059/0.024 | `#2E0F06` |
| `amberGradientTop` | 1.00/0.784/0.369 | `#FFC85E` |
| `amberGradientBottom` | 0.941/0.604/0.133 | `#F09A22` |
| `amberInk` | 0.102/0.071/0.024 | `#1A1206` |

渐变方向：`LinearGradient(topLeading → bottomTrailing)`（对应原型 135°）。

### 2.3 琥珀使用规则（硬约束）

- 琥珀 = 合计价值、可操作、选中、导航 tint。
- **深色卡内至多一个琥珀数值**（如专项清理头部的「预计可清理」），明细数值一律 `secondaryText`。
- **彩色渐变卡内不出现琥珀**：文字一律用对应 ink 色，进度条用 ink 实心 + ink 18% 轨道。
- 琥珀不用于「已完成」状态（进度条在深色卡上不染琥珀）。

## 3. 字体与数字

| 层级 | 规格 | 实现 |
| --- | --- | --- |
| 页面大标题 | 34 / 700 | `HomeView.homeTitleBar` |
| Section 标题 | **14 / 700 白** + 可选右侧 12.5 / 600 琥珀值 | `PhotoDeleteSectionHeader` |
| 渐变卡标题 | 16.5 / 700（ink 色） | `HomeView.pendingReviewCard` / `randomReviewFanCard` |
| 渐变卡大数字 | 31 / 700（单位 14 / 600 @72%） | `RollingNumberText` |
| 渐变卡价值 | 标签 11 @72% + 值 18 / 700 | `pendingReviewCard` |
| Band 段 | 标签 11.5 medium 次级 + chevron 8；计数 23 / 700 白；可释放 10.5 次级 | `periodBandSegment` |
| 列表行名称 | 15 / 600 白 | `cleanupRow` / `toolRow` |
| 列表行数值 | 15 / 600 `secondaryText` | 同上 |
| 行副标题 | 11.5 `secondaryText` | `toolRow` |

**数字格式（硬约束）**：一律 `PhotoDeleteCountFormat.plain(_:)`（= `String(count)`，无千分位、不受 locale 影响）；大数字加 `.monospacedDigit()`。金额/容量走 `CleanupStatsFormatter.space(_:)`（已 `.grouping(.never)`）。

## 4. 组件规范

### 4.1 卡片容器

- 标准卡片：`.photoDeleteCard(radius: 22)`（`surface` 底 + 连续圆角）。
- 同一组内容用一个外层卡片，内部用内缩 18pt 的 1pt `hairline` 分隔（`insetHairline`）；不在卡中套同等重量的卡。

### 4.2 渐变入口双卡（首页）

- 一行两张，**等高 158**、间距 12、圆角 22。
- **珊瑚卡（待整理）**：标题 → 大数字「N 张」 → Spacer → 「预计可释放」+ 值 → **7pt 进度条沉底**（ink 实心填充 + ink 18% 轨道）。整卡 ink 色文字。点击 → 本年周期整理。
- **琥珀卡（随机整理）**：标题 + 「最多 N 项」 + 底部居中**扇形牌轮**装饰（3 张 46×62、白描边 2、±24°、弧半径 104、静息摊开）。点击 → 随机整理。
- 实现：`HomeView.duoRow / pendingReviewCard / randomReviewFanCard / CoralProgressBar / RandomFanDecoration / HomeFanArt`。

### 4.3 分段 Band（按时间段）

- Section 标题「按时间段开始」+ 一张卡内 3 等分段（本周/本月/本年），段间 1pt 内缩 13/12 的分隔线。
- 段内容：标签+chevron（次级 11.5）→ 计数（23/700 白）→ 「可释放 X」（10.5 次级）。
- 实现：`periodBandSection / periodBandSegment / bandDivider`。

### 4.4 列表行（专项清理 / 工具）

- 结构：32pt 图标 tile（白 7% 底、圆角 11、图标 17 `secondaryText`）+ 名称 15/600 白 + 右侧值 15/600 次级 + chevron 12 弱色。
- 内边距 13/18；行间 `insetHairline`；行为 `Button(.plain)`。
- 实现：`cleanupRow` / `toolRow`。

### 4.5 顶栏

- 左侧大标题 34/700；右侧操作按钮。
- 右上删除入口当前为**占位**：iOS 26+ 用液态玻璃圆形按钮（`.buttonStyle(.glass)` + `.buttonBorderShape(.circle)`），老系统回落 `elevatedSurface` 实心圆钮；点击暂无行为（入口细节待定）。

## 5. 动效（均尊重「减弱动态效果」）

| 场景 | 规格 | 实现 |
| --- | --- | --- |
| 数字滚动 | 0.9s easeOut；首页大数字 delay 0，band 三段 0.22/0.30/0.38 | `RollingNumberText` |
| 进度条生长 | 0.26s 延迟 + 0.95s easeOut | `CoralProgressBar` |
| 扇形摊开 | 0.62s easeOut，每张错峰 0.09s，进场一次 | `RandomFanDecoration` |

不做：滚动视差、点击波纹、分区滚动渐入（原型手法，不落 App）。

## 6. 首页结构（唯一顺序）

```
大标题「整理」+ 右上删除占位
渐变双卡：待整理（珊瑚） | 随机整理（琥珀）
按时间段开始：本周 / 本月 / 本年
专项清理：相似与重复 / 视频 / 截图 / 大文件（头部合计 = 各项之和）
工具：图片压缩 / 视频压缩
```

数据全部来自现有计算（`DataManager`），不得在页面造指标：

| 位置 | 数据源 |
| --- | --- |
| 待整理张数 / 进度条 | `libraryStats`（total − reviewed / reviewed÷total） |
| 预计可释放 | `librarySizeText`（年周期 estimatedSizeMB 汇总） |
| Band 三段 | `currentPeriodSummary(for:)` |
| 专项清理 | `cleanupQueue(for:)` 的 `estimatedSpaceMB` / `assetCount` |

已知缺口（如实显示，待数据侧补齐）：视频队列 `estimatedSpaceMB` 恒为 0、无截图队列 → 两行可能显示 0.0 MB / 无值。

## 7. 边界与待办（本轮之外）

- 底部为系统 TabView（未做浮动胶囊标签栏）。
- 回收站 / 最近删除功能未做（顶栏仅占位）。
- iPad 宽屏下 158 高双卡会被拉宽，如需限制可给 dashboard 列 `frame(maxWidth: 560)`。
- 全仓仍有其他页面的旧分组数字格式（SettingsView、AlbumBrowserViews 等），后续统一扫尾为无千分位。

## 8. 实施锚点（文件地图）

| 内容 | 文件 |
| --- | --- |
| 主题 token | `ios-app/PhotoDelete/Views/Components/PhotoDeleteTheme.swift` |
| 组件与静态色 | `ios-app/PhotoDelete/Views/Components/DesignSystem.swift`（`PhotoDeleteSectionHeader` / `PhotoDeleteCountFormat`） |
| 首页 | `ios-app/PhotoDelete/Views/HomeView.swift` |
| 文案 | `ios-app/PhotoDelete/Localizable.xcstrings` |
| 视觉原型 | `designs/home-prototype.html` |

---

## 9. 产品图标生成 Prompt（保留）

```text
Create a premium iOS app icon for “PhotoDelete”, a privacy-first on-device photo cleanup app.

Concept:
A single elegant amber deletion mark forming a subtle abstract photo frame, with one small empty corner suggesting decluttering and space. The symbol should communicate photo organization, cleanup, and clarity without showing a literal trash can.

Visual direction:
Minimal, refined, quiet, high-end utility app.
Deep charcoal black background with a warm amber focal symbol.
Use one brand color only: muted luminous amber.
No extra rainbow colors, no multiple-hue gradients, no text, no letters, no UI screenshot, no camera illustration, no literal garbage bin.

Material and lighting:
Soft anodized metal or premium glass-like symbol, very subtle depth, restrained highlight, clean edge definition.
The amber mark should feel precise and calm, not playful or aggressive.
The background should be near-black charcoal with a barely perceptible warm undertone.
Strong silhouette at small sizes, excellent contrast, instantly recognizable at 60px.

Composition:
Centered symbol, generous negative space, balanced optical weight.
Rounded-square iOS icon canvas.
The symbol should occupy approximately 55% of the canvas.
No border, no shadow extending outside the icon, no decorative particles.

Style:
Apple-quality product icon, modern editorial minimalism, crisp vector-like geometry, sophisticated dark mode aesthetic, premium photography utility app.

Output:
1024x1024 square, opaque background, no transparency, no text, no watermark.
```
