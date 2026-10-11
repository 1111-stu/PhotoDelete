# 实况照片专项：接入调研与技术方案 v1

调研日期：2026-10-09。依据当前 `ios-app/` 工作区（包含现有暂存改动）与 `docs/special-cleanup-swiftui-integration.md` 已落地的通用专项架构。本阶段产出调研与技术方案，未修改原生 App。

## 结论

实况照片是现有专项清理架构里**最后一个没接的类别**，且底层几乎全部就绪：分类枚举、来源解析、子类型判定、分类集合、取数、浏览器页面、卡片、整理会话、localized 文案与 `livephoto` SF Symbol 都已存在，新增工作量远小于录屏或截图专项。

但存在一个**必须先修的正确性问题**：容量估算走 `mediaType == .image` 分支，只读取静图数据，实况照片配对的动作视频分量完全没被计入。对以"释放空间"为核心承诺的 App，该偏差会顺着 `AssetQueryEngine` 扩散成三处错误——卡片数字、`largestFirst` 默认排序、首页可清理合计。而且项目内部当前存在**三个互相不一致的容量算法**。

排除该问题后，剩余工作是在 `HomeView` 加一个入口、补卡片辨识度、补空状态分支，以及把 `ReviewPhotoCard` 已有的实况播放链路提取为可复用预览。删除语义上有一项需要产品决策。

## 已经就绪的部分

以下行号对应本轮工作区。

| 能力 | 位置 | 说明 |
| --- | --- | --- |
| 分类枚举 | `Models/AssetQueryModels.swift:5`、`:9` | `AssetCategoryID.livePhotos` 与 `AssetVirtualAlbumID.livePhotos` 均已存在 |
| 分类映射 | `Services/AssetQuery/AssetSourceResolver.swift:74`、`:86` | 已映射到 `PhotoCategory.livePhotos` / `AlbumType.livePhotos` |
| 子类型判定 | `Services/PhotoLibraryManager.swift:58`、`:1335` | `mediaType == .image && mediaSubtypes.contains(.photoLive)` |
| 分类集合填充 | `PhotoLibraryManager.swift:1313` | `appendAssetClassification` 已填充 `livePhotos` |
| 增量与快照 | `PhotoLibraryManager.swift:1075`、`:2093`、`:3107` | 刷新签名、删除剔除、增量 upsert 均已覆盖 `livePhotos` |
| 取数 | `Services/DataManager.swift:1471` | `getRealPhotos(for: .livePhotos)` 已通 |
| 页面与卡片 | `Views/CleanupAssetBrowserView.swift:216` | 已映射 `photoCategory`，标题与状态徽标可用 |
| 文案与图标 | `Models/Models.swift:19`、`:41`、`:301` | 标题「实况照片 / Live Photos」与 `livephoto` SF Symbol 已存在 |
| 随机浏览类别 | `Models/ReviewDiscoveryModels.swift:70`、`:85`、`:102`、`:119` | 已有 title / subtitle / icon，可作文案与图标来源 |

集合判定与录屏一致，走 **`mediaSubtypes` 系统子类型**而非 `.smartAlbumLivePhotos` 智能相册，方向正确：不依赖相册成员关系，天然跟随 Photos 增量更新。

需留意一处机制不一致：**变更检测的签名仍取自智能相册**——`PhotoLibraryManager.swift:1075` 的刷新签名使用 `fetchSmartAlbumAssets(.smartAlbumLivePhotos)`，而集合本身由子类型填充。两者在常规情况下同步（动作分量被剥离时智能相册成员与子类型同时变化，签名随之改变并触发重新分类），目前未见具体故障；但签名来源与集合来源不是同一机制，后续若出现实况照片集合未随库变化刷新的问题，应优先排查此处。此机制不一致非实况照片独有，不属本次接入的阻塞项。

## 必须补齐的逻辑

### 1. 容量估算错误（最高优先级，必须先修）

`Services/AssetQuery/AssetSizeLoader.swift:82-88` 按 `asset.mediaType` 路由容量任务。实况照片的 `mediaType == .image`，因此走 `photoFileSizeEstimate`，而该方法（`PhotoLibraryManager.swift:1999`）通过 `requestImageDataAndOrientation`（`:2013`）读取数据。该接口对实况照片返回的是**静图分量**（HEIC/JPEG），配对的动作视频不包含在内。

错误会顺着 `Services/AssetQuery/AssetQueryEngine.swift` 扩散：

1. `:109-113` 卡片显示的容量偏低。
2. `:131` `largestFirst` 默认排序依据错误——**默认排序下最大的实况照片排不上来**。
3. `:110` 首页「约 X 可清理」合计偏低。

同时项目内部当前有三个互相不一致的算法，对同一张实况照片会给出三个不同数字：

| 位置 | 算法 | 实况照片结果 |
| --- | --- | --- |
| `AssetSizeLoader` → `PhotoLibraryManager.swift:1999` | `requestImageDataAndOrientation` 读静图字节 | 只有静图分量 |
| `Views/Components/ReviewPhotoCard.swift:18-21` | KVC `value(forKey: "fileSize")` 取 `.max()` | 只取较大的单个分量 |
| `Views/PhotoDetailSheet.swift:65-70` | KVC `value(forKey: "fileSize")` 取 `.max()` | 同上 |

后两处对实况照片使用 `.max()` 本身就是错的——静图与动作视频是两个独立分量，应当**求和**。

**方案**：抽出单个纯函数（建议 `PhotoLibraryManager` 内，形如 `livePhotoFileSizeEstimate(for:)`），对 `PHAssetResource.assetResources(for:)` 中 `.photo`（或 `.fullSizePhoto`）与 `.pairedVideo` 的容量求和，三条路径统一调用，消除三份实现。求和实现二选一：

- **方案 A（已采纳）**：复用 `PHAssetResourceManager.requestData` 流式字节计数，对两个资源各读一遍求和。正确、无私有 API 风险，符合 `AssetSizeLoader` 顶部注释「不并行保留多份完整 Data」的约束。代价是实况库较大时首次进入需全量读一遍本地数据。
- **方案 B（已否决）**：KVC `fileSize` 求和。属于私有 API，审核拒审风险过高，项目内相关调用已移除，不得再引入。

缓存键 `AssetSizeLoader.swift:10-14` 为 `(managerID, assetID, modificationDate)`，求和结果可直接沿用，无需改动缓存结构。`AssetQuerySizeState` 的 `.knownMB` / `.iCloud` / `.unavailable` 语义不变。

⚠️ 「`requestImageDataAndOrientation` 对实况照片只返回静图」需在**真机**确认一次再动手，模拟器不足以验证容量路径（遵循仓库既有的真机验证要求）。确认方式：对同一张实况照片分别打印 `requestImageDataAndOrientation` 的 `data.count` 与 `.photo` + `.pairedVideo` 的 KVC `fileSize` 之和，比较两者差异。

### 2. 首页没有入口

`Views/HomeView.swift:794-830` 的 `specialCleanupSection` 当前四行：相似、视频、截图、录屏。新增第五行 `cleanupRow(icon: "livephoto", ...)` 并 `navigationPath.append(SwipeViewDestination.assetBrowser(.livePhotos))` 即可，属纯增量，不影响既有入口。

首页合计 `cleanupReclaimableSizeText`（`HomeView.swift:982-987`）基于 `AdvancedCleanupKind`，当前只含相似、视频、录屏，**实况照片不在其中**。是否纳入是产品决定，见下节。注意该合计按现有注释本身尚未补齐视频/截图。

### 3. 空状态分支缺失

`Views/CleanupAssetBrowserView.swift:167` 的图标为 `category == .screenshots ? "photo" : "video"`，`.livePhotos` 会落到 else 分支显示**视频图标**；`:221-227` 的 `emptyTitle` 对 `.livePhotos` 落到 `default` 返回 **"No videos"**。两处都需要补 `.livePhotos` 分支（图标用已有的 `livephoto` Symbol，文案「没有实况照片」）。

### 4. 卡片缺实况角标

`CleanupAssetCard`（`Views/CleanupAssetBrowserView.swift:244-257`）只在 `mediaType == .video` 时叠加播放图标与时长。实况照片在网格里与普通照片**完全无法区分**。

建议在封面左上角或底部补 `livephoto` 角标，复用卡片内已有的 overlay 写法（`.black.opacity(0.65)` + `RoundedRectangle(cornerRadius: 5)` + `.padding(5)`），与"已整理 / 待删除"徽标的视觉层级保持一致；左上角已被状态徽标占用，需与 `.reviewed` / `isPendingDeletion` 叠加时排布不冲突。具体取值遵循 `style.md` 与现有 token，不新造样式。

### 5. 筛选分区需按来源裁剪

- `content == .photos` **已正确包含**实况照片：`AssetQueryService.swift:187` 将 `mediaType == .image` 归为 `.photo`，`AssetQueryEngine.swift:42` 按 `mediaType == .photo` 过滤。无需改动。
- 但 `content == .videos` 在实况源下**必然为空**。`CleanupAssetFilterSheet` 会展示一个永远选不出结果的选项。建议按来源裁剪可用分区，与 `special-cleanup-swiftui-integration.md` 中「可用分区由页面配置指定」的设计意图一致。

### 6. 只读预览不播动作

`Views/Components/AssetReadOnlyPreviewView.swift:20-31` 只有视频播放器和静图两个分支，实况照片在预览里退化为静图。

播放链路已存在，无需重写：`Views/Components/ReviewPhotoCard.swift:106-116` 有 `PHLivePhoto` + `LivePhotoPreviewRepresentable`，并带 `AppConstants.reviewLivePhotoAutoPlayKey` 自动播放偏好（`Models/Models.swift:145-147`）。需做的是把该链路提取为可复用的只读预览组件，供专项预览与 ReviewPhotoCard 共用。

## 需要产品决策

**删除语义**：`PHAssetChangeRequest.deleteAssets`（`Services/PhotoLibraryManager.swift:1405-1407`）删除一张实况照片会**同时删除静图与动作分量**。这是系统行为，也符合"清理"预期。

但用户真实的常见诉求是「**只删动作、保留静图**」（iOS 自带相册的「复制为静止照片」）。该操作需要新建一个纯静图资产再删除原资产，不是简单删除，且会改变候选库与批确认的既有语义。**建议首期不做**，但必须在文案上把"删除的是整张实况照片（含动作）"说清楚，否则是明确的用户投诉点。

另需决定：实况照片是否计入首页 `cleanupReclaimableSizeText` 合计。

## 测试策略的硬约束

`Services/PhotoLibraryManager.swift:64-65` 已注释说明：`PHAssetChangeRequest` **无法设置 `mediaSubtypes`**，因此录屏只能靠测试进程按原始文件名补判（`isUITestScreenRecording`）。实况照片**连这个补丁都没有**——UI 测试种子库（`Services/UITestPhotoLibrarySeeder.swift`）造不出实况照片。

因此：

- **检测逻辑**必须靠纯函数单测。`PhotoLibraryAssetClassification`（`PhotoLibraryManager.swift:40`）已可注入 `mediaType` / `mediaSubtypes`，直接可测，无需真实图库。
- **容量的求和逻辑**应抽成纯函数单测，不绑定真机 IO；测试用例需覆盖「静图 + 动作」求和、仅有静图、仅有动作、以及 `.pairedVideo` 缺失时的降级。
- UI 测试无法覆盖实况网格与预览，这部分依赖模拟器/真机手工验证并在记录中说明。

## 建议落地顺序

1. **修容量**：抽纯函数 + 三处收敛（`AssetSizeLoader`、`ReviewPhotoCard`、`PhotoDetailSheet`）。先做，因为它同时修正排序与首页合计。
2. **首页加入口** + 补空状态分支：最小增量，可立即验收。
3. **卡片角标** + 筛选分区裁剪：补完辨识度与条件可用性。
4. **预览动作播放**：提取 `ReviewPhotoCard` 已有链路。

前两步完成即为可用的实况照片清理；第 4 步是体验完善，可独立排期。

## 实施验证重点

- **单元测试**：`PhotoLibraryAssetClassification` 对 `.photoLive` 的判定；求和函数的分量组合与降级；`AssetQueryEngine` 在实况源下 `content` / `age` / `reviewStatus` 过滤与 `largestFirst` 排序；`AssetSizeLoader` 缓存命中与 `modificationDate` 失效。
- **真机**：容量求和与 `requestImageDataAndOrientation` 的对比实验；大实况库进入速度与读取取消；iCloud 实况照片保持未知而非 0；有限权限；同 ID 编辑后缓存失效。
- **模拟器**：首页新入口、空状态图标与文案、卡片角标与"已整理"徽标叠加、预览动作播放、筛选 sheet 分区裁剪、浅暗主题、小屏、大字号、英繁中。
- **交互回归**：开始整理冻结当前 `pendingIDs` 与顺序；实况照片经既有滑动手势整理、撤销、批确认流程无误。

本阶段交付为技术方案；原型和原生实现完成度分开记录，尚无该新入口的构建或真机验证结论。
