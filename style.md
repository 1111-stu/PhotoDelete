# UI 风格指南

> 本文档已根据当前 PhotoDelete UI review 更新。前半部分记录现有实现，后半部分“当前目标规范”是后续视觉实现的优先依据。

基于以下材料提取：

- `build-in-pubilc/style-copy/Moonly iOS Onboarding/`：Moonly onboarding PNG，单图 `1180 × 2676 px`。
- `build-in-pubilc/style-copy/feature/`：功能页 JPEG，单图 `1179 × 2556 px`。
- `ios-app/PhotoDelete/Views/Components/DesignSystem.swift`：共享尺寸、按钮、卡片、Toast 和布局。
- `ios-app/PhotoDelete/Views/Components/PhotoDeleteTheme.swift`：Dark 主题色、表面层级和语义色。

代码 token 优先于截图推断；无法确认的内容标为“未在当前材料中发现明确证据”。Moonly 只作为深色、卡片化 iOS 视觉参考，不复制其占星业务、插画或订阅文案。

## 1. 概览

PhotoDelete 当前只有 Dark 主题，视觉方向是“深色照片优先、低对比表面、暖色操作反馈”的 iOS 工具型界面。后续颜色调整应围绕同一套 Dark token 展开，不再设计或维护多主题切换。

| 项目 | 规范 / 证据 |
| --- | --- |
| 平台 | SwiftUI iOS 16+，使用系统动态字体与 `Color` |
| 页面背景 | `backgroundTop` → `backgroundBottom` 的纵向 Dark 背景 |
| 内容边距 | 默认 `20pt`；规则宽屏可扩展到 `32pt` |
| 卡片 | 半透明主题表面 + 细描边，默认圆角 `22pt` |
| 控件 | 默认圆角 `14pt`；最小可点击区域 `44pt` |
| 主按钮 | 主题强调色填充，使用 `primaryAccentOnFill` 文字 |
| 层级 | 背景 → surface → elevated surface → 浮层 / Toast |
| 参考气质 | 近黑背景、圆角照片卡、白色 CTA、半透明底栏、暖色点缀 |

## 2. 色彩体系

### 2.1 代码 token

`PhotoDeleteTheme.swift` 当前只服务 Dark 主题。源码位置：`ios-app/PhotoDelete/Views/Components/PhotoDeleteTheme.swift`。

| Token | Dark 角色 | 用途 |
| --- | --- | --- |
| `backgroundTop` | 暗色上部背景 | 页面上部背景 |
| `backgroundBottom` | 暗色下部背景 | 页面下部背景、UIKit 背景 |
| `surface` | 暗色普通表面 | 普通卡片、次级按钮、列表 |
| `elevatedSurface` | 暗色 raised 表面 | 浮层、输入框、Toast |
| `cardStroke` | 低透明度白色 | 只用于必要边界或选中态 |
| `hairline` | 低透明度白色 | 分割线 |
| `primaryAccent` | 琥珀 | 主按钮、选中态、导航 tint |
| `primaryAccentPressed` | 深琥珀 | 按下态 |
| `primaryAccentOnFill` | 近黑色 | 琥珀填充上的文字 |
| `secondaryAccent` | 低饱和暖色 | 次要高亮 |
| `success` | 低饱和绿 | 完成、保留 |
| `warning` | 暖黄 | 警告 |
| `danger` | 珊瑚红 | 删除、破坏性操作 |
| `favorite` | 玫红 | 收藏 |

### 2.2 当前 Dark 主题的源码值

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
- 只需围绕 Dark 主题检查文字对比度、降低透明度后的可读性和高对比度辅助设置。

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
- 页面背景使用 `backgroundTop` 到 `backgroundBottom` 的 Dark 主题层次。
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
| 浮层阴影 | Dark 黑色 alpha `0.24~0.26` |
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
| 主色 soft fill | opacity `0.14` | `PhotoDeleteTheme.swift:83` |
| 主色 soft stroke | opacity `0.22` | `PhotoDeleteTheme.swift:84` |
| 语义 soft fill | opacity `0.14` | `PhotoDeleteTheme.swift:86-93` |
| 禁用破坏性按钮 | overall opacity `0.42` | `DesignSystem.swift` |
| Toast | `elevatedSurface.opacity(0.94)` | `DesignSystem.swift:557` |
| Moonly 照片叠层 | 半透明深色胶囊 / 玻璃感 | 截图推断，具体 alpha 未确认 |

透明表面要配合文字对比度；不能把照片染色后的混合像素直接定义成纯色 token。

## 11. 当前目标规范

### 11.1 核心方向

PhotoDelete 采用“冷中性深色照片画布、单一琥珀品牌色、低饱和语义色、紧凑系统分组”的视觉方向。重点应放在照片内容、整理进度和明确的安全操作上，而不是装饰性颜色或大量浮动卡片。

不建议增加第三种品牌主色。当前已有 `primaryAccent`、`secondaryAccent`、`success`、`warning`、`danger` 和 `favorite`，问题是语义色被当作首页装饰色使用，并且页面内存在硬编码颜色。

### 11.2 色彩职责

- 琥珀色：主要操作、选中、进度、导航 tint。
- 珊瑚红 `danger`：删除和危险状态。
- 玫红 `favorite`：收藏。
- 低饱和绿 `success`：完成、成功和保留。
- 暖黄 `warning`：权限、等待和注意事项。
- 视频、截图、大文件、相似照片属于内容分类，默认使用中性图标或统一低饱和琥珀 tint，不再各自分配高饱和颜色。

### 11.3 暗色目标 token

当前暗色主题的 `surface` 与 `elevatedSurface` 只相差很小的透明度，叠加大量 1pt 描边后会产生灰雾感。建议迁移到更明确的近不透明中性色：

| Token | 建议值 | 用途 |
| --- | --- | --- |
| `canvas` | `#0B1017` | 页面和非照片区域背景，偏冷的深蓝黑 |
| `surface` | `#121A24` | 普通分组和卡片，保持中性蓝灰，不使用棕色底 |
| `surfaceElevated` | `#1A2532` | 浮层、输入框、操作栏和选中容器 |
| `separator` | 白色 6% 到 8% | 分割线和极弱边界 |
| `cardStroke` | 白色约 6% | 只用于选中态、输入框和必要浮层 |
| `textPrimary` | `#F5F6F7` | 标题和主要内容 |
| `textSecondary` | `#A8ADB4` | 辅助说明和次级信息 |

### 11.4 关于深蓝与琥珀

首页和设置页当前的“脏感”判断基本成立，但根因不是琥珀品牌色本身，而是主题把暖黑背景、暖色描边、半透明白色表面和多个暖色语义值叠在了同一层级。卡片因此出现棕灰污染，层级也不够干净。

建议采用“冷深蓝表面 + 单一琥珀行动色”的组合：

- 页面背景、普通卡片、raised surface 全部切换为冷中性蓝黑；蓝色只负责空间和材质，不承担按钮语义。
- 琥珀保留给主操作、选中态、进度和导航 tint；不要把琥珀作为卡片填充、卡片描边或大面积背景光晕。
- 类似 iPhone Pro 的蓝色可以作为参考方向，但应使用低饱和、接近石墨蓝的 `#121A24` / `#1A2532`，不要直接使用高饱和宝蓝。这样照片中的暖色会成为视觉焦点，界面本身更安静、更高级。
- 首页的随机整理、往年今日、时间段和专项清理卡片使用同一套冷表面，仅保留小面积图标 soft fill；不要每张卡片染成不同色。
- 设置页使用冷表面分组和更弱的分割线，琥珀只出现在开关、选中标记、链接和可执行项；危险操作继续使用 `danger`。

这不是新增第三个品牌主色，而是把蓝色定义为暗色材质的中性底色。品牌识别仍由琥珀完成，深蓝负责降低视觉噪声和提升表面层级。
| `textTertiary` | `#737983` | 弱提示和非重点信息 |

新 UI 必须使用 `PhotoDeleteTheme` 或 `PhotoDeleteStyle` token，禁止在页面 View 中写 `Color(red:green:blue:)`。普通卡片优先使用表面差异，不同时叠加强透明填充、强描边和阴影。

### 11.4 容器与圆角

当前 22pt 圆角、半透明灰面、1pt 描边和阴影反复叠加，造成“卡片墙”。目标值如下：

| 场景 | 目标值 |
| --- | ---: |
| 主概览卡 | 20pt |
| 普通卡片 / grouped surface | 16pt |
| 输入框和普通控件 | 12pt |
| Toast、badge、底部操作条 | Capsule |
| 图标 tile | 10pt 到 12pt |

页面最多保留一个突出主卡片。同一组内容使用一个外层 surface，内部用 Divider 分隔；不要在卡片里面再放多个同等重量的卡片。浮层只采用一种主要层次：`surfaceElevated`、系统 material 或阴影不要全部叠加。

建议页面水平边距为 `20pt`，iPad 可读区域为 `32pt`，section 间距为 `20pt` 到 `24pt`，grouped row 垂直 padding 为 `12pt`，普通 row 最小高度为 `52pt` 到 `56pt`，点击区域保持 `44pt × 44pt`。

### 11.5 页面规则

#### 首页

- “随机整理”和“往年今日”使用同一中性 surface，只保留小型图标 tile、左侧 accent bar 或轻量 tint。
- 周期数据改成一个 grouped surface，三行之间使用 Divider，不使用三个独立大卡片。
- “专项清理”使用一个 grouped surface，内容类型图标统一中性或低饱和琥珀。
- “工具”保持列表行结构，不再给每个工具单独做彩色卡片。
- 删除红、蓝、黄、紫硬编码分类色。
- 引导卡内部的“知道了”改为轻量文字按钮或底部分隔操作，避免卡中套卡。

首页视觉顺序应是：照片库概览和主要整理入口、周期数据、专项清理、工具。

#### 设置页

- 每个 section 使用一个明确 grouped surface，内部使用 Divider。
- section heading 降低为 `.headline` 或 `.subheadline.weight(.semibold)`，不要使用 `.title2.bold()`。
- row title 使用 regular/medium，不要全部使用 semibold。
- subtitle 只在帮助决策时显示，避免每一行都变成两行灰色文字。
- 保持 Toggle、Menu、NavigationLink 等原生控件行为。
- supporter banner 可以保留轻量琥珀 icon tile 或状态 badge，但不做高饱和营销卡。
- 产品固定为 Dark 主题；导航栏、sheet 和系统控件应保持 Dark 外观一致，避免局部出现浅色表面。

#### 相册页

- 封面网格只展示封面、标题和数量，不再叠加额外灰卡。
- 列表行优先使用系统 grouped row；thumbnail 可以有 surface，但整行不重复涂灰。
- 搜索框使用 `surfaceElevated`，聚焦时显示琥珀色焦点边界。
- 创建相册优先使用 toolbar plus；若保留浮动按钮，使用琥珀实心、44pt 触控区域和低阴影。
- 首次使用提示使用短时 toast、hint 或 sheet，不永久占据列表首屏。
- 删除空相册时，选择态使用琥珀色，最终确认按钮才使用 danger。

#### 滑动整理页

- `reviewCanvas` 使用中性冷黑或炭黑，但与全局 canvas 保持同一 token 体系。
- 顶部 chrome 和底部操作栏只使用一层 `surfaceElevated` 或 material。
- 底部操作栏保留一个主操作；撤销、分享、收藏和删除使用低对比度语义 icon button。
- 每个 action button 不再同时拥有彩色背景、描边和阴影。
- 视频、截图和 Live Photo overlay 使用 material 或主题语义色，不使用固定黑色 alpha。
- 待删除、已归类状态优先使用窄状态条、badge 或边缘色标，减少整张照片上的黑色遮罩。
- 静音按钮固定在稳定的 chrome 区域，避免播放状态改变时跳位。
- 胶片条只突出当前照片，未选中缩略图不额外叠加灰色背景。

### 11.6 排版和状态

优先使用 Dynamic Type 和语义字体，逐步减少页面内散落的 `.system(size:)`。推荐使用：页面标题 `.title2.weight(.semibold)`、section 标题 `.headline.weight(.semibold)`、正文 `.body`、辅助说明 `.subheadline`、标签 `.caption`、数字指标 `.title.weight(.semibold).monospacedDigit()`。

所有自定义 ButtonStyle 至少提供默认、按下、禁用、焦点和加载状态。不要只用颜色表达状态；删除、收藏、完成等状态同时使用 icon、文字、位置或 badge。动画保持短、低幅度，并尊重 Reduce Motion。

### 11.7 实施优先级

**P0**

1. 收敛 `PhotoDeleteTheme` 的 canvas、surface、elevated surface 和文字 token。
2. 删除首页专项清理的四组硬编码颜色。
3. 移除随机整理、往年今日的大面积彩色背景。
4. 让首页局部颜色全部来自主题语义 token。

**P1**

1. 将首页周期卡、专项清理和工具区改为 grouped surface + Divider。
2. 将普通卡片圆角从 22pt 收敛到 16pt，减少默认描边。
3. 简化设置页分组和 section heading。
4. 统一相册页的列表/网格 surface 和创建按钮。
5. 统一滑动页 chrome、底部操作栏和照片状态 overlay。

**P2**

1. 逐步替换固定 `.system(size:)` 为语义字体。
2. 补齐 pressed、focus、disabled 和 Reduce Motion 状态。
3. 为 Dark 外观和 Dynamic Type 做截图回归检查。

## 12. 产品图标生成 Prompt

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
