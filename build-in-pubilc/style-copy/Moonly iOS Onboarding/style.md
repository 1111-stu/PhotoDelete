# UI 风格指南

基于以下材料提取：

- `build-in-pubilc/style-copy/Moonly iOS Onboarding/`：Moonly onboarding PNG，单图 `1180 × 2676 px`。
- `build-in-pubilc/style-copy/feature/`：功能页 JPEG，单图 `1179 × 2556 px`。
- `ios-app/PhotoDelete/Views/Components/DesignSystem.swift`：共享尺寸、按钮、卡片、Toast 和布局。
- `ios-app/PhotoDelete/Views/Components/PhotoDeleteTheme.swift`：主题色、明暗模式和语义色。

代码 token 优先于截图推断；无法确认的内容标为“未在当前材料中发现明确证据”。Moonly 只作为深色、卡片化 iOS 视觉参考，不复制其占星业务、插画或订阅文案。

## 1. 概览

PhotoDelete 的视觉方向是“深色照片优先、低对比表面、暖色操作反馈”的 iOS 工具型界面。当前代码已形成可切换主题系统：`cleanBlue`、`sage`、`sand`、`graphite`，默认主题为 `sage`（`PhotoDeleteTheme.swift:18`）。

| 项目 | 规范 / 证据 |
| --- | --- |
| 平台 | SwiftUI iOS 16+，使用系统动态字体与 `Color` |
| 页面背景 | `backgroundTop` → `backgroundBottom` 的纵向主题背景 |
| 内容边距 | 默认 `20pt`；规则宽屏可扩展到 `32pt` |
| 卡片 | 半透明主题表面 + 细描边，默认圆角 `22pt` |
| 控件 | 默认圆角 `14pt`；最小可点击区域 `44pt` |
| 主按钮 | 主题强调色填充，使用 `primaryAccentOnFill` 文字 |
| 层级 | 背景 → surface → elevated surface → 浮层 / Toast |
| 参考气质 | 近黑背景、圆角照片卡、白色 CTA、半透明底栏、暖色点缀 |

## 2. 色彩体系

### 2.1 代码 token

`PhotoDeleteTheme.swift` 用 `0...1` RGBA 分量定义 light/dark 两套值，实际渲染由系统外观选择。源码位置：`ios-app/PhotoDelete/Views/Components/PhotoDeleteTheme.swift:145-218`。

| Token | Light | Dark | 用途 |
| --- | --- | --- | --- |
| `backgroundTop` | 按主题变化 | 按主题变化 | 页面上部背景 |
| `backgroundBottom` | 按主题变化 | 按主题变化 | 页面下部背景、UIKit 背景 |
| `surface` | 白色 alpha `0.82~0.84` | 白色 alpha `0.075` | 普通卡片、次级按钮、列表 |
| `elevatedSurface` | 白色 alpha `0.92~0.94` | 白色 alpha `0.11` | 浮层、输入框、Toast |
| `cardStroke` | 主题色 alpha `0.10~0.11` | 白色 alpha `0.115` | 卡片描边 |
| `hairline` | 主题色 alpha `0.13~0.14` | 白色 alpha `0.115` | 分割线 |
| `primaryAccent` | 按主题变化 | 按主题变化 | 主按钮、选中态、导航 tint |
| `primaryAccentPressed` | 按主题变化 | 按主题变化 | 按下态 |
| `primaryAccentOnFill` | 通常白色 | 近黑主题色 | 强调色填充上的文字 |
| `secondaryAccent` | 按主题变化 | 按主题变化 | 次要高亮、视频 / Live Photo |
| `success` | 按主题变化 | 按主题变化 | 完成、保留 |
| `warning` | 按主题变化 | 按主题变化 | 警告 |
| `danger` | 按主题变化 | 按主题变化 | 删除、破坏性操作 |
| `favorite` | 按主题变化 | 按主题变化 | 收藏 |

### 2.2 默认 `sage` 深色主题的源码值

| Token | RGBA 分量 | 近似 Hex |
| --- | --- | --- |
| `backgroundTop` | `(0.044, 0.052, 0.047)` | `#0B0D0C` |
| `backgroundBottom` | `(0.032, 0.038, 0.035)` | `#080A09` |
| `surface` | white alpha `0.075` | 透明白，不是纯色 |
| `elevatedSurface` | white alpha `0.11` | 透明白，不是纯色 |
| `primaryAccent` | `(0.62, 0.84, 0.72)` | `#9ED6B8` |
| `primaryAccentPressed` | `(0.50, 0.72, 0.60)` | `#80B899` |
| `secondaryAccent` | `(0.86, 0.78, 0.52)` | `#DBC785` |
| `success` | `(0.58, 0.88, 0.66)` | `#94E0A8` |
| `warning` | `(0.95, 0.78, 0.43)` | `#F2C76E` |
| `danger` | `(1.00, 0.44, 0.40)` | `#FF7066` |
| `favorite` | `(1.00, 0.62, 0.74)` | `#FF9EBB` |

### 2.3 文字与软色

| 角色 | 值 / token | 用途 |
| --- | --- | --- |
| 主文字 | dark `UIColor(white: 1, alpha: 0.96)` | 标题、正文 |
| 次文字 | dark `UIColor(white: 1, alpha: 0.62)` | 辅助说明 |
| 弱文字 | dark `UIColor(white: 1, alpha: 0.42)` | 次级提示 |
| 主色 soft fill | `primaryAccent.opacity(0.14)` | 选中背景、图标 tile |
| 主色 soft stroke | `primaryAccent.opacity(0.22)` | 轻描边 |
| 语义 soft fill | success / warning / danger `.opacity(0.14)` | 语义背景 |

### 2.4 截图参考色

Moonly 截图中可观察到：画布约 `#17181F`，表面约 `#22242A` / `#2C2D33`，主文字 `#FFFFFF`，辅助文字约 `#C8C9CD` / `#8E9098`，暖色高亮约 `#F3B14C`，进度珊瑚约 `#CE724D`。这些是截图推断，不覆盖 PhotoDelete 代码 token；`#6848F8` 等 Moonly 紫色不应直接加入 PhotoDelete。

### 2.5 使用规则

- 新 UI 使用 `PhotoDeleteStyle` 或 `PhotoDeleteTheme.current`，不要在 View 中硬编码 RGB。
- 删除用 `danger`，收藏用 `favorite`，完成用 `success`，选中和主操作用 `primaryAccent`。
- 浅色、深色和四个主题都必须检查文字对比度。

## 3. 字体排版

### 3.1 字体族

未在当前材料中发现自定义字体文件或显式 `fontDesign`。当前实现使用 `.body`、`.headline`、`.title2`、`.subheadline`、`.caption` 和 `.system(size:weight:)`，因此采用 iOS San Francisco 系统字体；优先 Dynamic Type。

### 3.2 代码字号层级

| 层级 | 代码值 | 字重 / 用途 |
| --- | --- | --- |
| 页面 / 卡片标题 | `.title2.weight(.semibold)`、`.headline` | Semibold |
| 正文 | `.body` | Regular |
| 次级正文 | `.subheadline` | Regular / Semibold |
| 标签 | `.caption`、`.caption.bold()` | 状态、表头 |
| Toast | `14pt` | Semibold，`DesignSystem.swift:540-580` |
| 紧凑标题 | `17pt` | Semibold |
| 紧凑说明 | `13~14pt` | Regular / Semibold |
| 小标签 | `12pt` | Semibold |

标题、正文默认使用 `primaryText`，辅助说明使用 `secondaryText`，弱提示使用 `tertiaryText`。文案统一走 `L10n` / `Localizable.xcstrings`。

## 4. 间距系统

| Token / 用法 | 值 | 来源 |
| --- | --- | --- |
| 页面水平边距 | `20pt` | `PhotoDeleteStyle.screenHorizontalPadding` |
| 规则宽屏边距 | `32pt` | `PhotoDeleteAdaptiveLayout` |
| 区块间距 | `24pt` | `PhotoDeleteStyle.sectionSpacing` |
| 根内容顶部 | `8pt` | `PhotoDeleteStyle.rootContentTopSpacing` |
| 行图标 | `32pt` | `PhotoDeleteStyle.rowIconSize` |
| 行最小高度 | `58pt` | `PhotoDeleteStyle.rowMinHeight` |
| 最小点击区域 | `44 × 44pt` | `photoDeleteMinimumTapTarget` |
| 常用卡片 padding | `16pt`、`18pt`、`24pt` | 组件源码显式值 |
| 常用内部间距 | `6/10/12/14/16pt` | 组件源码显式值 |

页面使用 `20pt` 外边距、`24pt` 区块间距；卡片内边距优先 `16~24pt`；局部值不要未经验证提升为全局 token。

## 5. 布局与栅格

- 使用 SwiftUI `VStack` / `HStack` / `ZStack`，不要按 `1179/1180px` 截图像素固定布局。
- 根内容通常 `frame(maxWidth: .infinity)`，宽屏通过 `readableContentMaxWidth` 限制阅读宽度。
- iPhone 默认左右 `20pt`，规则宽屏为 `32pt`。
- 页面背景使用 `backgroundTop` 到 `backgroundBottom` 的主题层次。
- 主要标题、正文和列表左对齐；onboarding / 授权页可居中；数字统计保持列基线。
- Moonly feature 截图显示“顶部标题 + 横向胶囊 + 大照片卡 / 统计卡 + 底部导航”的可复用结构，但底栏固定高度、blur 和所有页面都使用该结构，未在当前材料中确认。
- 未发现 Web breakpoint、CSS grid 或桌面断点；iOS 适配通过 size class 和可读宽度完成。

## 6. 组件样式

### 6.1 卡片 / 容器

| 属性 | 规范 |
| --- | --- |
| 背景 | 普通 `theme.surface`；浮层 `theme.elevatedSurface` |
| 圆角 | 默认 `22pt`，`RoundedRectangle(..., style: .continuous)` |
| 描边 | `theme.cardStroke`，通常 `1pt` |
| 内边距 | `16/18/24pt`，按内容密度选择 |
| 阴影 | 普通卡片不强制；浮层使用 `floatingShadow` |
| 入口 | `.photoDeleteCard()`，`DesignSystem.swift:607-610` |

### 6.2 主按钮

使用 `.photoDeletePrimaryButton()` / `PhotoDeletePrimaryButtonStyle`。填充为 `theme.buttonPrimaryFill`，文字为 `theme.buttonPrimaryText`，标签通常 `.body.weight(.semibold)`，宽度可撑满容器。按下态使用 `primaryAccentPressed` 或样式自带透明度 / 缩放。

### 6.3 次按钮与破坏性按钮

- 次按钮 `.photoDeleteSecondaryButton()`：`surface` 背景、`primaryAccent` 文字、`primaryAccentSoftStroke` 描边，用于取消、稍后等次要路径。
- 破坏性按钮 `.photoDeleteDestructiveButton()`：文字 `danger`；未按下背景约 `danger.opacity(0.12)`，按下约 `0.18`，描边 `danger.opacity(0.28)`，`1pt`；禁用整体约 `0.42`；按下约 `0.78`，`scaleEffect(0.985)`；动画 `.easeOut(duration: 0.14)`。

### 6.4 列表行 / 设置项

行最小高度 `58pt`，水平 padding 常见 `16pt`；图标框优先 `32pt`；标题用 `primaryText`，副标题用 `secondaryText`，状态值用 `tertiaryText` / 语义色；分隔线使用 `hairline`。统一开关、复选框、radio 的品牌参数未在当前材料中发现，应优先采用原生 SwiftUI 控件并匹配 tint。

### 6.5 图标、Toast、授权卡

- `PhotoDeleteStyle.iconTint(for:)`：删除 / trash → `danger`；favorite / heart → `favorite`；video / livephoto → `secondaryAccent`；screenshot / iphone / photo / album → `primaryAccent`。
- Toast：胶囊 + `elevatedSurface.opacity(0.94)`，水平 padding `14pt`、垂直 `11pt`、内部间距 `10pt`；文字 `14pt semibold`；阴影 `radius 10pt, x 0, y 5pt`；来源 `DesignSystem.swift:540-580`。
- 授权卡：图标 `largeTitle.weight(.medium)`；标题 `.title2.weight(.semibold)`；内容间距 `20pt`；整体 padding `24pt`；CTA 最大宽度 `180pt`；来源 `PhotoAuthorizationCard`。

### 6.6 其它组件状态

| 组件 | 证据 |
| --- | --- |
| Tab / 底栏 | 存在主题导航 tint；Moonly 有半透明底栏，但 PhotoDelete 统一高度和 blur 未确认 |
| 输入框 | `searchFieldFill = elevatedSurface`，`searchFieldStroke = primaryAccentSoftStroke`；统一高度未确认 |
| Modal / Sheet | 使用 SwiftUI 系统 presentation；统一 detent / 遮罩未确认 |
| Alert | 未发现品牌化样式，优先系统 Alert |
| Loading / Skeleton | 未发现明确 token |
| Empty state | 卡片 + 系统图标 + 主题文字；专用插画未确认 |

## 7. 阴影与层级

层级顺序为：页面背景 → `surface` → `elevatedSurface` → Toast / 浮动操作 → 系统 sheet / alert。

| 用法 | 值 |
| --- | --- |
| 浮层阴影 | light 黑色 alpha `0.07~0.09`；dark 黑色 alpha `0.24~0.26` |
| Toast 阴影 | `radius: 10pt, x: 0, y: 5pt` |
| 普通卡片 | 不使用重阴影，主要靠表面差异和描边 |
| 描边 | `cardStroke` / `hairline` |

截图层次主要靠背景、表面明度差、照片内容和透明叠层，不应用大面积黑色投影。

## 8. 动画与过渡

### 已确认

| 场景 | 属性 | 时长 / 曲线 | 来源 |
| --- | --- | --- | --- |
| 破坏性按钮按下 | scale、opacity | `.easeOut(duration: 0.14)` | `DesignSystem.swift` |

### 未确认 / 推断

截图是静态材料，未提供页面转场、卡片滑动、进度条、底栏动画的时长、延迟或 easing。未在当前材料中发现全局 `animation`、`transition` 或 spring token。若新增动画，应短时、低幅度、以触控响应为主，不把 Moonly 的动效推断为 PhotoDelete 必须规格。

## 9. 圆角

| 组件 | 值 | 说明 |
| --- | --- | --- |
| 普通卡片 | `22pt` | `cardRadius` |
| 按钮 / 输入框 / 控件 | `14pt` | `controlRadius` |
| 胶囊 | `Capsule` 或高度的一半 | Toast、标签、操作控件 |
| 圆形图标背景 | `Circle` | 状态、选中图标 |
| Moonly 大卡片参考 | 约 `16~24pt` | 截图推断，不覆盖代码 token |

代码应优先使用连续圆角，避免无来源的 8pt、12pt 等额外半径扩散。

## 10. 不透明度与透明效果

| 场景 | 值 / 规则 | 来源 |
| --- | --- | --- |
| dark `surface` | white alpha `0.075` | `PhotoDeleteTheme.swift` |
| dark `elevatedSurface` | white alpha `0.11` | `PhotoDeleteTheme.swift` |
| light `surface` | white alpha `0.82~0.84` | `PhotoDeleteTheme.swift` |
| light `elevatedSurface` | white alpha `0.92~0.94` | `PhotoDeleteTheme.swift` |
| 主色 soft fill | opacity `0.14` | `PhotoDeleteTheme.swift:83` |
| 主色 soft stroke | opacity `0.22` | `PhotoDeleteTheme.swift:84` |
| 语义 soft fill | opacity `0.14` | `PhotoDeleteTheme.swift:86-93` |
| 禁用破坏性按钮 | overall opacity `0.42` | `DesignSystem.swift` |
| Toast | `elevatedSurface.opacity(0.94)` | `DesignSystem.swift:557` |
| Moonly 照片叠层 | 半透明深色胶囊 / 玻璃感 | 截图推断，具体 alpha 未确认 |

透明表面要配合文字对比度；不能把照片染色后的混合像素直接定义成纯色 token。