# PhotoDelete Design System

> 这是全局视觉与组件规范，不是页面需求或产品流程文档。页面布局、交互和数据规则应放在对应功能文档中。实现以 `ios-app/PhotoDelete/DesignSystem/Theme.swift` 和 `Components/` 为准；本文件说明共用标准与新增 UI 的约束。
>
> 最近核对：2026-10-11。

## Overview

PhotoDelete 使用**黑白中性的暗色设计系统**。近黑画布、黑灰表面和白灰文字构成界面主体；珊瑚与琥珀是少量、语义明确的点缀色，不构成大面积暖色主题。照片是主要内容，UI 应保持安静，让照片和信息层级自然突出。

全局默认：

- 页面背景使用近黑中性层级，卡片和浮层逐级提亮。
- 普通文字、图标和分隔线使用白色透明度阶梯。
- 琥珀表达主操作、选中状态和系统 tint。
- 珊瑚只用于登记的品牌入口。首页两张核心入口卡是大面积珊瑚/琥珀渐变的特例；删除数量与危险状态使用 `destructive`。
- 成功、警告、危险、收藏使用各自状态 token；不要用品牌强调色替代状态色。
- 页面局部规则不能自行增加颜色、字号或圆角 token。确需扩展时先修改 `Theme.swift` 和本规范。

## Color Palette

### Neutral foundation

| Token | Value | Usage |
| --- | --- | --- |
| `backgroundTop` | `#0A0A0D` | 普通页面背景渐变上端 |
| `background` | `#08080A` | 页面主背景 |
| `reviewCanvas` | `#000000` | 整理场景专用黑色画布 |
| `surface` | `#16161A` | 普通卡片、列表容器 |
| `elevatedSurface` | `#1E1E24` | 输入、浮层、toast、次级操作表面 |
| `reviewPhotoSurface` | `#12131B` | 整理页照片框留白与加载态的石墨深灰承托 |
| `primaryText` | White 96% | 标题和主要内容 |
| `secondaryText` | White 62% | 说明、次级值 |
| `tertiaryText` | White 42% | 弱图标、辅助信息 |
| `cardStroke` | White 9% | 卡片描边 |
| `hairline` | White 7.5% | 细分隔线 |

### Accent and status colors

| Token | Value | Semantic role |
| --- | --- | --- |
| `accent` | `#F3B14C` | 琥珀：主 CTA、选中状态、系统 tint |
| `accentPressed` | `#C98A32` | 琥珀按下态 |
| `secondaryAccent` | `#FFC77A` | 琥珀体系的辅助色，仅限已有语义 |
| `coralGradientTop` | `#FB857E` | 珊瑚品牌入口点缀；收藏快捷入口复用此色 |
| `coralGradientBottom` | `#F25C54` | 珊瑚入口卡渐变下端 |
| `coralInk` | `#2E0F06` | 珊瑚卡片上的深色文字 |
| `amberGradientTop` | `#FFC85E` | 琥珀入口卡渐变上端 |
| `amberGradientBottom` | `#F09A22` | 琥珀入口卡渐变下端 |
| `amberInk` | `#1A1206` | 琥珀卡片上的深色文字 |
| `positive` | `#B8DB85` | 成功、已完成 |
| `warning` | `#FFC773` | 警告 |
| `destructive` | `#FF7561` | 删除、危险状态 |
| `favorite` | `#FFA3B8` | 照片收藏状态 |

### Decorative colors

| Token | Value | Usage |
| --- | --- | --- |
| `boardPaper` | `#FAFAF7` | 相纸墙相纸白边 |
| `boardClipPalette` | `#EDD65C` `#9E87DB` `#78BD66` `#61A3E6` `#E06B94` `#CCA375` | 相纸墙小木夹；按相纸种子取色 |
| `albumFolderPalettes` | 蓝 / 珊瑚 / 绿 / 琥珀 / 桃 / 淡紫 | 整理页相册托盘的插画文件夹；按 `album.id` 稳定取色；仅装饰，不表达状态 |

装饰色只出现在相纸墙、相册托盘这类「照片内容区」里的实物道具上，不表达状态或操作，不能用于按钮、图标、文字。不要往琥珀、珊瑚靠。

RGB tokens in `Theme.swift` are the source of truth; hex values above are rounded documentation equivalents.

### Color rules

- **Black and white are the theme.** Accent colors remain subordinate in area and frequency.
- Use `accent` only when an action or selected state needs emphasis. Do not tint every icon or heading amber.
- Use coral for registered brand entry points and deletion-count indicators. The collection/favorite data state itself uses `favorite`; the album shortcut uses coral only as a small brand accent.
- Use status colors for their matching status. Favorite state uses `favorite`; deletion counts and destructive actions use `destructive`, not coral.
- The paired home entry cards are the only routine large-area accent surfaces. Each card uses its own gradient and ink color; do not introduce the other accent inside the card.
- Do not add one-off RGB/hex colors in views. Add or reuse a semantic `Theme` token.

## Typography

The native app uses the system San Francisco family with the system Chinese fallback. It does not bundle a global display font. `.rounded` is a limited variant for action chrome and prominent numeric controls. The HTML prototypes may load Archivo for Latin display text; that font is not part of the native app typography.

| Role | Size / weight | Typical use |
| --- | --- | --- |
| Display title | 34 / bold | Root screen title |
| Section title | 14 / bold | Group heading |
| Card title | 16.5 / bold | Main entry card |
| Primary card number | 31 / bold | Large count |
| Band count | 23 / bold | Period summary |
| Row title / value | 15 / semibold | Standard list row |
| Body | System body / regular or medium | Explanatory content |
| Secondary metadata | 11.5–12 / regular | Subtitle, timestamp, hint |
| Chrome symbol | 17 / bold rounded | Header icon button |
| Review tool symbol | 20 / bold rounded | Photo review toolbar |

Regular is for reading text, medium for compact labels, semibold for controls and row titles, and bold for hierarchy or headline numbers. Keep a screen to a small number of weights. Use `.monospacedDigit()` for changing counts and progress values. Photo counts use `PhotoDeleteCountFormat.plain(_:)` with no grouping separators; capacities use `CleanupStatsFormatter.space(_:)`.

## Spacing System

`Theme` follows a 4pt base rhythm. Use the named tokens before adding a custom value.

| Token | Points | Typical use |
| --- | ---: | --- |
| `space2` | 8 | Compact group spacing |
| `space3` | 12 | Small component gaps |
| `space4` | 16 | Standard inner padding |
| `space5` | 20 | Phone horizontal page inset |
| `space6` | 24 | Card padding / major group gap |
| `space8` | 32 | Wide-screen horizontal inset |
| `space12` | 48 | Large breathing room |
| `space16` | 64 | Empty-state and section spacing |
| `space24` | 96 | Scroll content bottom clearance |

Common fixed sizes are separate from spacing: `sizeTap=44`, `sizeIcon=32`, `sizeChrome=48`, and `sizeRow=56`. `PhotoDeleteAdaptiveLayout` expands horizontal insets and constrains content width on larger screens.

## Component Styles

### Surfaces and cards

- Root pages use `PhotoDeleteScreenBackground` (`backgroundTop` to `background`).
- Standard cards use `surface`, a subtle `cardStroke`, and `.continuous` corners.
- Keep one visual container around a related group. Separate items inside it with an inset `hairline`; avoid stacking equally prominent cards inside cards.
- Floating surfaces may use a slightly translucent `surface`, a hairline border, and a restrained shadow.

### List rows

`PhotoDeleteListRow` is the shared row pattern: optional 32pt icon tile, 15pt semibold title, optional 11.5pt secondary subtitle, optional 15pt secondary value, and a tertiary chevron. Typical padding is 18pt horizontal and 13pt vertical. Use `.plain` button styling and keep row content neutral unless an explicit state applies.

### Buttons

- Primary: amber fill, `onAccent` foreground, `radiusMd`; press feedback uses a small scale and opacity change.
- Secondary: neutral surface with restrained amber label/stroke when it represents an available action.
- Destructive: destructive-tinted surface and label. Do not disguise destructive actions as primary amber.
- Header icon button: 48pt circular hit target, 17pt bold rounded symbol, white by default.
- Header chrome uses iOS 26 regular glass where available and an `elevatedSurface` fallback on earlier versions.
- Custom header icon color is limited to a documented semantic state or the registered coral favorite shortcut.

### Review album tray

整理页下滑加入相册使用一张浮起的横向托盘，不是 sheet：

- 托盘离屏幕左右/下各 16pt，`radiusXl` 32，`surface` + hairline + floating shadow
- 顶部 28pt 呼吸带只放一行微提示「点按相册进入」；不加大标题
- 关闭按钮视觉 24pt、点击热区 44pt，半压托盘右上沿
- 相册卡为 82pt 插画文件夹：彩色背板 + 圆角页签、3 层露出的照片、前袋渐变 / 柔和反光；左下角是照片图标 + 张数，名称在卡下方
- 横向 rail 间距 12pt、左右内边距 18pt；两端用约 12pt 的 mask 渐隐
- 加号只在按压时出现，不做常驻角标、不做 hover；写入中整排禁用
- 点按相册立即加入当前照片，**不自动下一张**；托盘保持打开，可继续加入其他相册
- 不提供「新建相册」，不提供「所有相册」第二层 sheet / 搜索

### Navigation and sheets

The root `NavigationStack` contains the `TabView`; pushed pages cover the tab bar structurally. Reuse `MainTabRouter` and `photoDeletePushedToolbar` instead of nesting navigation stacks. Sheets use the existing neutral surface and system presentation behavior; accent color is reserved for actionable or selected states.

## Shadows & Elevation

Elevation is primarily communicated through neutral surface brightness, not shadow. `floatingShadow` is black at 30% opacity.

| Level | Treatment | Use |
| --- | --- | --- |
| Base | `background` gradient | Page canvas |
| Surface | `surface` + subtle `cardStroke` | Standard card |
| Elevated | `elevatedSurface` | Input, menu, sheet content |
| Floating | Surface + hairline + shadow, commonly radius 12 / y 6 | Floating panel |
| Modal focus | Elevated surface + shadow, commonly radius 18 / y 10 | Important overlay |

Reserve stronger shadows for objects that physically lift, such as drag previews. Avoid shadows on ordinary list rows and avoid adding shadows on top of system glass.

## Animations & Transitions

Motion explains state changes and direct manipulation. Keep it short, respect Reduce Motion, and avoid decorative motion tied to scrolling.

| Interaction | Existing range / pattern |
| --- | --- |
| Button press | 0.14s easeOut, scale to about 0.985 |
| Light state change | 0.16–0.24s easeOut |
| Reorder | About 0.22s easeOut |
| Count roll | About 0.9s easeOut |
| Entry card progress | About 0.95s easeOut after a short delay |
| Fan card reveal | About 0.62s easeOut, staggered once |

Use spring motion for a lifted or movable object; use easeOut for ordinary state changes. Do not add parallax, click ripples, or scroll-triggered section reveals.

## Border Radius

Use continuous rounded rectangles and the shared radius ladder:

| Token | Points | Use |
| --- | ---: | --- |
| `radiusSm` | 12 | Icon tile, compact thumbnail |
| `radiusMd` | 16 | Input, button, compact row card |
| `radiusLg` | 24 | Standard large card |
| `radiusXl` | 32 | 整理页浮动相册托盘（内容专用） |

Circles and capsules follow their semantic shapes. A small number of content-specific masks may use a different radius when the image format requires it; do not introduce a new general-purpose radius for a single view.

已登记的内容专用例外：整理页相册导轨的胶片缩略图为固定 2:3 竖幅卡片、当前生效格变正方形，用 4pt 圆角 / 3pt 间距（对齐 iOS 原生「照片」查看器底部胶片条），常量见 `ios-app/PhotoDelete/Views/Review/Components/ReviewPhotoStrip.swift` 的 `ReviewPhotoStripLayout`。

另一个已登记例外是整理页相册托盘的插画文件夹：外层 20pt、前袋 12pt、照片边 6pt，统一放在 `ReviewAlbumTrayLayout`，只服务这张 82pt 的插画，不外溢到普通卡片。

## Opacity & Transparency

Reuse opacity tokens instead of creating near-duplicate gray values.

| Value | Use |
| ---: | --- |
| White 96% | Primary text |
| White 62% | Secondary text |
| White 42% | Tertiary text |
| White 9% | Card outline |
| White 7.5% | Hairline |
| White 7% | Neutral icon tile fill |
| White 5% | Reorder slot fill |
| White 34% | Reorder slot stroke / selected outline |
| Ink 18% | Accent-card progress track |
| Black 30% | Base floating shadow |
| Black 6% | 整理页相册托盘外遮罩 |

Transparency is for hierarchy, glass chrome, overlays, and disabled states. Do not make important text translucent or build a stack of multiple translucent surfaces to simulate elevation.

## Common Tailwind CSS Usage in Project

The native app is **SwiftUI**, not a Tailwind CSS project. There is no Tailwind configuration, `className`, `@tailwind`, or utility-class build step. `designs/*.html` are standalone HTML/CSS prototypes using handwritten CSS.

`Theme.swift` borrows Tailwind-like token naming (`space*`, `size*`, `radius*`, `text*`) as a naming convention only. Native UI should use SwiftUI modifiers and `Theme` tokens; HTML prototypes should use their CSS custom properties. Do not add Tailwind-specific assumptions to native feature code.

## Example Component Reference Design Code

This reference uses existing project components and tokens. Product copy and action destinations are placeholders; feature-specific behavior belongs in the owning screen.

```swift
struct ExampleSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            PhotoDeleteSectionHeader(title: "Section title")

            VStack(spacing: 0) {
                PhotoDeleteListRow(
                    icon: "photo",
                    title: "Primary row",
                    subtitle: "Optional supporting text",
                    value: "12",
                    action: openPrimaryRow
                )

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: Theme.stroke)
                    .padding(.leading, 18)

                PhotoDeleteListRow(
                    icon: "video",
                    title: "Secondary row",
                    value: "4",
                    action: openSecondaryRow
                )
            }
            .photoDeleteCard(radius: Theme.radiusLg)
        }
    }

    private func openPrimaryRow() {}
    private func openSecondaryRow() {}
}
```

Shared implementation anchors:

- Tokens: `ios-app/PhotoDelete/DesignSystem/Theme.swift`
- Shared surfaces, rows, and button styles: `ios-app/PhotoDelete/Components/PhotoDeleteSharedUI.swift`
- Header chrome: `ios-app/PhotoDelete/Components/PhotoDeleteCircleIconButton.swift` and `PhotoDeleteGlassChrome.swift`
- Adaptive layout: `ios-app/PhotoDelete/Components/PhotoDeleteSharedUI.swift`

## Extension Rules

- Start with a neutral surface and neutral text/icon color. Add accent only when its semantic role is clear.
- Prefer an existing shared component over a page-local lookalike.
- Keep color, spacing, typography, radius, and motion decisions in their respective token/guide sections; keep feature flow details in feature docs.
- When implementation intentionally changes the system, update tokens and this guide in the same change.
- Visual prototypes demonstrate a direction or interaction; they do not override global tokens.
