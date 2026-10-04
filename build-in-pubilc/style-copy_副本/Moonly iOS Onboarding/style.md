# UI 风格指南

从 `Moonly iOS Onboarding` 的 13 张静态截图提取的深色界面风格。截图内容区为 **1180 × 2556 px**，对应 iPhone 逻辑尺寸约 **393 × 852 pt**（@3x，逻辑点 = px ÷ 3）。底部 `#2F2F2F` 的来源水印条不属于界面，不计入样式。

没有设计稿源文件或 CSS。下表里的十六进制和尺寸来自像素测量；和 Tailwind 默认阶梯不完全重合的值标为 **推断**。未出现的状态写「未在当前材料中发现明确证据」。

视觉气质：近黑画布、白字、一块纯白胶囊主按钮、抬起的深灰表面、琥珀到珊瑚的点缀。层级靠明度差，不靠重阴影。圆角要么是全胶囊，要么是大约 16pt 的大圆角。

## 1. 概览

| 项 | 规则 |
| --- | --- |
| 画布 | `#17181F`，全屏铺满 |
| 表面 | `#22242A` 选项卡 / 次按钮；选中轮盘 `#2C2D33` |
| 主文字 | `#FFFFFF` |
| 次文字 | `#C8C9CD` 一带 |
| 主按钮 | 白底 `#FFFFFF`、黑字 `#000000`、高度约 28pt、`rounded-full` |
| 强调色 | 琥珀 `#F3B14C`，进度条偏珊瑚 `#CE724D` |
| 功能色 | 徽章紫 `#6848F8`，成功绿 `#40D060` |
| 页面边距 | 左右约 25pt |
| 字体 | 无衬线，几何、标题偏粗。推断为 SF Pro Display / SF Pro Text，`font-sans` |
| 阴影 | 控件本身几乎无投影；发光只出现在选中圆点和进度条 |

可复用的是颜色、字号阶梯、边距、胶囊按钮、表面卡片、轮盘选中条、毛玻璃底栏。产品文案、占星信息架构、插画内容不作为样式的一部分。

## 2. 色彩体系

### Tailwind 颜色变量

```css
@theme {
  --color-canvas: #17181F;
  --color-canvas-deep: #101118;
  --color-canvas-soft: #1C1D23;
  --color-surface: #22242A;
  --color-surface-2: #24252B;
  --color-surface-selected: #2C2D33;
  --color-control: #3B3A41;
  --color-ink: #FFFFFF;
  --color-ink-muted: #C8C9CD;
  --color-ink-faint: #8E9098;
  --color-inverse: #000000;
  --color-accent: #F3B14C;
  --color-accent-hot: #CE724D;
  --color-accent-deep: #E38D4E;
  --color-violet: #6848F8;
  --color-success: #40D060;
  --color-glass: rgb(255 255 255 / 0.22);
  --color-glass-selected: rgb(255 255 255 / 0.16);
  --color-track: #2A2C33;
}
```

### 语义对照

| Token | 值 | Tailwind | 用途 | 证据 |
| --- | --- | --- | --- | --- |
| canvas | `#17181F` | `bg-canvas` | 默认页面背景 | 多屏左上角与中部取样一致 |
| canvas-deep | `#101118` | `bg-canvas-deep` | 更深的一屏背景 | 第 16 屏状态栏区域 |
| canvas-soft | `#1C1D23` | `bg-canvas-soft` | 滚轮屏下半段、双按钮之间的空隙 | 第 6、11 屏 |
| surface | `#22242A` | `bg-surface` | 选项行、日期格、次级按钮 | 第 2 屏卡片中心 |
| surface-2 | `#24252B` | `bg-surface-2` | Skip 按钮、卡片边缘略亮一档 | 第 11 屏 Skip 中心 |
| surface-selected | `#2C2D33` | `bg-surface-selected` | 滚轮当前行胶囊 | 第 6 屏 `y=1464` |
| control | `#3B3A41` | `bg-control` | 未选中单选圆 | 第 3 屏 |
| ink | `#FFFFFF` | `text-ink` | 标题、选项、主百分比 | 标题行纯白 |
| ink-muted | `#C8C9CD` | `text-ink-muted` | 副标题、说明、未激活行 | 第 1 屏副标题高频色 `#CACCD0` / `#C9CBCF`，取中值 |
| ink-faint | `#8E9098` | `text-ink-faint` | 滚轮远离中心的行、0% 标签 | 推断，随距离继续变淡 |
| inverse | `#000000` | `text-inverse` | 白按钮上的标签 | 第 1 屏按钮内像素为 `#000000` |
| accent | `#F3B14C` | `text-accent` `bg-accent` | 选中单选、百分比、选中图标 | 第 3 屏圆心 `#F3B14C` / `#F5B24C` |
| accent-hot | `#CE724D` | `bg-accent-hot` | 进度条中段 | 第 13 屏进度条 |
| accent-deep | `#E38D4E` | — | 月亮图形左缘 | 第 0 屏，从 `#DF8950` 过渡到 `#EEA34F` |
| violet | `#6848F8` | `bg-violet` | `BIRTH CHART` 小徽章 | 量化桶中心落在 `#6040F0`（R 96–111，G 64–79，B 240–255），代表值推断 |
| success | `#40D060` | `text-success` | 承诺旁的盾牌勾 | 量化桶 `#40D060` |
| glass | `rgb(255 255 255 / 0.22)` | `bg-glass` | 底栏胶囊 | 叠在照片上，取样被内容染色，透明度推断 |
| track | `#2A2C33` | `bg-track` | 进度条未填充段 | 第 13 屏条右侧接近表面色 |

### 渐变

| 名称 | 值 | Tailwind | 用途 |
| --- | --- | --- | --- |
| accent-orb | `linear-gradient(180deg, #F6C56A 0%, #F3B14C 45%, #E38D4E 100%)` | `bg-gradient-to-b from-[#F6C56A] via-accent to-accent-deep` | 选中单选圆。边缘测到 `#DE8E52` |
| progress | `linear-gradient(90deg, #B38442 0%, #CE724D 55%, #E8A05A 100%)` | `bg-gradient-to-r from-[#B38442] via-accent-hot to-[#E8A05A]` | 进度条与进行中的百分比 |
| moon | `linear-gradient(90deg, #DF8950, #EEA34F 50%, #E38D4E)` | — | 仅品牌图形，不作为控件色 |

未选中单选、选项卡、白按钮都是纯色，没有描边。

## 3. 字体排版

字体族推断为系统无衬线。标题用粗体，按钮用中粗，说明用常规。Tailwind：`font-sans`。

字号由字形像素高度反推。SF 类字体的大写高度大约是字号的 0.72，再除以 3。标为推断。

| 角色 | 测量字形高 | 推断字号 | 字重 | 行高 | Tailwind |
| --- | --- | --- | --- | --- | --- |
| 问题标题 | 62px ≈ 20.7pt | 28pt | 700 | 紧凑，两行间距约 10pt | `text-[28px] font-bold leading-[34px] tracking-tight` |
| 强调标题 | 首行最高约 79px | 32–34pt | 700 | 紧凑 | `text-[34px] font-bold leading-tight tracking-tight` |
| 弹层标题 | 66px ≈ 22pt | 30pt | 700 | 紧凑 | `text-[30px] font-bold leading-tight` |
| 副标题 / 说明 | 约 34px | 16–17pt | 400–500 | 约 22pt | `text-[17px] font-medium leading-6 text-ink-muted` |
| 选项行 | 与说明同级，颜色为白 | 17pt | 500–600 | 单行居中 | `text-[17px] font-semibold text-ink` |
| 主按钮 | 字形盒约 40px | 17pt | 600 | 单行 | `text-[17px] font-semibold leading-none text-inverse` |
| 分组标题 | 目测小于选项、浅于纯白 | 20pt | 600 | — | `text-xl font-semibold text-ink-muted` |
| 价格主数字 | 与选项行接近 | 17pt | 600 | — | `text-[17px] font-semibold` |
| 价格说明 / 次行 | 明显更小 | 13pt | 400 | — | `text-[13px] text-ink-muted` |
| 徽章 | 大写、很短 | 11pt | 700 | 1 | `text-[11px] font-bold uppercase tracking-wide` |
| 底栏标签 | 图标下的小字 | 11pt | 500 | 1 | `text-[11px] font-medium` |
| 滚轮选中 | 白、比相邻行更大更亮 | 22pt | 600 | 行高约 28pt | `text-[22px] font-semibold text-ink` |
| 滚轮相邻 | 灰 | 20pt | 500 | — | `text-xl font-medium text-ink-faint` |
| 眉题 / 评价小字 | 全大写 | 11pt | 600 | — | `text-[11px] font-semibold uppercase tracking-[0.14em]` |

标题颜色永远是 `text-ink`。说明、法律式短句、未完成步骤用 `text-ink-muted`。进行中的百分比用强调色渐变，不用纯白。

对齐：营销首屏、生日问题、弹层标题居中。问卷标题、选项、进度标签左对齐。价格在卡片内右对齐。

## 4. 间距系统

基准是 4pt。测量值先写成逻辑点，再映射到最接近的 Tailwind spacing（1 = 4px）。

| 位置 | 测量 | Tailwind | 说明 |
| --- | --- | --- | --- |
| 页面左右 | 75px = 25pt | `px-6` | 25pt 介于 `px-6`(24) 与 `px-7`(28) 之间，实现用 24 |
| 选项卡间距 | 约 15px = 5pt | `space-y-1.5` | 推断目标为 6px |
| 选项卡内左内边距 | 文字距卡片左缘 64px = 21pt | `px-5` | 20px |
| 选项卡内右内边距 | 单选圆距右缘约 25pt | `pr-5` | 与页面边距同级 |
| 标题与说明 | 标题块结束到说明约 16pt | `mt-4` | |
| 说明与第一张卡 | 明显大于标题间距，约 24pt | `mt-6` | 推断 |
| 主按钮距屏幕底 | 按钮底到内容底约 77pt | `pb-8` 再加安全区 | 含 Home Indicator 区域，不要再额外叠一层大边距 |
| 双按钮间距 | 约 15pt | `gap-4` | Skip / Next |
| 进度标签与条 | 很紧，约 8pt | `mt-2` | |
| 步骤之间 | 大于卡间距，约 28–32pt | `mt-8` | 推断 |
| 弹层标题与说明 | 约 12pt | `mt-3` | 推断 |
| 弹层说明与按钮 | 约 24pt | `mt-6` | 推断 |
| 徽章与标题的空隙 | 约 8pt | `gap-2` | |

选项卡高度约 **63pt**（188px）。单选圆直径 **20pt**（59px），`size-5`。

## 5. 布局与栅格

单列。内容宽度 = 屏宽减去左右 24px。没有多列栅格，营销首屏的四块插画是内容，不是布局系统。

| 模式 | 结构 | Tailwind |
| --- | --- | --- |
| 问卷 | 返回图标在左，标题在图标右侧并换行，说明在标题下，选项靠上，底部留白 | `min-h-dvh bg-canvas px-6` |
| 居中问题 | 标题在上三分之一居中，滚轮在中部，说明贴在按钮上方 | 纵向 `flex flex-col`，滚轮 `flex-1` |
| 营销首屏 | 标题居中，插画区，社会证明，底部一条主按钮 | 按钮 `mt-auto` |
| 付费墙 | 上半是照片，下半叠深色表面；方案卡全宽堆叠 | 卡片 `space-y-3` |
| 底栏页 | 顶栏标题，横滑日期，内容卡，底部悬浮胶囊栏 | 栏 `fixed inset-x-4 bottom-4` |
| 底部弹层 | 从下往上的深色面板，顶图圆角，标题居中，主按钮贴底 | `rounded-t-[28px]` |

返回控件在左上，距顶约状态栏之下，尺寸约 24pt，颜色 `text-ink`。点击热区按 44pt 做，图标本身更小。

主按钮始终贴在安全区上方，横向撑满内容宽。需要次操作时，两个按钮等宽并排，次按钮在左。

## 6. 组件样式

静态图里没有 hover、按下、焦点环、禁用、加载。这些状态未在当前材料中发现明确证据。下面只记录看得到的状态。

### 主按钮

白胶囊，黑字，无边框，无投影。

| 属性 | 值 |
| --- | --- |
| 高度 | 83px ≈ 28pt |
| 宽度 | 内容宽，左右各留 24px |
| 圆角 | 高度的一半，全胶囊 |
| 填充 | `#FFFFFF` |
| 标签 | `#000000`，17pt，semibold，水平垂直居中 |
| 状态 | 只看到默认态 |

```html
<button class="h-7 w-full rounded-full bg-white text-[17px] font-semibold text-black">
  Continue
</button>
```

`h-7` 是 28px。若按 pt 写死，用 `h-[28px]`。

### 次按钮

与主按钮同高、同圆角。填充用表面色，文字用白色。和主按钮并排时各占一半，中间 `gap-4`。

```html
<div class="flex gap-4">
  <button class="h-[28px] flex-1 rounded-full bg-surface-2 text-[17px] font-semibold text-ink">
    Skip
  </button>
  <button class="h-[28px] flex-1 rounded-full bg-white text-[17px] font-semibold text-black">
    Next
  </button>
</div>
```

### 选项行

整行可点。未选中和选中的底色相同，选中只改变右侧圆点。

| 属性 | 值 |
| --- | --- |
| 高度 | 约 64px，`h-16` |
| 填充 | `bg-surface` |
| 圆角 | 约 15pt，推断 `rounded-2xl`（16px） |
| 内边距 | `px-5` |
| 文字 | `text-[17px] font-semibold text-ink` |
| 未选中圆 | 20px，`bg-control` |
| 选中圆 | 20px，琥珀纵向渐变，无描边、无对勾 |

圆角证据：卡片左缘从顶部向下约 44px（15pt）后进入直边。

```html
<button class="flex h-16 w-full items-center justify-between rounded-2xl bg-surface px-5">
  <span class="text-[17px] font-semibold text-ink">She / Her</span>
  <span class="size-5 rounded-full bg-gradient-to-b from-[#F6C56A] to-accent-deep"></span>
</button>
```

未选中时把圆点换成 `bg-control`。

### 方案卡

结构与选项行相同，但更高，因为有两行字。叠在照片上时表面更亮，读起来像 `bg-white/15` 的毛玻璃，暗底上则回到 `bg-surface`。

| 行 | 样式 |
| --- | --- |
| 标题 | `text-[17px] font-semibold text-ink` |
| 次行 | `text-[13px] text-ink-muted` |
| 右侧价格 | `text-[17px] font-semibold text-right` |
| 价格单位 | `text-[13px] text-ink-muted text-right` |
| 徽章 | `rounded-full bg-violet px-2 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white` |

选中仍然只点亮左侧圆点，卡片没有描边。

### 滚轮

三列，当前行一条深灰胶囊横跨三列。远离中心的行逐步变淡，最远接近背景。

| 属性 | 值 |
| --- | --- |
| 选中条 | `h-9 rounded-full bg-surface-selected` |
| 选中文字 | `text-[22px] font-semibold text-ink` |
| 相邻行 | `text-xl text-ink-faint` |
| 更远的行 | 同一颜色再降透明度，推断 `opacity-40` 到 `opacity-20` |
| 行距 | 约 28pt |

```html
<div class="relative">
  <div class="absolute inset-x-0 top-1/2 h-9 -translate-y-1/2 rounded-full bg-surface-selected"></div>
  <p class="relative text-center text-[22px] font-semibold text-ink">February</p>
</div>
```

### 进度

标签一行：左白字，右强调色百分比。条很细，全圆角。未完成步骤的标签和百分比都降到 `text-ink-muted`，条保持空轨道。

| 属性 | 值 |
| --- | --- |
| 条高 | 约 4px，`h-1` |
| 圆角 | `rounded-full` |
| 填充 | `bg-gradient-to-r from-[#B38442] via-accent-hot to-[#E8A05A]` |
| 轨道 | `bg-track` |
| 百分比 | 与填充同一渐变，用 `bg-clip-text text-transparent` |

### 底部弹层

深色面板，顶部大圆角。内部插画自己再切一圈圆角。标题居中、说明居中灰色、底部同一颗白胶囊按钮。

```html
<section class="rounded-t-[28px] bg-canvas px-6 pb-8 pt-4">
  <img class="h-52 w-full rounded-3xl object-cover" alt="" />
  <h2 class="mt-6 text-center text-[30px] font-bold tracking-tight text-ink">Title</h2>
  <p class="mt-3 text-center text-[17px] leading-6 text-ink-muted">Supporting line</p>
  <button class="mt-6 h-[28px] w-full rounded-full bg-white text-[17px] font-semibold text-black">
    Start here
  </button>
</section>
```

`rounded-t-[28px]` 是推断。面板顶边在截图里明显大于选项卡的 16px。

### 底栏

悬浮胶囊，毛玻璃，五等分。选中项有一块更实的圆形底，图标用 `text-accent`，文字 `text-ink`。未选中图标和文字都是半透明白。

```html
<nav class="flex h-16 items-center rounded-full bg-white/20 px-2 backdrop-blur-xl">
  <a class="flex flex-1 flex-col items-center gap-1 text-ink">
    <span class="flex size-10 items-center justify-center rounded-full bg-white/15 text-accent">●</span>
    <span class="text-[11px] font-medium">Calendar</span>
  </a>
  <a class="flex flex-1 flex-col items-center gap-1 text-white/70">
    <span class="flex size-10 items-center justify-center">●</span>
    <span class="text-[11px] font-medium">Practice</span>
  </a>
</nav>
```

栏高测量约 60pt，用 `h-16`（64px）。玻璃的精确透明度未在当前材料中发现可分离的色值，上面的 `/20` 与 `/15` 是推断。

### 日期格与小胶囊

选中日：`rounded-2xl bg-surface`，星期缩写在上，日期在下，中间一个浅色圆形。未选中日没有底板，文字 `text-ink-muted`。旁边的月入口是同色小圆角块。

功能入口（例如 Dream / Tarot）是 `rounded-full bg-surface px-4 py-2`，眉题 11pt 灰色，标题 15pt 白色。推断 `text-[15px] font-semibold`。

插画上的标签芯片是半透明深灰胶囊，取样约 `#44424A`，文字白色，`rounded-full bg-black/40 px-3 py-1 text-sm text-white backdrop-blur`。

### 返回

细线箭头，白色，约 24pt。没有圆形底板。

## 7. 阴影与层级

控件分割靠背景色差：`canvas` < `surface` < 白按钮。选项卡、主按钮、次按钮的边缘直接落到背景上，没有测到可分离的黑色投影。

| 层级 | 处理 | Tailwind |
| --- | --- | --- |
| 页面 | 无阴影 | — |
| 卡片 / 按钮 | 无阴影 | `shadow-none` |
| 选中圆点 | 渐变本身带一点暖边，不做 drop shadow | — |
| 进度条 | 颜色发光，不是黑色阴影 | 推断 `shadow-[0_0_12px_rgb(206_114_77/0.45)]` |
| 底栏 | 靠模糊和半透明，不靠投影 | `backdrop-blur-xl` |
| 弹层 | 盖住后面的页面，后面页面保持可见但被压暗 | 推断遮罩 `bg-black/50` |

从底到顶：页面、内容卡、底部弹层、悬浮底栏、主按钮（按钮在弹层内部时属于弹层）。未看到独立的模态蒙层色值。

## 8. 动画与过渡

未在当前材料中发现明确证据。截图是静止的。

可以从画面关系推断、但不要当成已测量的规格：

| 场景 | 推断 |
| --- | --- |
| 滚轮 | 行随位移淡出，`transition-opacity` |
| 选中圆点 | 颜色切换，150–200ms |
| 进度条 | 宽度变化，`transition-[width] duration-500` |
| 弹层 | 自底部进入 |

没有时长、曲线或延迟的像素证据。实现时用短、缓出的过渡即可，不要加弹跳。

## 9. 圆角

| 控件 | 测量 | Tailwind |
| --- | --- | --- |
| 主按钮、次按钮、底栏、滚轮选中条、徽章、进度条、芯片 | 胶囊，半径 = 高度 / 2 | `rounded-full` |
| 选项卡、方案卡、日期格 | 直边前的圆角约 15pt | `rounded-2xl` |
| 弹层顶部、弹层内大图 | 大于卡片 | `rounded-t-[28px]`、图片 `rounded-3xl` |
| 单选圆、选中底栏图标底 | 正圆 | `rounded-full` |

没有 4px、8px 这一档小圆角。小控件也走胶囊。

## 10. 不透明度与透明效果

| 用法 | 处理 |
| --- | --- |
| 滚轮非选中行 | 越远越淡，直到接近背景 |
| 未完成步骤文案 | 不另做一套灰，直接 `text-ink-muted` |
| 底栏 | 白的低透明度 + 背景模糊 |
| 选中底栏项的圆形底 | 比栏本身更实一点的白透明度 |
| 插画芯片 | `bg-black/40` 到 `bg-black/55`，推断 |
| 付费墙方案卡 | 照片上的 `bg-white/10` 到 `bg-white/20`，推断 |
| 主按钮、选项文字 | 不透明 |

没有禁用态的整体 `opacity-40` 证据。Skip 是换填充色，不是把主按钮变淡。

## 11. 异常与不一致项

| 类型 | 位置/来源 | 当前值 | 相关规范 | 问题 | 建议 |
| --- | --- | --- | --- | --- | --- |
| 背景 | 第 1–3 屏 vs 第 6、11 屏 vs 第 16 屏 | `#17181F` / `#1C1D23` / `#101118` | canvas | 三档近黑同时存在 | 页面统一用 `#17181F`，`#1C1D23` 只留给分隔，`#101118` 不单开 token |
| 表面 | 选项卡 `#22242A`，Skip `#24252B`，日期格更深 | 相差约 2–8 级 | surface | 次按钮和卡片不是同一灰度 | 次按钮与选项卡共用 `bg-surface` |
| 强调色 | 单选 `#F3B14C`，进度 `#CE724D`，月亮 `#EEA34F` | 金 / 珊瑚 / 橙 | accent | 同一“暖色”有三个色相 | 控件选中用 `#F3B14C`，进度条单独用横向渐变 |
| 标题字号 | 问卷标题字形 62px，社会证明首行约 79px | 28pt 与 34pt | 标题 | 居中营销标题比问卷标题大约一档 | 问卷用 28，只有整屏口号用 34 |
| 按钮高度 | 多屏白按钮 72–88px | 约 28pt | 主按钮 | 抗锯齿让测量有 ±4px 波动 | 固定 `h-[28px]`，不要按截图逐屏改 |
| 玻璃材质 | 底栏、付费墙卡片 | 被底下照片染色 | glass | 取样得不到稳定十六进制 | 用透明度 + `backdrop-blur`，不要取某一帧的混合色 |
| 选中反馈 | 选项卡只改圆点；日期格改整块底色 | 两种选中 | — | 列表和日历不是同一选中语言 | 列表保持“只点亮圆点”，日历才用表面底 |

未发现描边输入框、开关、复选框、Toast、骨架屏或错误红。这些不要从这套图里发明出来。
