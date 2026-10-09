# 专项素材浏览页与筛选 Sheet：SwiftUI 接入调研

调研日期：2026-10-09。依据当前工作区（包含已有暂存改动）、已确认的 `designs/screen-recordings-prototype.html` 卡片原型，以及 `ios-app/UI_GUIDELINES.md`。本轮只调研与记录方案，未改原生业务代码、未执行构建。

## 结论与范围

采用一个通用 `CleanupAssetBrowserView`，一个 `CleanupAssetFilterSheet`，配套 Service 层通用素材查询，以及页面级可观察模型。查询服务支持分类与相册来源，页面首期接入三个专项。首期同时支持屏幕录制、视频、截图；不分别建设三个页面，也不让 sheet 自己取 Photos 数据。

原型表达信息结构和卡片样式。原生页面使用系统导航栏、系统返回手势、系统 sheet、安全区和项目主题。现有相册浏览页与高级多选清理页保留各自交互，提取底层能力供新页面使用；本轮不把相册、压缩、相似照片一并迁移。

| 配置 | 素材源 | 卡片差异 | 点击 | 主操作 |
| --- | --- | --- | --- | --- |
| `.screenRecordings` | `getRealPhotos(for: .screenRecordings)` | 播放图标、时长 | 视频预览 | 整理当前结果中的待整理项 |
| `.videos` | `getRealPhotos(for: .videos)` | 播放图标、时长；包含录屏这一视频子集 | 视频预览 | 同上 |
| `.screenshots` | `getRealPhotos(for: .screenshots)` | 不显示播放图标和时长 | 图片预览 | 同上 |

三个分类首期共用四组筛选及默认值：拍摄时间全部、整理状态全部、不分组、占用从大到小。query 属于当前浏览页面；关闭 sheet、关闭预览、从整理返回都保留，离开分类后重新进入恢复默认。不写入全局排序设置，不跨分类串用状态。

## 已有能力与证据

以下行号对应本轮工作区。

| 能力 | 当前代码 | 接入判断 |
| --- | --- | --- |
| 三类资产源 | `Services/DataManager.swift:1444` | 可直接复用分类集合，不重新扫描 Photos；录屏系统子类型识别在 `Services/PhotoLibraryManager.swift:66` |
| reviewed 状态 | `DataManager.swift:262`、`:1283`、`:1303` | 使用本 App 的 `reviewedAssetIDs` / `isReviewed`；浏览、播放不标记整理；系统收藏不能自动等同于整理 |
| 缩略图 | `Views/AlbumBrowserViews.swift:298` | 可先组合 `AlbumAssetThumbnail`；后续提取中性名称并支持直接传 PHAsset，减少每张按 ID fetch。保留取消和代际校验，补内容修改后的刷新 |
| 分组 | `AlbumBrowserViews.swift:127` | 提取/扩展分组 builder，保留相册旧调用默认行为；现有组间始终倒序、无日期标题为空，需要显式组顺序与无日期标题 |
| 懒网格 | `AlbumBrowserViews.swift:393` | 复用 `ScrollView → LazyVStack → LazyVGrid` 的结构，新增完整素材卡片；原相册 density 固定列数不直接照用 |
| 筛选 sheet | `AlbumBrowserViews.swift:517` | 复用系统呈现结构；内容绑定为相册类型、密度、日期排序，不能直接当本次 sheet。现有按本地化标题回查枚举的方式不沿用 |
| 主题与卡片 | `Views/Components/DesignSystem.swift:187`、`:203`、`:709`、`:713` | 复用背景、card、primary button、语义字体和颜色；不硬编码 HTML 的暗色值 |
| 真实大小及状态 | `PhotoLibraryManager.swift:478`、`:1973`、`:1999` | `AssetFileSizeEstimate` 已统一图片/视频，`VideoFileSizeEstimate` 是类型别名；可靠值、iCloud、unavailable 已区分 |
| 共享大小缓存 | `DataManager.swift:2391`、`:2413` | 直接复用读写接口；不能把 `estimatedSizeMB` 的时长/分辨率回退估算冒充真实大小 |
| 分批加载 | `Views/AdvancedView.swift:1799`、`Views/BatchReviewViews.swift:338` | 提取有限并发、批量发布、取消/generation 策略；现有高级页主要只读可见范围，不能直接承诺全库大小排序 |
| 预览 | `AdvancedView.swift:5790`、`:6090`；`BatchReviewViews.swift:985` | 视频播放器、图片缩放已有；外层预览为 private，提取只读预览组件，去除高级列表的多选依赖。不能用 SwipePhotoView 代替只读预览 |
| 整理会话 | `Services/PhotoReviewSource.swift:4`、`Services/PhotoReviewSession.swift:6` | 保留现有队列、撤销、候选库、批确认；新增显式范围输入 |
| 周期浏览 | `Services/TimePeriodBrowser.swift:11` | 面向周期统计，不是“15天以前”的素材过滤，不直接复用日期边界语义 |

## 推荐组件与数据流（按相册复用需求修订）

查询能力放在 `Services/AssetQuery/`，使用中性的 Asset 命名。将“从哪里取素材”与“怎样筛选素材”分开；分类和相册共用查询执行流程，分别使用对应的数据来源适配。View 不调用 Photos、不自行 filter/sorted，也不执行容量任务。

```text
专项素材页 / 相册浏览页
  → 页面级 AssetBrowserModel（SwiftUI 可观察适配层）
      → AssetQueryService（查询、更新订阅、任务取消）
          → AssetSourceResolver（分类集合 / 相册成员）
              → 既有 DataManager / PhotoLibraryManager
          → AssetSizeLoader（共享容量缓存、有限并发读取）
          → AssetQueryEngine（纯筛选、排序、分组、汇总）
      ← AssetQueryResult（统一结果快照）
  → 筛选 sheet 只绑定 model.query
  → 整理操作根据场景 policy 冻结当前结果 → SwipePhotoView
```

这套 SwiftUI 可观察模型承担用户所说的 hook 作用：View 声明依赖、绑定筛选、展示状态和触发意图即可，沿用现有 ObservableObject / @StateObject，无需为了模仿 React 再造 hook 机制。

| 层 | 职责 | 不负责 |
| --- | --- | --- |
| `AssetSourceResolver` | 解析分类或稳定相册标识、加载成员、处理来源不存在/失去权限 | UI 和排序状态 |
| `AssetQueryEngine` | 对不可变素材元信息执行条件过滤、稳定排序、分组、全结果统计 | Photos 请求、缓存、副作用、本地化文案 |
| `AssetQueryService` | 协调来源、engine、容量 loader、库/相册成员/reviewed 修订事件，发布一致结果 | 全局共享筛选条件、sheet 展开状态、导航、Photos 写入 |
| `AssetBrowserModel` | 每页面持有 query/result/loading/error；请求生命周期、reset、可见范围优先级；UI 意图桥接 | 重写查询算法 |
| View / sheet / card | 布局、绑定、文案、预览与导航事件 | 数据扫描、筛选排序、容量读取 |

服务可共享依赖和缓存，但**每个页面独立查询会话**。打开录屏页和相册页不能共用一个 singleton.currentQuery；一个页面离开也不能取消另一页面的任务。共享容量请求可以按素材 ID + 内容版本去重，按调用者管理取消。

建议文件分工：

- `Models/AssetQueryModels.swift`：AssetSource、AssetQuery、筛选枚举、元信息快照、result、分组标识；不依赖 SwiftUI。
- `Services/AssetQuery/AssetSourceResolver.swift`：封装现有分类集合与相册读取，不另建平行图库。
- `Services/AssetQuery/AssetQueryEngine.swift`：纯查询算法，可独立单测；后台执行使用 Sendable 值快照，不直接跨隔离域传 View/可变 DataManager 状态。
- `Services/AssetQuery/AssetQueryService.swift`：页面级查询会话/更新流与取消，注入 resolver、size loader；容量缓存仍复用既有存储。
- `Services/AssetQuery/AssetSizeLoader.swift`：容量任务、去重、优先级、版本和失效处理。
- `ViewModels/AssetBrowserModel.swift`：@MainActor ObservableObject，向 SwiftUI 提供可绑定状态；项目也可暂放 Services，但职责是页面适配层。
- `Views/CleanupAssetBrowserView.swift`、`Views/CleanupAssetFilterSheet.swift`、`Views/Components/CleanupAssetCard.swift`：首期专项 UI；相册未来复用 service/model 时可保留自己的页面外观和默认配置。
- 共享缩略图/只读预览提取文件；原相册/高级页面通过兼容接口继续调用。

核心接口示意（方案，尚未实现）：

```swift
enum AssetSource: Hashable {
    case category(AssetCategoryID)
    case album(AssetAlbumReference)
}

// 分类 ID 覆盖视频、录屏、截图等；album reference 使用稳定 ID，
// 区分用户相册、系统智能相册以及现有虚拟相册，不以相册标题作键。
struct AssetQuery: Equatable {
    var source: AssetSource
    var content: AssetContentFilter = .all
    var age: AssetAgeFilter = .all
    var reviewStatus: AssetReviewFilter = .all
    var grouping: AssetTimeGrouping = .none
    var sort: AssetSort = .newestFirst
}

protocol AssetQueryServing {
    // 每次调用建立独立会话。query 改变时取消旧流；
    // 同一流持续发布容量、图库与整理状态变化后的快照。
    func results(for query: AssetQuery) -> AsyncThrowingStream<AssetQueryResult, Error>
}

@MainActor
final class AssetBrowserModel: ObservableObject {
    @Published var query: AssetQuery
    @Published private(set) var result: AssetQueryResult?
    // loading / error / refresh / reset / visibleIDs 等页面接口
}
```

示意的 AssetCategoryID / AssetAlbumReference 需依据当前 PhotoCategory / AlbumInfo 定义适配，避免要求现有类型直接满足尚未具备的 Hashable/Sendable。服务初期只有一个本地实现，无需引入额外 repository 框架。

专项配置的默认 query 为全部时间/状态、不分组/容量降序。相册配置可保留全部内容/按日/最新在前；其“照片、视频、收藏”作为 content 条件由 engine 执行。密度属于展示偏好，仍留在页面模型，不混入素材查询或触发容量重读。日期标题、本地化容量和主题颜色由展示层生成，engine 只返回稳定组键和数值。

sheet 通过类型化枚举更新 query；可用分区由页面配置指定。专项显示时间/整理状态/分组/排序，相册可显示内容/分组/排序及独立展示密度。重置回各自默认值。不要通过本地化标题反查枚举。

### 相册接入与整理语义

`DataManager.getPhotosForAlbum`（`:3595`）已经兼容真实 PHAssetCollection 与一部分虚拟分类，resolver 复用它；用户相册用稳定 ID 重新解析当前对象，不能长期依赖进入页面时的旧 AlbumInfo。相册删除返回来源不存在状态；成员增减、同 ID 编辑、权限变化、重命名均需要对应更新，不能只观察数量。

读取/过滤可共用，整理队列策略必须由场景显式决定：专项默认只整理未 reviewed 项，而 `PhotoReviewSessionReviewedStatePolicy`（`Services/PhotoReviewSession.swift:164`）当前相册模式不使用全局 reviewed 跳过素材。服务返回全部匹配 ID、顺序与 reviewed 信息，不替所有调用方强制裁成 pendingIDs；页面的 review policy 决定本轮目标和按钮计数。相册采用显式范围后也必须保留 album context，不能意外变成普通分类整理。

首期实现 service 的分类与相册来源及单测，专项先接入 UI；相册已有过滤/排序可随后迁移到同一 service，不要求先重做相册外观。这样相册支持在服务契约与测试中落地，而非只预留一个没有实现的枚举分支。

## 查询语义先统一

一次构建得到同一结果快照，供网格、顶部统计、sheet 结果提示、预览顺序、开始整理共同使用，防止各处自行过滤后统计不一致。

1. resolver 取得分类/相册素材快照；engine 根据 content、age 与 reviewed 过滤。
2. 不分组则全列表稳定排序；分组则先建立日/月桶，再排序每个桶。最近/大小排序时组间最近在前，最早排序时组间最早在前。无日期组始终末尾并给本地化标题；不能直接反转所有组而把无日期放到最前。
3. 最终 sections 展平为浏览顺序，服务返回所有匹配 IDs 与 reviewed 信息。专项页面的 review policy 在该顺序上移除已整理资产得到 `pendingIDs`，按钮项数与之保持一致；相册按自身 policy 生成本轮目标。不能只传分类或相册而丢掉筛选。
4. 汇总针对所有匹配素材，不是分页已渲染的前 40 项。总大小是当前结果的大小，包含已整理资产，不代表删除后可释放空间。

日期边界建议固定为用户本地日历的自然日：15/30/180 天以前为严格早于“今天零点减 N 个日历日”；1 年以前按 `.year` 减一而非 365 天。engine 注入 now/calendar，页面跨日或重新活跃时更新参考日；非全部时间筛选排除无日期资产。与 HTML 逐毫秒比较的演示逻辑在原生接入时统一为该规则，并覆盖边界测试。

排序比较器显式比较创建日期，不能沿用 `PhotoReviewSortOrder.apply` 对“输入已经最新在前”的假设。容量排序将可靠值优先、按大小倒序；同大小按日期，再按 assetID。未读取、iCloud、不可用均不能当 0 MB。日期排序下缺失日期始终末尾，同日期按 assetID。

## 容量加载是图片/视频共用时的主要成本

已存在的图片大小方法通过 `requestImageDataAndOrientation` 读取本地图片数据，并非轻量资源长度查询；视频方法也要请求本地 AVAsset。两者均禁止列表自动下载 iCloud 原件。因此截图分类不能在主线程逐张读完整图片、也不能无限并行读取整个截图库。

推荐由查询 service 协调统一 `AssetSizeLoader`，复用现有 `AssetFileSizeEstimate` 与 DataManager 缓存。先回填缓存，优先可见范围，再低并发/串行读取其余匹配素材，按小批次发布；图片串行作为初始实现，每次尽快释放临时 Data。并发量和批大小通过真实图库性能测量调整。退出/更换素材源时取消任务，generation 校验拒绝过期结果；补足 Photos 请求 ID 级取消，不能只有 await 结束后的 Task.checkCancellation。

卡片容量状态分开表示：未读取/读取中、可靠容量、iCloud、不可用。不能把所有未知值统一标为 iCloud。顶部显示“计算中”或已知容量与未知项数；只有所有项可靠才显示完整总大小。

默认按容量排序时，完整本地读取完成前只能展示缓存已知项优先的暂定顺序；界面应表示仍在计算。批次更新统计，不在滚动或触摸中持续重排卡片；空闲时合并提交重排并保持可见锚点。用户可以在读取完成前开始整理，届时冻结当前展示顺序。这样能立即进入页面，又不声称未完成的排序已严格覆盖全部素材。

缓存有效性需要补齐：目前 `DataManager.swift:439` 的图库回调清理视频缓存，但通用 `assetFileSizeEstimateCache` 仍可能保留同 ID 编辑前的值。建议统一缓存条目携带 asset modificationDate，并按库修订号重新验证/剔除；iCloud/unavailable 不永久负缓存，预览下载后、返回页面或显式刷新时可重试。新页面不要覆盖 PhotoLibraryManager 已被 DataManager 使用的单回调；在 DataManager 增加轻量库内容修订号/事件，包含同 ID 编辑、权限变化、删除和分类变化。

## 网格与 Sheet 的原生落地

素材卡片保持独立 surface + 细描边、16pt 连续圆角、约 6pt 内边距；封面 1:1，日期在左、容量在右的 HStack 保持同一行。采用项目已有圆角/字体 token；原型 10px 封面圆角可对应现有 12pt token，无需创造新的一套样式。

列数根据实际内容宽度与动态字号决定，不使用设备型号或网页 viewport 的阈值。标准字号优先三列，日期/容量最小可读宽度不够则两列；辅助功能大字号降至一列。用缩放语义字体、单行约束、紧凑本地化日期/容量格式，避免靠 `.minimumScaleFactor` 无限压小文字。预览和 VoiceOver 给完整日期/容量；选中/已整理状态同时有文字或勾选。

页面系统 push；底部用 `.safeAreaInset(edge: .bottom)` 放开始整理按钮。sheet 采用 `.sheet` + 本地 `NavigationStack` + `ScrollView`，单选绑定即时生效，关闭/下拉保留选择，重置回当前分类默认。推荐普通字号初始 `.fraction(0.75)`，可扩为 `.large`；小屏/辅助功能字号直接 `.large`，始终可滚动。初始档位最终以原生模拟器验证调整，不复制 HTML 的固定像素高度。

四个筛选分区由 typed option grid 展示，时间 5 个选项自然换下一行；大字号减少选项列数。图标按钮和选项点击目标至少 44pt，系统 SF Symbols，本地化简中/繁中/英文，浅色与暗色均遵循当前主题。素材卡片不叠自定义 glass，iOS 26 导航和 sheet 让系统自然呈现。

系统 API 依据：[presentationDetents](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))、[safeAreaInset](https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-4s51l)、[ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)。自适应布局与档位选择是本方案的设计建议，不是文档要求；仅用 ViewThatFits 不能代替外层网格列数对可读宽度的判断。

兼容性核查：AGENTS 概述为 iOS 16+，但当前 app target Debug/Release 实际 `IPHONEOS_DEPLOYMENT_TARGET = 17.0`（`PhotoDelete.xcodeproj/project.pbxproj:461`、`:486`）；project 级为16。该功能选择16+基础 API，不自行调整部署目标；使用17+/26专属修饰符时保留适当 availability。

## 整理范围接入是必须修改的行为接口

当前 `SwipePhotoView` 未提供显式素材范围，`PhotoReviewSource.photos` 会按类别重新获取资产，`usesChronologicalOrder` 又会应用全局新旧排序。只在浏览页筛选再传 `.screenRecordings` 会丢掉筛选、大小顺序和分组顺序。

建议为 SwipePhotoView 增加可选通用 `ExplicitAssetReviewScope` 输入（orderedAssetIDs、独立 scopeID、来源上下文与 reviewed policy），并传入 PhotoReviewSource。该输入优先解析 `orderedAssetIDs`，按输入顺序映射当前有权限的 PHAsset，跳过全局日期排序；保留旧调用默认路径。

专项进入整理时冻结当前 `pendingIDs`；相册按其 policy 冻结目标 IDs。不在每个 reviewed 更新时重新过滤本轮队列，避免已操作的素材立即消失、破坏撤销和位置。库变化只剔除已不存在/失去权限的素材并更新对应对象，不加入新增素材或按新容量重排。继续复用 PhotoReviewSession 的分页、reviewed 状态、PhotoReviewActions、候选库和 BatchConfirmView，不绕过现有写入管理器。

首期显式范围使用临时 scope ID，不读写既有 `category:*` 进度游标；reviewed 决策仍照常持久化。返回网格后按现有 query 更新统计/状态与素材，重新点开始即可从剩余项开始。若以后要精确跨退出恢复筛选会话，再设计范围签名与有界持久化，避免为每次 UUID 永久存一条游标。旧分类/相册/随机整理的进度行为保持原逻辑。

## 路由接入点与分阶段顺序

1. 在 HomeView 的 `SwipeViewDestination` 新增专项浏览路由（`:10`），同步手写 equality/hash（`:24`、`:55`）与 `navigationDestination`（`:190`）。只将专项三个入口视频/截图/录屏（`:801`、`:810`、`:819`）切换到浏览器，保留原 `.category` 直接整理用途。
2. 先接通用 AssetQueryService/engine/resolver（含相册来源）、四组筛选和显式 review scope，验证当前结果到会话的范围和顺序。随后接共用卡片、容量服务、预览和库刷新；三类一起验证，而不是等录屏写死后再复制到截图。
3. AdvancedView 两个录屏分发点（`:453`、`:6444`）可复用同一个浏览器，并保留入口原有 supporter 授权。高级视频入口当前是 AdvancedAssetListView 多选清理（`:449`、`:6440`），首期保留该交互，不能为了共用外观直接改成“开始滑动整理”。免费首页专项不增加付费门槛。
4. 相册/高级页面只在提取共享组件时做兼容接线；不改变其默认筛选、密度、多选和批确认方式。

## 实施验证重点

- 单元测试：分类/用户相册/智能及虚拟相册 resolver、相册丢失/权限变化、自然日边界、闰年/时区、无日期、各场景默认值、reviewed policy、可靠/未知容量排序、稳定 tie-break、组间与组内顺序、全部结果统计与分页区分。
- 查询生命周期测试：两个页面的 query/取消互不干扰、快速切换拒绝旧结果、相册成员同数量替换、同 ID 内容编辑、共享容量读取去重及失效、错误后的重试。
- 会话测试：筛选范围和顺序无丢失；全局排序不覆盖显式范围；reviewed 更新不使队列收缩；撤销、候选、批确认、返回刷新；删除/权限变更剔除，新增不混入本轮；旧 source 行为回归。
- 模拟器：三个入口、sheet reset/下拉/Done、滚动、预览关闭、大小读取中开始整理、全部已整理/无素材/无结果、浅暗主题、小屏、大字号、英繁中；实际查看截图和完整操作录屏。
- 真机：大截图库的内存/进入速度、容量读取取消、真实录屏识别、iCloud、limited 权限、同 ID 编辑后缓存更新、批删除/收藏/后台恢复。模拟器不能代替这些验证。

本轮交付为技术方案；原型和原生实现完成度分开记录，尚无该新 SwiftUI 页的构建或真机验证结论。
