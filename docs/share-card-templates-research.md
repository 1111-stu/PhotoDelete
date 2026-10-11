# 分享卡片三模板：调研与规格（极简相框 / 邮票票根 / Colorwork）

决策日期：2026-10-11。
状态：**调研完成；原型见 `designs/share-card-prototype.html`，待验收后落地。**
范围：整理页（`SwipePhotoView`）底栏「分享」→ 卡片预览 sheet；三套模板 + 日期/地点开关 + 分享出图。不含视频卡片、不含多选拼图。

---

## 1. 一句话定稿

**分享不再直发原图，而是渲染一张「卡片」：三套模板（极简相框 / 邮票票根 / Colorwork），模板可切、日期与地点各自可关，出图即分享。**

三张参考图（用户提供）已逐像素测量，规格见 §3——所有数字来自参考图，不是目测。

---

## 2. 三套模板是什么

| # | 模板 | 气质 | 参考图来源 | 出图比例 |
| --- | --- | --- | --- | --- |
| A | **极简相框** Minimal Frame | 近白卡纸 + 3:4 照片内缩 + 左下日期/地点，右下品牌签名 | 参考图 1（竞品「卡片预览」） | **2:3**（1200×1840） |
| B | **邮票票根** Ticket Stub | 棕底白卡，照片下方一张打孔票根：车站名 + 年月日 + 条码 | 参考图 2（NEXT STATION 票根） | **3:4**（1200×1600） |
| C | **Colorwork** | 上半照相片主色大色块 + 打字机体衬线标题，下半满幅照片 | 参考图 3（COLOR WALK） | **3:4**（1200×1600） |

三张都用**同一个 3:4 出图习惯**（A 天然偏长，2:3），适配小红书/朋友圈竖版。

---

## 3. 参考图像素规格（量自原图，原图坐标）

### 3.1 参考图 1 · 极简相框（923×2000，手机截图）

| 项 | 原图值 | 换算到 1200 宽（×1.884） |
| --- | --- | --- |
| 画面底色 | `#F4F5F7`（卡与背景同色，边缘靠极淡阴影分离） | 同 |
| 照片 | x 164..758、y 451..1244 → **595×793 = 3:4**，直角 | 宽 1121，内缩 42 |
| 照片边距 | 左/右 21/22，上 19 | 42 |
| 日期 | 数字高 20px，灰 `#6A6A70` | 字号 ≈ 51 |
| 地点 | 字高 34px，近黑 `#0D0E10`，Bold | 字号 ≈ 66 |
| 签名「回见」 | 右对齐、与地点同行、近黑，≈26px | 字号 ≈ 49 |
| 文字左边距 | 距卡边 36（比照片再缩进 14） | 68 |
| 照片下 → 日期上 | 40 | 75 |
| 日期下 → 地点上 | 29 | 55 |
| 地点下 → 卡底 | 40 | 75 |
| 卡整体 | 637×978 ≈ **1:1.535** | 1200×1840 |

### 3.2 参考图 2 · 邮票票根（1280×1707 = 3:4）

| 项 | 原图值 | 换算到 1200 宽（×0.9375） |
| --- | --- | --- |
| 背景 | 棕 `#855143`，票根居中（左右各留 21.6% 宽、上下各留 14% 高） | 同 |
| 票根卡 | x 276..1003、y 239..1467 → 727×1228，**圆角 ≈52** | 681×1151，圆角 48 |
| 卡底 | 纯白 `#FFFFFF` | 同 |
| 照片 | 内缩 22（同色白边），683×880 ≈ 7:9，**圆角 ≈20** | 内缩 21，圆角 19 |
| 照片下白带 | 29px，**虚线就压在票根上缘**（不在白带中间） | 27 |
| 撕票虚线 | 深色（黑 ~45%）dash 7 / gap 5 / 粗 2.5 | 同 |
| 打孔缺口 | 左右各一个半圆，**半径 ≈21**，圆心在虚线处 | 20 |
| 票根区 | 虚线→卡底 = 294 高，底色 `#B87D6D` | 275 高 |
| 标签（NEXT STATION / YEAR / DATE） | cap 24，宽字距大写，深色 | cap 22.5 |
| 站名（FANTASY WORLD） | cap 59、行距 60、Bold 近黑 | cap 55 |
| 点线分隔 | 站名下一条细点线 | 同 |
| YEAR / DATE 数值 | 2026 / 07.30，cap ≈30 Bold；两列间距 146 | cap 28，列距 137 |
| 文字左边距 | 距卡边 64（比照片缩进 42） | 60 |
| 条码白板 | 84 宽 × 250 高，**右侧贴死卡边**，上距票根顶 23、下距卡底 20 | 79×235 |
| 条码 | 水平条纹 + 竖排数字串（整体旋转 90°） | 同 |

### 3.3 参考图 3 · Colorwork（1280×1707 = 3:4）

| 项 | 原图值 | 换算到 1200 宽（×0.9375） |
| --- | --- | --- |
| 色块 | 上半**正好 50%**（853/1707），色值取自照片主色（示例 `#314B01`） | 上半 800 |
| 标题 | COLOR WALK，纯白，打字机体衬线、大写、宽字距，cap 36 | cap 34 |
| 日期 | July 30, 2026，同字体小一号、留原大小写，cap 23 | cap 21.5 |
| 标题→日期 | 41 | 38 |
| 文字组位置 | 色块内**垂直居中**（组中心 422 vs 块中心 426） | 居中 |
| 照片 | 下半满幅，通栏出血 | 同 |

---

## 4. 数据来源（都用现成的，不造新指标）

| 卡片元素 | 数据源 | 备注 |
| --- | --- | --- |
| 照片 | 当前 `PHAsset` 全尺寸图（`PhotoLibraryManager` 已有单张取图路径） | 预览用 `reviewLarge` 级缩略图，出图前再拉全尺寸 |
| 日期 | `asset.creationDate` | 缺省（如截图）时隐藏日期行/降级 |
| 地点 | `PhotoLocationTitleCacheStore` 的 `PhotoLocationResolvedTitle.title`（已是「深圳·宝安」格式） | 无定位 → `显示地点` 开关置灰 |
| 签名（A）/ 站名（B） | 品牌文案，默认「回见」/「下一站」 | 待定：是否用 App 名替换 |
| 条码（B） | `asset.localIdentifier` 哈希 → Code128 | 每次分享稳定可复现 |
| 色块（C） | 照片主色提取（见 §5.4） | 与照片同色系即为设计意图 |

---

## 5. iOS 落地路径

### 5.1 出图：SwiftUI `ImageRenderer`（iOS 16+，目标 18 无压力）

- 预览与出图**共用同一个 SwiftUI 卡片视图**（`ShareCardView(template:photo:meta:)`），预览按屏幕尺寸缩小，出图按 `renderer.scale` 放大 → 所见即所得。
- `renderer.scale = 2`（1080 宽 ≈ 2160px 输出）就够；社交平台二次压缩，@3x 只会吃内存（3240×5760 ≈ 75MB）。
- **`ImageRenderer` 是 `@MainActor` 且同步**：出图前必须先拿到全尺寸 `UIImage`（`AsyncImage` 会渲染成空白），在按钮 loading 态里完成。
- 出图后写临时 PNG（复用 `PhotoSharePayload` 的目录清理逻辑），再交给现有 `SystemShareSheet`。
- 参考资料：[Apple · ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer)、[Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-convert-a-swiftui-view-to-an-image)、[Create with Swift](https://www.createwithswift.com/exporting-swiftui-views-to-images-with-imagerender/)。

### 5.2 票根打孔与虚线（模板 B）

- 打孔：整卡用 `Canvas`/`Path` 画成一张蒙版（圆角矩形 + 两个半圆相减，`evenOdd` 填充），照片层 `.mask()` 之——比叠同色圆点干净，换背景色不穿帮。
- 撕票虚线：`Path` + `StrokeStyle(lineWidth: 2.5, dash: [7, 5])`。
- 出图时蒙版与预览同一套代码，不会出现「预览有孔、出图没孔」。

### 5.3 条码（模板 B）

`CIFilter` 内置 `CICode128BarcodeGenerator`（`CoreImage`，无第三方库）：

```swift
let filter = CIFilter(name: "CICode128BarcodeGenerator")
filter?.setValue(Data(asset.localIdentifier.utf8), forKey: "inputMessage")
filter?.setValue(8, forKey: "inputQuietSpace")
// 产出横条码 → 旋转 90° → 放进右侧白板；数字串用同一份 seed 拼串竖排
```

### 5.4 主色提取（模板 C）

- 下采样到 ~64px → `CIFilter(name: "CIAreaAverage")` 读 1×1 中心像素；再按 HSL 做一次「提纯」（压低亮度、提高饱和度），保证白字对比度 ≥ 4.5:1，避免浅色照片撞出白底白字。
- 兜底：提取失败 → 退到 `Theme.surface`。**这是模板 C 的签名，必须有兜底。**

### 5.5 字体

| 模板 | 字体 | 说明 |
| --- | --- | --- |
| A | SF Pro / PingFang（系统） | 中文标题走 PingFang Semibold |
| B | SF Pro（Helvetica 感）大写宽字距 | 参考图为 Helvetica Bold，SF 最接近且免费 |
| C | **American Typewriter**（iOS 内置，`Font.custom("AmericanTypewriter", size:)`） | 参考图即打字机体衬线；**内置可商用，不必也不允许把字体文件打进包** |

参考：[iOS 内置字体清单](https://github.com/feb19/fontlist-apple)、[SwiftUI Font.custom 用法](https://stackoverflow.com/questions/78796708)。

### 5.6 其他

- **编号（非海量）**：模板目录写死 3 个 enum（`ShareCardTemplate.minimalFrame / ticketStub / colorwork`），以后加模板只加枚举 + 视图。
- 渲染失败 / 无照片 → 分享按钮保持可点但弹现有错误提示；不静默失败。

---

## 6. 交互定稿（预览 sheet）

```
┌──────────────────────────────┐
│ 取消          卡片预览         │  ← 顶栏；取消 = 关闭 sheet
│                              │
│      ┌──────────────┐        │
│      │   卡片实时预览  │        │  ← 与出图同一视图；随模板/开关即时变
│      └──────────────┘        │
│                              │
│  ▢ 极简   ▢ 票根   ▢ COLOR   │  ← 模板三选一（琥珀选中；小样=真图缩略）
│  显示日期            (开关)   │  ← 无日期数据 → 置灰
│  显示地点            (开关)   │  ← 无定位 → 置灰
│  ┌────────────────────────┐  │
│  │         分享            │  │  ← 全 sheet 唯一琥珀
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- 入口：整理页底栏「分享」（现在是直发原图，改为此 sheet）。
- 开关默认全开；关掉只影响卡片，不影响原图。
- **不做**：模板内文字编辑（站名/签名）、多张拼图、自定义配色——先看用户要不要。

---

## 7. 边界与不做

- 视频 / Live Photo：分享原文件，不给卡片（卡片模板对视频无意义）。
- 照片横构图：卡片按容器 `aspectFill` 裁切，不整卡变形。
- 无 `creationDate`（截图/导入）：日期行整行隐藏，开关置灰。
- 无地点：地点行隐藏；参考图 A 的「回见」签名保持右对齐不塌陷。
- **不做**：模板付费墙、水印、二维码、AI 文案。

---

## 8. 落地检查清单

- [ ] `ShareCardTemplate` 枚举 + `ShareCardView` 三套分支（先用固定尺寸 1200 宽出图）
- [ ] 预览 sheet 替换现有「分享直发」路径；原图分享保留一个文案出口（待定）
- [ ] `ImageRenderer @2x` + 临时 PNG + `SystemShareSheet` 闭环；分享后清理临时目录
- [ ] CICode128BarcodeGenerator / CIAreaAverage（含对比度兜底）/ American Typewriter 三个点各自真机验证
- [ ] 无日期、无地点、连拍横构图三个降级态截图回归
- [ ] `style.md` 增补「分享卡」一节（出图比例 / 字体 / 不与 App 琥珀体系混用的说明）
