# 相册拖拽排序：现状调研与交互方案 v1

日期：2026-10-09。依据当前 `ios-app/` 工作区（包含现有暂存改动）。本阶段产出调研与可交互原型，未修改原生 App。

## 结论

排序的**数据层已经完整**：`saveCustomAlbumOrder` + `albumsSortedByCustomOrder` 稳定排序，新建相册自动前置。问题全在 UI 层：

1. 排序只在 **列表布局 + 编辑模式** 下可用，且是系统 `List.onMove`（拖动把手 + 系统高亮），没有落点表达，视觉粗糙。
2. **紧凑 / 海报两种网格完全没有排序入口**；想排序必须先切到列表（`beginReorderingFromDisplaySheet` 强制换布局）。
3. 网格 tile 的长按已经被 `contextMenu`（整理 / 编辑 / 删除）占用 —— 这是本次交互必须先解决的核心冲突。

建议方案：三种布局统一为 **长按抬升 → 拖动 → 站位（空位）→ 落位**；长按后**原地松手**仍弹出原菜单，移动则进入排序；搜索状态下禁用排序（沿用现有文案与 Toast）。

## 现状地图

| 能力 | 位置 | 现状与限制 |
| --- | --- | --- |
| 三种展示方式 | `AlbumBrowserViews.swift:9`（`AlbumDisplayStyle`：compact / cover / list） | 紧凑 3 列（iPad 5）、海报 2 列（iPad 4）、列表 |
| 网格容器 | `AlbumsView.swift:237`（`albumCoverBrowser`） | `LazyVGrid`，列间距 14、行间距 18 |
| 网格 tile | `AlbumBrowserViews.swift:258`（`AlbumCoverTile`） | 方形封面（紧凑圆角 14 / 海报 18）+ 右下数量胶囊 + 居中标题 |
| 网格长按 | `AlbumsView.swift:286`（`albumCoverButton.contextMenu`） | 已被菜单占用：整理 / 编辑 / 删除 |
| 列表行 | `AlbumsView.swift:817`（`AlbumInfoRow`）+ `:449`（`albumRow`） | 36pt 缩略图 + 标题 15/600 + 数量；`insetGrouped` 分组卡 + hairline |
| 唯一的排序实现 | `AlbumsView.swift:339`（`ForEach.onMove`） | 仅 `editMode == .active` 时挂载；编辑模式由顶栏「完成」或显示方式 sheet 进入 |
| 排序入口 | `AlbumsView.swift:581`（`beginReorderingFromDisplaySheet`） | 显示方式 sheet 的「排序」按钮 → **强制切到列表** + 进入编辑模式 |
| 排序持久化 | `AlbumsView.swift:600`（`moveUserAlbums`）→ `DataManager.swift:3677` | 写全量 id 顺序到 UserDefaults（`customAlbumOrderKey`） |
| 排序读取 | `DataManager.swift:3692`（`albumsSortedByCustomOrder`） | 不在 order 里的相册排在已排相册之后，按原序 |
| 新建相册 | `DataManager.swift:3740`（`insertCreatedUserAlbum`） | `customAlbumOrderByPrepending` 前置插入 |
| 搜索与排序互斥 | `AlbumsView.swift:589`、`:601` | 搜索非空时进不了排序 / 拖动被拒绝，提示「先清空搜索再排序」 |
| 提示行 | `AlbumsView.swift:746`（`AlbumSwipeHintRow`） | 只在列表布局出现：「Use Sort in the top right to reorder」 |
| 字符串 | `Localizable.xcstrings` | 已有可复用语料：`Clear search before reordering`、`Reorder`；遗留未用的 `长按相册可自定义排序` / `Tap to organize this album. Touch and hold to reorder.` |
| 历史 | 2026-07-27 `1b78710` | 上一版排序入口是列表行的 contextMenu「调整顺序」，随滚动优化一并移除，改为显示方式 sheet |

## 交互决策（本版方案）

1. **触发**：长按 0.4s 抬升（缩放 1.06 + 浮起阴影 + 中等触觉）。抬升后**手指移动** → 进入拖拽；**原地松手** → 弹出原有 contextMenu。长按与菜单共存，不牺牲整理 / 编辑 / 删除入口。
2. **站位**：被拿起的那一格留在原位变成「空位」——与封面同尺寸同圆角的空槽，填充浮层色（`#1E1E24`）+ 琥珀 22% 细描边（对齐「输入框 / 选中」既有语言）。拖到别处时，空位跟着换位，原位置不会出现"两个洞"。
3. **让位**：拖动经过其他项中心时，其余项 0.22s 平移让位（列表为整行高度，网格为整格），每次换位一次 selection 触觉；空位本身不做补间，直接跳位。
4. **落位**：松手后浮起的卡 0.18s 落回空位，轻触觉，随后写回顺序（`saveCustomAlbumOrder`）。
5. **布局一致**：三种布局用同一套手势与状态机，只有站位尺寸 / 圆角跟随布局（封面 18、紧凑 14、列表为卡片形状）。列表从「一张分组卡 + 分隔线」改为**每个相册一张独立卡片**（surface 底、圆角 16、间距 8、内边距 12/14）：托出的是一整张卡，空位也是一整张卡，站位语言与网格完全一致；同时不再依赖 `List.onMove` 与编辑模式，拖动把手一并去掉。
6. **入口与文案**：显示方式 sheet 的「排序」按钮改为一行提示（长按即可排序，不再强制换布局）；顶部可关闭提示行文案同步改为「长按相册拖动即可排序」。无障碍路径：每项提供「上移 / 下移」自定义动作与位置播报（第 N 个，共 M 个）。
7. **搜索互斥**：搜索非空时禁用长按排序并沿用现有提示（「先清空搜索再排序」），不做过滤态排序。
8. **自动滚动**：拖到滚动区域上下边缘 90pt 内自动滚动，站位随滚动实时更新。
9. **数据边界**：只重排当前未过滤的全量顺序；拖动结束写全量 id；拖动期间冻结列表（`rebuildDisplayedRows` / DataManager publish 不打断手势）。

## 实现要点与风险（供落地评审）

- `List.onMove` 无法用于网格，三布局统一需要自定义手势：`LongPressGesture` 与 `DragGesture` 组合（或 iOS 16+ 的 `draggable` / `dropDestination`，但系统拖放在同 App 内排序的落点表达与让位动画不可控，不推荐）。自定义手势需要在抬升后屏蔽父 `ScrollView` 滚动。
- 让位动画建议手写 FLIP（记录 rect → 变更 → 补间），避免 `withAnimation` 驱动整个网格重建。
- 拖动中若 `dataManager.$userAlbums` 或搜索变化触发 `rebuildDisplayedRows` 会打断会话：拖动期间应冻结列表快照，结束后再合并。
- 触觉：抬升 `.impact(.medium)`、换位 `.selection`、落位 `.impact(.light)`（`HapticManager` 已有对应封装）。
- 列表布局改为独立行卡后，`List` + `insetGrouped` 的分组语义不再合适（分隔线、行背景、`onMove` 都绑定在 List 上），建议列表走 `ScrollView` + `VStack` 卡片自绘，或继续用 `List` 但以 `.listRowBackground` 画卡片 + `.listRowInsets` 留间距 + `.listRowSeparator(.hidden)`。这一改也会让 style.md §4.1「同一组内容用一个外层卡片」在相册页有一个明确的例外，规范需要同步补一句。

## 原型与验证

`designs/albums-reorder-prototype.html` 为独立可交互原型：三种布局可切换，支持真实的长按（0.45s）→ 抬升 → 拖动 → 站位 → 落位全流程、原地松手弹菜单、搜索态禁用、边缘自动滚动与自动演示。使用合成相册数据与 CSS 示意封面，不访问真实相册、不写任何存储。

原生实现建议新增一个手势状态机（`AlbumReorderSession`：idle / armed / dragging / settling）承载上述逻辑，网格与列表共用；`AlbumsView` 的编辑模式与 `onMove` 路径、`AlbumDisplayStyleSheet` 的「排序」按钮随之删除。验证重点：三布局换位索引、跨行拖动、自动滚动、搜索互斥、菜单与拖拽互不误触、落位后顺序持久化与重启恢复。

**已在浏览器实测（2026-10-09，Chrome / 合成指针事件）**：长按 0.45s 后抬升且只存在一个浮起卡；拖到目标格后站位与该格同尺寸（封面 168 / 紧凑 107 / 列表整卡），填充 `#1E1E24` + 琥珀内描边；越过其他项中心时换位索引正确并在松手后写回顺序；切换布局后顺序保留；原地松手弹出整理 / 编辑 / 删除菜单且不残留浮起卡；搜索非空时长按被拒并提示；过滤、重置、`Esc` 收菜单均正常；控制台无报错。截图见 `designs/albums-reorder-cover.png`、`-compact.png`、`-list.png`、`-menu.png`、`-search.png`（headless Chrome，390×844 @2x）。该检查是原型层的交互验证，不等于原生移动端、触屏手势与无障碍验收。
