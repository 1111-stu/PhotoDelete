# PhotoDelete Design System

> The single source of truth for visual language, tokens, components, motion, and UI writing.
> Implementation wins over this document when they differ; update both in the same change.
>
> Last verified: 2026-10-25 · Native app: SwiftUI · Prototypes: standalone HTML/CSS

---

## 1. Overview

PhotoDelete is a local-first photo cleanup app. The interface is built around one idea: **the photos and illustrations are the content; the UI is the frame.** The system is dark, tactile, and deliberately quiet, with a small number of warm accent surfaces.

### 1.1 Visual character

- **Near-black canvas, layered neutrals.** The home uses `backgroundTop → background`; the review canvas uses pure black so photos are the only focus.
- **Heavy, rounded geometry.** Large continuous corner radii, thick type, generous inner padding, and floating chrome. Avoid thin iOS-settings-style hairline-only screens.
- **Monochrome functional layer; brand color by exception.** White-opacity text and white action states on charcoal. Coral and amber are reserved for the two home entry cards; functional chrome, selection, CTAs, and switches are neutral.
- **Two content registers.**
  1. **Media cards** (time periods, entry cards): large illustrations, no icon container, more air, 80pt rows.
  2. **Utility lists** (special cleanup, settings): smaller icons, optical sizing, compact 62pt rows, hairlines between items.
- **Glass and pills for chrome.** Header circles, tool capsules, and the floating tab bar use glass or translucent elevated surfaces; content cards stay opaque.
- **Illustrative, not iconographic.** The user-provided 3D illustrations are part of the brand. System line icons are kept only where the product intentionally stays platform-native (see the header trash exception).

### 1.2 Design principles

1. **Black and white are the theme.** Functional emphasis is white/neutral; coral and amber are brand moments, not action colors.
2. **Weight before decoration.** Hierarchy comes from size, weight, spacing, and radius before color.
3. **One container per group.** Use hairlines inside a card; do not stack equally prominent cards inside cards.
4. **Photos and illustrations lead.** Keep labels, chrome, and dividers subordinate.
5. **Optical alignment beats mechanical alignment.** Align icon centers and title columns across sections; size each illustration by perceived ink mass, not by a single box.
6. **Static is static.** No ambient motion, parallax, floating loops, or scroll-triggered reveals. Motion explains a state change or direct manipulation.
7. **Native where it matters.** Use system sheets, switches, blur, and safe-area behavior; custom chrome only where it adds identity.

### 1.3 Reference set (2026-10-25)

The current reference screens (settings, canvas editor, mode picker) confirm the same family of decisions: near-black canvas, squircle cards, glass pill controls, 1px hairlines as structure, oversized monochrome geometry, and one dominant idea per screen. They are **pattern references, not token sources**. In particular:

- Their green switches are the platform default. PhotoDelete adopts a green switch-on state via `Theme.positive`; green is reserved for switches/success, not brand accents.
- Their display face is not bundled in the native app. PhotoDelete uses SF Pro + PingFang SC; the HTML prototypes may use Archivo for Latin display text only.
- Their pure-black canvas maps to PhotoDelete's review/editor canvas; the home uses near-black to preserve surface layering.

---

## 2. Color Palette

RGB values in `Theme.swift` are the source of truth; hex values below are rounded documentation equivalents.

### 2.1 Canvas

| Token | Value | Usage |
| --- | --- | --- |
| `backgroundTop` | `#0A0A0D` | Root page gradient top |
| `background` | `#08080A` | Root page base |
| `reviewCanvas` | `#000000` | Photo review / immersive editing canvas only |

Use `PhotoDeleteScreenBackground()` for root pages. Do not paint arbitrary black surfaces; use `surface` and `elevatedSurface` for layering.

### 2.2 Surface & structure

| Token | Value | Usage |
| --- | --- | --- |
| `surface` | `#16161A` | Standard card and grouped list container |
| `elevatedSurface` | `#1E1E24` | Inputs, menus, floating panels, toast |
| `reviewPhotoSurfaceTop` | `#1E2024` | Review photo frame fill, gradient start (top-leading) |
| `reviewPhotoSurfaceBottom` | `#0C0D11` | Review photo frame fill, gradient end (bottom-trailing) |
| `cardStroke` | White 9% | 1pt card outline |
| `hairline` | White 7.5% | Inset separators inside cards |
| `floatingShadow` | Black 30% | Floating chrome/panel shadow |
| `reviewPhotoStroke` | White 12% → 1% | Review photo frame outline; fades toward bottom-trailing |

### 2.3 Text

| Token | Value | Usage |
| --- | --- | --- |
| `primaryText` | White 96% | Titles, primary values, primary labels |
| `secondaryText` | White 62% | Subtitles, secondary values, secondary actions |
| `tertiaryText` | White 42% | Chevrons, hints, unit labels, least important metadata |

Text opacity is a hierarchy tool, not a way to make text “soft.” Do not set important copy below `secondaryText` (62%).

### 2.4 Action (monochrome)

The token name `accent` is retained for API compatibility, but it is now the **monochrome action color**, not amber. Amber lives only in the home entry gradient (`amberGradient*`).

| Token | Value | Usage |
| --- | --- | --- |
| `accent` | White 96% | Primary CTA fill, selected text/icon, active controls |
| `accentPressed` | White 82% | Pressed white action state |
| `onAccent` | `#08080A` | Ink on white fills |
| `accentSoftFill` | White 10% | Selected/soft action background |
| `accentSoftStroke` | White 22% | Selected/soft action outline |

Use white as the active/selected color. Do not reintroduce amber for CTAs, tabs, toggles, section totals, or selection outlines. The only amber surfaces are the “随机整理” entry card and its ink.

### 2.5 Status

| Token | Value | Usage |
| --- | --- | --- |
| `positive` | `#B8DB85` | Completed / positive confirmation |
| `warning` | `#FFC773` | Warning |
| `destructive` | `#FF7561` | Delete, destructive actions, pending-delete counts |
| `favorite` | `#FFA3B8` | Favorite state |

Status colors are never used as general decoration, and destructive actions are never disguised as the white primary action. `warning` remains a semantic yellow (large files); it is not a brand accent.

### 2.6 Home entry gradients (registered exception)

| Token | Value | Usage |
| --- | --- | --- |
| `coralGradientTop` | `#FB857E` | “待整理” card top |
| `coralGradientBottom` | `#F25C54` | “待整理” card bottom |
| `coralInk` | `#2E0F06` | Ink on coral |
| `amberGradientTop` | `#FFC85E` | “随机整理” card top |
| `amberGradientBottom` | `#F09A22` | “随机整理” card bottom |
| `amberInk` | `#1A1206` | Ink on amber |

These two paired cards are the only routine large-area accent surfaces. Each card owns its gradient and ink; do not cross-use coral inside amber or vice versa.

### 2.7 Decorative-only colors

| Token | Value / palette | Usage |
| --- | --- | --- |
| `boardPaper` | `#FAFAF7` | Photo-wall print border |
| `boardClipPalette` | lemon / lavender / grass / sky / rose / wood | Photo-wall clips; stable by print seed |
| `albumFolderPalettes` | blue / coral / green / amber / peach / lilac | Album tray folders; stable by album id |
| `dropSlotFill` / `dropSlotStroke` | White 5% / White 34% | Reorder drop slot |
| `trayScrim` | Black 6% | Album tray scrim |

Decorative colors only appear on physical-object metaphors inside content areas (prints, clips, folders, illustrations). They never encode state or actions and must not drift toward amber/coral semantics.

### 2.8 Illustration assets

The period and cleanup illustrations are **approved raster assets**, not color tokens. The current set is a black-and-white stone-sculpture family:

- Period: calendar + clock (week), grid calendar (month), sundial (year).
- Cleanup: ornate frame (screenshots), twin busts (similar/duplicates), film camera (video/screen recordings), stone camera (live photos).
- The dice is reserved for the random-review card; the broom is a spare/section-level asset until it has a row.
- They are decorative, not status indicators. Do not recolor, tint, or use them to encode success/error.
- Keep transparent PNGs; never bake a white background into the asset.
- The set carries a baked dark contact halo. It is part of the material look and must stay consistent across icons; do not add a second tile background behind it.
- The top-right collection/trash entry intentionally keeps the system line icon (`archivebox`) per product decision. Do not replace it with an illustration.

### 2.9 Color rules

1. Never add one-off RGB/hex values in a view; add or reuse a `Theme` token.
2. Keep the functional layer monochrome. The two home entry cards are the only large brand-color surfaces.
3. Use `destructive` for deletion and pending-delete counts; use `favorite` for favorites; use `positive` for completed states and switch-on.
4. Use white for primary actions and selected states. Amber is not an action color.
5. Do not use color alone to communicate state; pair it with weight, shape, label, or icon.
6. Green is reserved for switch-on and success. Do not use green as a general brand accent or for selected tabs.
7. Registered exception: the Supporter paywall (`PaywallDS`) keeps its own pink accent, gold rating star, and white CTA. It is a dedicated conversion surface and does not inherit the home action tokens.

---

## 3. Typography

### 3.1 Families & pairing

**Native app**

- Latin and numerals: **SF Pro** (system).
- Chinese: **PingFang SC** via system fallback.
- The app bundles **no custom display font**. This is deliberate: it keeps the UI native, compact, and legible across languages.
- `.rounded` is a limited SF variant for action chrome and prominent numeric controls (header symbols, metrics). It is not a second family and is not used for body copy.

**HTML prototypes**

- Latin display: **Archivo 500 / 600 / 700**, self-hosted in `designs/fonts` as woff2. Never use a CDN font; the prototypes must open from `file://`.
- Chinese: system PingFang SC. Do not rely on automatic CJK fallback after a Latin font if a specific Chinese face is required; name the Chinese face explicitly.
- Archivo is a prototype voice, not an app dependency. Do not assume it is bundled in the iOS target.

**Reference screens**

- The reference app uses a condensed/rounded display face for Chinese. It is not adopted in PhotoDelete. Use it as a composition reference only.

### 3.2 Weight ladder

Only four weights are used in native UI:

| Weight | Role |
| --- | --- |
| 400 regular | Reading copy, subtitles, metadata, hints |
| 500 medium | Compact labels, tab labels, small annotations |
| 600 semibold | Row titles, controls, action labels, sheet rows |
| 700 bold | Screen titles, card titles, numbers, hierarchy |

Avoid 300/800/900 in native UI. Do not synthesize bold. If a screen needs more hierarchy, change size/spacing before adding another weight.

### 3.3 Type scale

| Role | Size / weight | Tracking | Typical usage |
| --- | --- | --- | --- |
| Display title | 34 / 700 | -0.03em | Root screen title (“整理”) |
| Screen title (settings) | 17 / 600 | 0 | Centered small-screen headers |
| Section title | 14 / 700 | +0.01em | “专项清理”, “按类型整理” |
| Section trailing | 12.5 / 600 | 0 | Secondary total in section header |
| Entry card title | 16.5 / 700 | -0.015em | “待整理”, “随机整理” |
| Entry card number | 31 / 700 | -0.04em | Pending count |
| Entry card label | 11 / 400 | 0 | “预计可释放” |
| Entry card size | 18 / 700 | -0.02em | “7.8 GB” |
| Period card title | 16 / 700 | -0.015em | 本周 / 本月 / 本年; one line, min scale 0.9 |
| Period card meta | 11.5 / 400 | 0 | “共 33 项 · 55.8 MB” |
| Period card count | 26 / 700 | -0.035em | Remaining count |
| Period count label | 10.5 / 400 | 0 | “待整理” |
| Period action | 13.5 / 600 | 0 | Fixed visual label “更多 / More”; accessibility uses Choose date/month/year |
| Period action chevron | 9 / 700 | 0 | Right-zone chevron |
| List row title | 15 / 600 | 0 | Standard list / settings rows |
| Home cleanup title | 16 / 600 | -0.01em | Matches period-card title size; slightly lighter than 16 / 700 |
| List row subtitle | 11.5 / 400 | 0 | Supporting metadata |
| List row value | 15 / 600 | 0 | Secondary value (“5.8 MB”) |
| Sheet title | 17 / 700 | 0 | “按周整理 / 按月整理 / 按年整理” |
| Sheet row title | 17 / 600 | +0.005em | Period rows |
| Sheet row subtitle | 13 / 400 | 0 | “共 33 项 · 55.8 MB” |
| Sheet count | 20 / 700 | -0.02em | Remaining count |
| Sheet meta label | 11.5 / 400 | 0 | “待整理” |
| Tab label | 11 / 500 | 0 | Unselected; selected becomes 11 / 700 |
| Chrome symbol | 17 / 700 rounded | 0 | 48pt header circle |
| Primary button label | System body / 600 | 0 | White CTA, dark ink |

Rules:

- Use `.monospacedDigit()` for any changing count, timer, or progress number.
- Counts use `PhotoDeleteCountFormat.plain(_:)` and **never** grouping separators (`1131`, not `1,131`).
- Sizes use `CleanupStatsFormatter.space(_:)` with a single decimal where appropriate.
- Keep a screen to at most three weights. The home uses 400 / 600 / 700; 500 is reserved for tab labels and compact annotations.
- Multi-line reading copy uses system line height; aim for 1.4–1.6× size. Single-line metadata should not be forced into multi-line height.

### 3.4 Latin + Chinese + numerals

- Let the system pair SF and PingFang; do not manually switch fonts within a label.
- Numerals should stay tabular and aligned; use SF rounded only for metrics that benefit from a softer shape.
- In prototypes, Archivo should be applied to Latin display copy and numerals; Chinese falls back to PingFang. Check actual rendering: CJK does not always fall back as expected after a Latin family.
- Keep units and separators consistent: `7.8 GB`, `55.8 MB`, `共 33 项 · 55.8 MB`, `18 段`, `312 组`, `112 张`.
- Avoid `1,131`; use `1131`.

### 3.5 Truncation & localization

- Titles, values, and right-zone labels use `lineLimit(1)`.
- Allow localized right-zone labels to grow the column; do not assume Chinese 3-character widths.
- Do not hard-code date formats; use locale-aware formatters (`AppDateFormatter`, `TimeOrganizeFormatter`).
- When a localized string can be long, allow the main title/subtitle to shrink or truncate before breaking the grid.

---

## 4. Spacing System

### 4.1 Base rhythm

All spacing is on a **4pt grid**. Use tokens before custom numbers.

| Token | Value | Typical use |
| --- | ---: | --- |
| `space2` | 8 | Compact group spacing, header top padding |
| `space3` | 12 | Card gaps, inner title/icon gaps |
| `space4` | 16 | Standard inner padding, icon slot lead-in |
| `space5` | 20 | Phone page inset |
| `space6` | 24 | Card padding, major group gap |
| `space8` | 32 | Wide-screen page inset |
| `space12` | 48 | Large breathing room |
| `space16` | 64 | Empty states |
| `space24` | 96 | Scroll bottom clearance |

`sizeTap = 44`, `sizeIcon = 32`, `sizeChrome = 48`, `sizeRow = 56` are **sizes**, not spacing; do not reuse them as gaps.

### 4.2 Layout constants

- Home page inset: 20pt phone (`space5`), 32pt expanded (`space8`).
- Home content max width: 520pt phone, 1040pt expanded.
- Home top padding: 8pt.
- Scroll bottom clearance: 96pt.
- Home vertical section gap: 22pt (registered home composition value; not a global token).
- Entry pair: 158pt high, 12pt gap.
- Period cards: 12pt gap; 24pt radius; 80pt row height.
- Special cleanup card: one card, 24pt radius, four 62pt rows.
- Floating tab bar: 14pt sides, 22pt bottom, 76pt height.

### 4.3 The two home grids

These two grids are the reference for cross-section alignment. **Align the optical axes, not the container sizes.**

**Period card — leading 12, icon 56, gap 12, title 80**

```
card edge
  │ 12pt padding
  │ [ 56pt illustration ]  12pt gap  → title / meta
  │                                   count block
  │                                   1pt divider
  │                                   12pt + action label + chevron
```

- Illustration center: 12 + 28 = **40pt**.
- Title left edge: 12 + 56 + 12 = **80pt**.
- Count block is trailing-aligned before the divider.
- Action column uses 12pt horizontal padding.

**Cleanup row — leading 16, transparent 48 slot, gap 16, title 80**

```
card edge
  │ 16pt padding
  │ [ 48pt transparent slot, icon centered ]  16pt gap  → title / subtitle
  │                                                     value + chevron
```

- Icon center: 16 + 24 = **40pt** (matches period cards).
- Title left edge: 16 + 48 + 16 = **80pt** (matches period cards).
- Vertical padding: 7pt; row height: 48 + 14 = **62pt**.
- Hairline inset: 16pt, aligned to the slot edge.
- Do **not** fill the 48pt slot with a background block. The icons float, like the period illustrations. A filled tile was tested and made the list read as a second, heavier rhythm.

### 4.4 Standard list row

For rows outside the home cleanup exception:

- Horizontal padding: 18pt both sides.
- Vertical padding: 13pt.
- Icon tile: 32pt, radius 12, white 7% fill; SF Symbol 17 / regular, secondary.
- Gap: 14pt; title 15 / 600; subtitle 11.5 / 400 secondary; value 15 / 600 secondary; chevron 12 / 600 tertiary.
- Hairline inset: 18pt.

### 4.5 Section rhythm

- Section header horizontal padding: 6pt.
- Header-to-content gap: 9–12pt.
- Group/card gap: 12pt.
- Major section gap on home: 22pt.
- Do not add a section header to the time cards. The three period cards are self-explanatory and directly follow the entry pair; this is a product decision from 2026-10-25. The “专项清理” header remains.

---

## 5. Layout & Composition

### 5.1 Home composition

1. **Title bar** — 34 / 700 “整理” left, 48pt collection/trash circle right.
2. **Entry pair** — coral “待整理” + amber “随机整理”, 158pt high, 12pt gap.
3. **Period cards** — three independent cards (本周 / 本月 / 本年), 12pt gaps, no section header.
4. **Special cleanup** — section header + one grouped card with four rows in this order: **截图 → 相似与重复 → 录屏与视频 → 实况照片**.
5. **Floating tab bar** — 整理 / 相册 / 设置.

The page scrolls; no content is pinned except the tab bar and the header chrome appropriate to the screen.

### 5.2 Two registers

- **Media card register:** period cards and entry cards use large illustrations, 80pt content height, no tile behind the icon, and more air. The illustration is the focal content.
- **Utility register:** cleanup/settings lists use smaller illustrations, optical sizing, 62pt rows, hairlines, and transparent slots. The list is scannable, not decorative.

Do not “fix” the size difference between 56pt period illustrations and 33–42pt cleanup illustrations by forcing equal containers. The size difference is hierarchy, not misalignment. Fix alignment through shared centers (40pt) and shared title columns (80pt).

### 5.3 Alignment rules

1. Left-align primary content to the page inset; cards share the same outer edge.
2. Inside a group, align icon centers and title columns across related sections.
3. Use hairline separators to express structure; do not wrap every row in its own card.
4. Keep right-side values and chevrons on a shared trailing edge.
5. Avoid nested cards; if a card needs internal structure, use 1pt hairlines and spacing.
6. Leave the bottom 96pt clear for the floating tab bar.

### 5.4 Sheets & modal composition

- Period selection uses a system sheet at `.medium` detent, with a drag indicator.
- Content: title 17 / 700 at top 24 / bottom 4; rows with 52pt thumbnail, 17 / 600 title, 13 / 400 subtitle, 20 / 700 count, 11.5 / 400 “待整理”; hairlines between rows.
- The sheet lists **other** periods only. The current period is entered from the period card body; do not duplicate “本周全部 / 本月全部 / 今年全部” in the sheet.
- Empty sheet state: “No other periods” / “暂无其他周期”, centered, 14 / 400 secondary, 32pt vertical padding.
- Sheets use system corner/presentation behavior; prototype sheet radius (26) is a visual reference, not a native token.

### 5.5 Reference patterns for future screens

The provided reference screens add useful composition patterns:

- **Settings-style grouping:** large squircle cards (24–28 radius) on near-black, 16pt hairline insets, a single glass pill CTA, section labels in secondary text. Adopt the grouping and quiet chrome; keep PhotoDelete's monochrome action semantics and green switch-on.
- **Editor chrome:** 48pt glass circle back button, a glass capsule grouping related icons with 1pt separators, a large canvas card with a 1px stroke, a compact + button cluster, and a floating pill tab bar. Adopt the glass/pill language; keep the photo canvas pure black.
- **Choice/mode screens:** pure black, one centered question (≈28 / 600), oversized monochrome geometry, hairlines splitting options, minimal chrome. Adopt only when a single decision dominates the screen; do not add accent colors to a decision screen unless the choice is destructive or selected.

---

## 6. Component Styles

### 6.1 Screen background

- Use `PhotoDeleteScreenBackground()` on root pages (near-black gradient).
- Use `reviewCanvas` (pure black) only for photo review/immersive editing.
- Do not add decorative background gradients or glows outside the registered entry cards.

### 6.2 Cards

- Standard card: `surface`, 24pt continuous radius, 1pt `cardStroke`, no shadow.
- Inner padding: usually 16–22pt; rows use 13–18pt vertical/horizontal based on the component.
- Group related items in one card; separate with hairlines, not nested cards.
- Floating surfaces (tray, toast, tab bar) may use translucency + hairline + `floatingShadow`.
- Media cards can use a gradient or a photo; utility cards stay neutral.
- Review photo frame (`RealPhotoCard`): diagonal `reviewPhotoSurfaceTop → reviewPhotoSurfaceBottom` fill (steeper than 45°, horizontal change ≈0.54× vertical) with a 1pt white 12% → 1% gradient stroke; no shadow. It is a photo frame surface, not decorative chrome.
- Review photo frame sits inside a `space5` (20pt) side inset on both edges; the pager stride stays one full page wide, so adjacent cards keep a 40pt gap while swiping.
- The frame gradient carries a deterministic 145° hairline texture: soft 5pt light bands every 13pt at white 1.0–2.4%, blurred 2.4pt. It is texture, not a second gradient; keep it low-contrast and static.

### 6.3 Section header

- `PhotoDeleteSectionHeader(title:trailing:)`.
- Title: 14 / 700, primary.
- Trailing: 12.5 / 600, secondary text, single line.
- Horizontal padding: 6pt.
- Header-to-content: 9–12pt.
- The time section has no header (2026-10-25 decision); the cleanup section keeps “专项清理” plus the secondary reclaimable total.

### 6.4 Period card

**Anatomy**

```
[ illustration 56 ]  title / 共 X 项 · Y        count / 待整理   │  更多 ›
                     ───────────────────────── main hit area ──┼─ right hit area ─
```

**Geometry**

- Three independent cards; 12pt gap; `surface` + 24pt radius; no shadow; 1pt `cardStroke`.
- Content height 80pt: 56pt illustration + 12pt vertical padding top/bottom.
- Horizontal grid: 12pt leading + 56pt illustration + 12pt gap to title; title at 80pt; icon center at 40pt.
- Main hit area: illustration, title/meta, count; opens the current period directly.
- Divider: 1pt `hairline`, full height, between main and right zones.
- Right hit area: fixed visual label 更多 / More (13.5 / 600 secondary) + 9 / 700 tertiary chevron; 12pt horizontal padding; opens `PeriodPickerSheet`. The fixed label keeps all three right columns the same width and leaves room for English titles; accessibility labels stay specific (Choose date/month/year).

**Content**

- Title: 本周 / 本月 / 本年 (16 / 700, one line, min scale 0.9).
- Meta: `共 X 项 · Y` (11.5 / 400 secondary, one line, min scale 0.9).
- Count: remaining items (26 / 700, monospaced).
- Count label: 待整理 (10.5 / 400 tertiary).
- Right label: 更多 / More (13.5 / 600 secondary). Accessibility label is specific to the scope.
- Illustration: 56pt user-provided PNG, no tile; shadow black 22%, radius 3, y 2.

**Behavior**

- Main tap: `SwipeViewDestination.period(scope, summary.intervalStart)`.
- Right tap: set `periodPickerScope = scope`.
- The two areas are sibling buttons; never nest a button inside a button.
- Accessibility identifiers: `home-period-week`, `home-period-month`, `home-period-year`; right zones add `-more`.

### 6.5 Cleanup row

**Geometry**

- One grouped card, 24pt radius; four rows; row height 62pt.
- Leading 16pt; transparent 48pt slot; gap 16pt; title at 80pt; trailing 18pt.
- Vertical padding 7pt.
- Hairline inset 16pt; only between rows, not after the last row.

**Icon**

- User-provided PNG; transparent; no tile background.
- Optical size by visual weight, not one mechanical size:
  - 相似与重复 (twin busts): **42pt**
  - 截图 (ornate frame): **42pt**
  - 录屏与视频 (film camera): **38pt**
  - 实况照片 (stone camera): **38pt**
- Shadow: black 20%, radius 2, y 1.
- Icon center 40pt aligns with period-card illustrations; title x 80pt aligns with period-card titles.

**Text**

- Title 16 / 600 primary, one line, min scale 0.9. Same size as the period-card title (16 / 700); the lighter weight keeps the list a step below the cards while preserving one shared title size.
- Subtitle 11.5 / 400 secondary (optional slot; the native home currently uses title + value only, while the HTML prototype demonstrates supporting subtitles).
- Value 15 / 600 secondary (when known).
- Chevron 12 / 600 tertiary.
- Row order is product-owned: 截图 → 相似与重复 → 录屏与视频 → 实况照片.

**Behavior**

- Whole row is the hit target; opens the corresponding browser/cleanup.
- Values show only when data is available; do not invent a value or show `0.0 MB` for an unknown estimate.

### 6.6 Standard list row

- Used outside the home cleanup exception.
- 32pt icon tile, 12pt radius, white 7% fill; SF Symbol 17 / regular secondary.
- Title 15 / 600; subtitle 11.5 / 400 secondary; value 15 / 600 secondary; chevron 12 / 600 tertiary.
- 18pt horizontal, 13pt vertical; hairline inset 18pt.
- Optional illustrated variant (`iconImage`) uses a transparent 48pt slot and optical size; do not fill the slot.

### 6.7 Entry cards (home)

- Pair height 158pt; 12pt gap; 24pt radius.
- Coral “待整理”: 16.5 / 700 title; 31 / 700 count; 11 / 400 label; 18 / 700 size; 11 / 400 ink labels; 7pt progress bar with ink 18% track and ink fill.
- Amber “随机整理”: 16.5 / 700 title; 12 / 500 subtitle; fan of three 46×62 prints, 2pt white border, 9pt radius, staggered 0.62s reveal; fan sits 52pt above the bottom.
- Ink colors are `coralInk` / `amberInk`; do not use white text on these gradients.
- The pair is the only routine large-area accent surface.

### 6.8 Header chrome & badges

- `PhotoDeleteCircleIconButton`: 48pt visible circle, glass on iOS 26+, `elevatedSurface` fallback; symbol 17 / 700 rounded, primary by default.
- **Exception:** the top-right collection/trash entry keeps the system `archivebox` line icon. Do not replace it with an illustration.
- Badge: capsule 20pt min, destructive fill, white 11.5 / 700, 2.5pt background ring, offset (3, -3), 99+ cap.
- Filter toolbar: the icon stays white in both states; a non-default filter adds a 4pt white dot at the bottom of the circle. Use shape, not an amber icon tint, for active state.
- Do not tint header chrome amber unless it expresses a documented state.

### 6.9 Buttons

- **Primary:** white fill, `onAccent` dark ink, 16pt radius; 0.14s press scale to 0.985 and opacity change.
- **Secondary:** neutral surface with white/secondary label and a white 22% hairline stroke; no amber.
- **Destructive:** destructive-tinted surface and label; never disguise as the white primary action.
- **Glass circle:** 48pt; glass chrome or elevated fallback.
- **Glass capsule / pill group:** capsule 999; horizontal icon groups may use 1pt internal separators; keep hit targets ≥44pt.
- **Plain rows:** use `.plain` but keep a clear content shape; if adding press feedback, use a 4% white pressed background, not a scale, so list rhythm stays stable.

### 6.10 Toggles & selectors

- Use the system `Toggle`; tint it with `Theme.positive` (soft green) in settings.
- Green is reserved for switch-on and success; do not use it for tabs, CTAs, or decorative accents.
- Selected rows use a white checkmark or a white 10% soft fill; selection must not rely on color alone.
- Segmented/pill selectors use capsules and a quiet surface; selected state is a lighter elevated surface or white label/icon.

### 6.11 Sheets

- Use system sheets with the neutral surface; do not add a custom corner radius to the native sheet.
- `.presentationDetents([.medium])`, drag indicator visible.
- Title 17 / 700; rows: 52pt thumbnail, 17 / 600 title, 13 / 400 subtitle, 20 / 700 count, 11.5 / 400 meta, chevrons; hairlines between rows.
- Empty state: “No other periods” / “暂无其他周期”, centered, 14 / 400 secondary.

### 6.12 Floating tab bar

- 14pt sides, 22pt bottom, 76pt height, capsule 999.
- Background rgba(28,28,34,0.92) + 28pt blur + 1px white 6% inset + floating shadow.
- Three tabs; icon 23pt; label 11 / 500; selected: 46pt elevated/white-plate circle, 24pt white icon, white 11 / 700 label.
- The bar floats above the content; bottom scrim uses a 118pt gradient to `background`.

### 6.13 Empty, loading, and scanning states

- Use the same card surface and 24pt radius.
- Scanning: glyph + 22 / 600 “Reading Photos” + 15 / 400 secondary explanation; progress uses the white action color.
- Empty: `ContentUnavailableView` on iOS 17+, with a secondary-style action button.
- Do not use colorful illustrations as empty-state decoration unless the content itself is illustrative; keep error/empty states neutral.

### 6.14 Settings-style groups

- Page inset 20pt; card radius 24; surface; internal hairline 16pt.
- Section labels: 14 / 700 or 13 / 500 secondary for quiet groups.
- Rows: 56pt min height; title 17 / 600; subtitle 13 / 400 secondary; chevron tertiary.
- Toggles: soft green tint (`Theme.positive`); row labels remain primary.
- A Pro/feature card may use a glass pill CTA and a larger 24–28pt radius; keep it to one prominent card per screen.
- Do not use the reference's green switches or its display font.

---

## 7. Shadows & Elevation

Elevation is primarily surface brightness, not shadow.

| Level | Treatment | Use |
| --- | --- | --- |
| Base | `background` gradient | Page canvas |
| Surface | `surface`, 1pt `cardStroke` | Standard card / grouped list |
| Elevated | `elevatedSurface` | Inputs, menus, sheet content |
| Floating | Surface + hairline + shadow (y 6, radius 12) | Floating tray, toast, tab bar |
| Modal focus | Elevated surface + stronger shadow (y 10, radius 18) | Important overlays |

Rules:

- Ordinary cards and rows have **no shadow**.
- Floating chrome may use `floatingShadow` (black 30%).
- Do not add shadows on top of system glass.
- Illustrations may use a small local shadow to sit on the card:
  - Period illustration: black 22%, radius 3, y 2.
  - Cleanup illustration: black 20%, radius 2, y 1.
- Strong shadows are reserved for drag previews and physically lifted objects.

---

## 8. Animations & Transitions

### 8.1 Principles

- **Static is static.** No ambient floating, parallax, ripple, or scroll-triggered reveals.
- Motion explains a state change, a gesture result, or a direct manipulation.
- Keep durations short; respect Reduce Motion.
- Prefer opacity/transform/background; avoid animating layout where a crossfade is clearer.

### 8.2 Motion table

| Interaction | Pattern |
| --- | --- |
| Button press | 0.14s easeOut, scale 0.985, light opacity change |
| Light state change | 0.16–0.24s easeOut |
| Reorder | ≈0.22s easeOut |
| Count roll | ≈0.9s easeOut from 0; period cards stagger 0.22 / 0.30 / 0.38 |
| Entry progress | ≈0.95s easeOut after a short delay |
| Fan reveal | ≈0.62s easeOut, staggered once (0 / 90 / 180ms) |
| Sheet presentation | System spring; prototype reference ≈0.34s cubic-bezier(.22,.9,.28,1) |
| Toast | 0.22s opacity + 0.30s transform |

### 8.3 Reduce Motion

- Set final numeric values immediately; do not roll counts.
- Skip fan/print reveals; show the final composition.
- Keep state changes as instant opacity/background changes.
- Never make Reduce Motion a broken state; the layout must be complete without animation.

### 8.4 Haptics

- Use haptics to reinforce destructive or committed actions where already implemented.
- Haptics are never the only feedback; pair them with a visual state change.

---

## 9. Border Radius

Use continuous rounded rectangles and the shared ladder.

| Token | Points | Use |
| --- | ---: | --- |
| `radiusSm` | 12 | 32pt icon tile, compact thumbnail |
| `radiusMd` | 16 | Button, input, 48pt slot/tile, compact row card |
| `radiusLg` | 24 | Standard large card, home entry cards, period cards, grouped list |
| `radiusXl` | 32 | Review album tray (content-specific) |

- Circles/capsules use 999.
- Do not introduce a new general-purpose radius for a single view.
- Registered exceptions:
  - Review photo strip: 4pt thumbnails, 3pt gap, 2:3 portrait (current cell square).
  - Album tray folder illustration: outer 20, front pocket 12, photo edge 6; defined in `ReviewAlbumTrayLayout`.
- Prototypes may use 20/22/26 for visual exploration; those are not native tokens. Converge native components to 12/16/24/32.

---

## 10. Opacity & Transparency

| Value | Use |
| ---: | --- |
| White 96% | Primary text |
| White 62% | Secondary text / secondary values |
| White 42% | Tertiary text / chevrons / hints |
| White 34% | Reorder slot stroke / selected outline |
| White 12% | Review photo frame stroke |
| White 9% | Card outline |
| White 7.5% | Hairline |
| White 7% | Neutral icon tile fill (standard SF rows) |
| White 5% | Reorder slot fill |
| White 10% | Soft action fill (selected) |
| White 22% | Soft action stroke (selected) |
| Ink 18% | Accent-card progress track (brand cards only) |
| Black 30% | Floating shadow |
| Black 6% | Album tray scrim |

Rules:

- Important text is never below 62% opacity.
- Do not stack multiple translucent surfaces to fake elevation; use surface brightness.
- Glass is for chrome, not for content cards.
- Illustration PNGs must be genuinely transparent; no white matte.
- The 48pt cleanup slot is **transparent**. If a tile background is ever reintroduced, cap it at 5–7% white and re-check row density.

---

## 11. Common Tailwind CSS Usage in Project

**There is no Tailwind in this project.** The native app is SwiftUI and uses `Theme` + SwiftUI modifiers. There is no `tailwind.config`, no `className`, no utility-class build step.

The token names are Tailwind-inspired for familiarity:

| Theme token | Prototype CSS variable | Tailwind-like equivalent (if ported) |
| --- | --- | --- |
| `background` | `--bg` | `bg-background` |
| `surface` | `--card` | `bg-surface` |
| `elevatedSurface` | `--card2` | `bg-elevated` |
| `primaryText` | `--ink` | `text-primary` |
| `secondaryText` | `--ink2` | `text-secondary` |
| `tertiaryText` | `--ink3` | `text-tertiary` |
| `accent` | `--action` | `text-action` / `bg-action` |
| `accentPressed` | `--action-pressed` | `bg-action-pressed` |
| `onAccent` | `--on-action` | `text-on-action` |
| `accentSoftFill` | `--action-soft` | `bg-action-soft` |
| `accentSoftStroke` | `--action-stroke` | `border-action-stroke` |
| `coralGradientTop/Bottom` | `--coral-a` / `--coral-b` | `from-coral to-coral` |
| `amberGradientTop/Bottom` | `--amber-lt` / `--amber-dk` | `from-amber to-amber` |
| `cardStroke` | `--stroke` | `border-stroke` |
| `hairline` | `--sep` | `border-hairline` |
| `radiusLg` | `--r-lg` / `--r-card` | `rounded-3xl` |
| `space5` | `20px` | `p-5` / `gap-5` |

HTML prototypes are standalone files with handwritten CSS, not Tailwind. Example token block used by `designs/home-period-cards.html`:

```css
:root {
  --bg: #0A0A0D;
  --card: #16161A;
  --card2: #1E1E24;
  --ink: #FFFFFF;
  --ink2: rgba(255,255,255,.62);
  --ink3: rgba(255,255,255,.42);
  --action: rgba(255,255,255,.96);
  --action-pressed: #D1D1D3;
  --on-action: #08080A;
  --action-soft: rgba(255,255,255,.10);
  --action-stroke: rgba(255,255,255,.22);
  --amber: #F3B14C;      /* brand card only */
  --amber-lt: #FFC85E;   /* brand card only */
  --amber-dk: #F09A22;   /* brand card only */
  --coral-a: #FB857E;
  --coral-b: #F25C54;
  --sep: rgba(255,255,255,.075);
  --stroke: rgba(255,255,255,.09);
  --r-card: 24px;
}
```

Prototype font rules:

- Self-host Archivo woff2 files in `designs/fonts`; never use a CDN.
- Chinese falls back to PingFang SC. If a specific Chinese face is required, name it explicitly; do not rely on automatic CJK fallback.
- Do not add `className` or Tailwind build assumptions to native code.

If this design system is ever ported to a Tailwind-based web surface, map the semantic tokens above rather than raw grays, and keep the same radii/spacing scale. That is a future port, not the current project state.

---

## 12. Example Component Reference Code

### 12.1 SwiftUI — period card geometry

```swift
private func periodCard(
    scope: AdvancedTimeScope,
    title: String,
    moreTitle: String,
    illustrationName: String,
    identifier: String,
    rollDelay: Double
) -> some View {
    let summary = currentPeriodSummary(for: scope)

    return HStack(spacing: 0) {
        // Main hit area: enter the current period directly.
        Button {
            router.push(SwipeViewDestination.period(scope, summary.intervalStart))
        } label: {
            HStack(spacing: 12) {
                Image(illustrationName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(Theme.primaryText)

                    Text(String(
                        format: L10n.string("%@ items · %@"),
                        PhotoDeleteCountFormat.plain(summary.assetCount),
                        summary.formattedEstimatedSize
                    ))
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    RollingNumberText(target: summary.remainingCount, delay: rollDelay)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("To review"))
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)

        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1)

        // Independent right hit area: choose another period.
        Button {
            periodPickerScope = scope
        } label: {
            HStack(spacing: 4) {
                Text(moreTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifier)-more")
    }
    .photoDeleteCard(radius: Theme.radiusLg)
}
```

Key values: leading 12 + illustration 56 + gap 12 = title at 80; icon center 40; main and right are sibling buttons, never nested.

### 12.2 SwiftUI — illustrated list row

```swift
PhotoDeleteListRow(
    iconImage: "CleanupSimilarIcon",
    iconImageSize: 42,
    title: L10n.string("Similar"),
    value: cleanupQueue(for: .similarPhotos)?.formattedSpace,
    accessibilityIdentifier: "home-cleanup-similar"
) {
    router.push(SwipeViewDestination.cleanup(.similarPhotos))
}
```

`PhotoDeleteListRow` rules for illustrated icons:

- Transparent 48pt slot; no tile background.
- Leading 16, gap 16, title at 80; vertical 7; row height 62.
- Optical sizes: similar 42, screenshots 42, video 38, live 38.
- Shadow black 20%, radius 2, y 1.
- Hairline inset 16.

### 12.3 HTML — period card reference

```html
<div class="pcard">
  <button class="pmain">
    <span class="pcover">
      <img src="illustrations/week.png" alt="">
    </span>
    <span class="pbody">
      <b>本周</b>
      <small>共 33 项 · 55.8 MB</small>
    </span>
    <span class="pcount">
      <b class="num">32</b>
      <small>待整理</small>
    </span>
  </button>
  <button class="pmore" aria-label="Choose date">
    <span>更多</span>
    <svg class="chev"><use href="#i-chev"/></svg>
  </button>
</div>
```

```css
.pcard {
  display: flex;
  align-items: stretch;
  overflow: hidden;
  border: 1px solid var(--stroke);
  border-radius: 24px;
  background: var(--card);
}
.pmain {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
  padding: 12px;
  text-align: left;
}
.pcover img { width: 56px; height: 56px; object-fit: contain; }
.pmore {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 0 12px;
  border-left: 1px solid var(--sep);
  color: var(--ink2);
  font-size: 13.5px;
  font-weight: 600;
}
```

The HTML prototype uses Archivo for Latin display and PingFang for Chinese; the native app uses SF/PingFang. Do not copy prototype font assumptions into the app.

---

## 13. Accessibility

- Tap targets: minimum 44pt. Period card right zone, rows, and header circles must all meet this.
- Split hit areas must have distinct accessibility labels/identifiers; the visible right label is 更多 / More, while its accessibility label stays specific (Choose date/month/year).
- Decorative illustrations are `accessibilityHidden(true)`. The row title/value carry meaning.
- Dynamic counts must be read as a single phrase; avoid reading visually separated “0” and “待整理” as unrelated elements when a combined label is clearer.
- Do not rely on color alone for state. Selected/error/destructive states also use text, icon, shape, or position.
- Support Reduce Motion: final values, no rolls/fans.
- Maintain contrast: primary/secondary text on surfaces; no text over photos without a scrim; white on dark is the action/selected color, not body copy.
- Test larger text settings; fixed font sizes may clip. If Dynamic Type is expanded, allow titles/subtitles to wrap or scale, but preserve the 40/80 optical axes where possible.
- VoiceOver order should follow: title, meta, count, action; the right-zone control is separate.
- Sheets must be dismissible by drag and by the close button; the background must not trap focus.

---

## 14. Localization & Content

- Chinese is the primary shipping language; English source strings live in `Localizable.xcstrings`.
- Counts use `PhotoDeleteCountFormat.plain`: no grouping separators.
- Sizes use `CleanupStatsFormatter.space`: consistent unit spacing (`7.8 GB`, `55.8 MB`).
- Period meta format: `共 X 项 · Y` (`%@ items · %@` key).
- Period actions use one fixed visual label: 更多 / More. Keep `Choose date/month/year` as the accessibility labels, not the visible copy.
- English cleanup row label is `Videos & Recordings` (not `Videos & Screen Recordings`) so it stays on one line at 16pt; Chinese remains 录屏与视频.
- Count labels: 待整理 (`To review`); deletion counts are separate (`destructive`).
- Dates: locale-aware; short years in compact rows; full range in sheets/preview.
- Do not hard-code “周/月/年” into formatters; use the scope titles and locale formatters.
- Avoid concatenating translated fragments; use complete format strings with positional arguments where needed.
- RTL: mirror chevrons and directional layout where the platform does; keep icon illustrations unmirrored (objects are not directional).
- Avoid abbreviations that only work in Chinese; test German/Arabic label growth in the right zone.

---

## 15. Do / Don't

| Do | Don't |
| --- | --- |
| Use near-black canvas and layered surfaces | Paint arbitrary black rectangles |
| Keep coral/amber only in the two entry cards | Use amber for CTAs, tabs, toggles, or section totals |
| Use white for active/selected states | Use green as a general brand accent |
| Let photos/illustrations lead | Decorate with gradients or glows outside entry cards |
| Align icon centers and title columns | Force different icon sizes into identical tiles |
| Use per-icon optical sizes (42/40/33/33) | Give every illustration the same mechanical 36pt box |
| Use transparent 48pt slots for utility icons | Add filled tiles that create a second rhythm |
| Keep row height 62 in the cleanup list | Inflate list rows to match media cards |
| Use hairlines inside a group | Nest cards inside cards |
| Use tabular numerals and no separators | Show `1,131` or proportional digits in counters |
| Keep motion for state changes | Add ambient/parallax/scroll-driven motion |
| Respect Reduce Motion | Leave final values blank when motion is reduced |
| Keep the header trash icon platform-native | Replace it with an illustration (product exception) |

---

## 16. Implementation Anchors

- **Tokens:** `ios-app/PhotoDelete/DesignSystem/Theme.swift`
- **Shared surfaces, rows, buttons, adaptive layout:** `ios-app/PhotoDelete/Components/PhotoDeleteSharedUI.swift`
- **Header circle chrome:** `ios-app/PhotoDelete/Components/PhotoDeleteCircleIconButton.swift`, `PhotoDeleteGlassChrome.swift`
- **Home composition:** `ios-app/PhotoDelete/Views/Home/HomeView.swift`
- **Period sheet:** `ios-app/PhotoDelete/Views/Home/PeriodPickerSheet.swift`
- **Period logic/formatting:** `ios-app/PhotoDelete/Services/TimePeriodBrowser.swift`
- **Localization:** `ios-app/PhotoDelete/Localizable.xcstrings`
- **Home visual prototype:** `designs/home-period-cards.html`
- **Illustration assets:** `ios-app/PhotoDelete/Assets.xcassets/Period*Icon.imageset`, `Cleanup*Icon.imageset`; source PNGs in `designs/illustrations/`
- **Review strip exception:** `ios-app/PhotoDelete/Views/Review/Components/ReviewPhotoStrip.swift` (`ReviewPhotoStripLayout`)
- **Album tray exception:** `ReviewAlbumTrayLayout` and `designs/review-album-tray-prototype.html`

When implementation and this guide differ, treat the implementation as current behavior, then update the guide in the same change that changes the system.

---

## 17. Recent Decisions (2026-10-25)

Use these to prevent regressions:

1. **Videos + screen recordings merged** into one home entry (`录屏与视频`); screen recordings are a subset of videos, so size values use the larger queue value to avoid double counting.
2. **Period section is three independent cards**, 本周 / 本月 / 本年; no “按时间段开始” header.
3. **Period card split interaction:** card body enters the current period; right zone (visible 更多 / More, accessibility Choose date/month/year) opens the period sheet.
4. **Period sheet lists other periods only**; the first “本期全部” row was removed. Empty state is “暂无其他周期”.
5. **Special cleanup order:** 截图 → 相似与重复 → 录屏与视频 → 实况照片.
6. **Cleanup icons are optically sized** (42 / 42 / 38 / 38) inside a transparent 48pt slot; no tile background.
7. **Shared optical axes:** icon center 40, title column 80; period cards and cleanup rows use the same grid.
8. **Hairline inset 16** in the cleanup card; 62pt row height.
9. **User-provided stone-sculpture icons** replaced the earlier colorful calendars/cleanup set; do not reintroduce the CocoMaterial SVGs or the bright 3D clay icons.
10. **Header collection/trash icon stays the system `archivebox` line icon**; this is a deliberate exception to the illustration language.
11. **Functional amber removed (2026-10-25):** the action layer is monochrome white; amber/coral remain only in the two home entry cards. Switches use `Theme.positive` green; section trailing and tab selection are neutral. Do not reintroduce amber CTAs, tabs, toggles, or section totals.
12. **Stone icon set (2026-10-25):** period icons are calendar+clock / grid calendar / sundial; cleanup icons are frame / twin busts / film camera / stone camera. Optical sizes are 42 / 42 / 38 / 38. The dice is reserved for the random card; the broom is a spare asset.
13. **Title density + fixed More (2026-10-25):** period titles and home cleanup titles share 16pt; the period right zone uses a fixed 更多 / More label so all three card columns align and English titles stay on one line. Row titles use one line with 0.9 minimum scale.

---

## 18. Reference Analysis (2026-10-25)

The three reference screens are useful for composition, not for tokens:

- **Settings screen:** near-black canvas; large 24–28pt squircle cards; 1px hairlines; a white/glass pill CTA; green switches (platform default). Adopt the quiet grouping and pill CTA; use green only for switch-on and keep PhotoDelete's row/typography scale.
- **Canvas editor:** large rounded canvas card with a 1px stroke; glass circular back button; glass capsule icon group with 1pt separators; compact + button cluster; pill “背景” control; floating tab bar with a soft selected pill. Adopt the glass/pill chrome and the hierarchy of one big canvas + small tool clusters.
- **Mode picker:** pure black; a single centered question; oversized monochrome triangles; hairlines splitting options; minimal labels. Adopt this composition only for single-decision screens; keep it monochrome and avoid adding accent color unless the choice is destructive or selected.

What not to copy:

- Green outside switches/success (it is a state color, not a brand accent).
- The reference's display font (not bundled; native uses SF/PingFang).
- The reference's pure black on the home (home keeps near-black for surface layering; pure black is for the review canvas).

---

## 19. Quick Token Reference

| Category | Values |
| --- | --- |
| Canvas | `#0A0A0D` / `#08080A`, review `#000000` |
| Surfaces | `#16161A`, `#1E1E24`, review `#12131B` |
| Text | White 96% / 62% / 42% |
| Structure | Stroke 9%, hairline 7.5% |
| Action | White 96%; pressed 82%; ink `#08080A`; soft 10% / 22% |
| Brand gradients | coral `#FB857E → #F25C54`; amber `#FFC85E → #F09A22` |
| Status | positive `#B8DB85`, warning `#FFC773`, destructive `#FF7561`, favorite `#FFA3B8` |
| Spacing | 8 / 12 / 16 / 20 / 24 / 32 / 48 / 64 / 96 |
| Sizes | tap 44, icon 32, chrome 48, row 56 |
| Radii | 12 / 16 / 24 / 32; capsules 999 |
| Motion | press 0.14s; state 0.16–0.24s; count 0.9s; fan 0.62s; sheet ≈0.34s |
| Home axes | icon center 40; title column 80; period card 80 high; cleanup row 62 high |
| Optical sizes | similar 42; screenshots 42; video 38; live 38 |
