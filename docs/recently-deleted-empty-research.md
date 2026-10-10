# 首页垃圾桶 → 清空「最近删除」：调研与方案 v1

调研日期：2026-10-11。依据当前 `ios-app/` 工作区、Apple PhotoKit 公开 API、竞品公开说明与社区实践。本阶段产出调研与方案，未修改原生 App。

## 结论

产品方向正确：**退出整理页已强制 `BatchConfirmView` 确认删除**，首页垃圾桶不应再承担「候选队列二次确认」，而应 closure「真正腾空间」——引导用户清空系统「最近删除」。

但有一条硬约束：**第三方 App 无法用公开 PhotoKit API 在应用内永久清空「最近删除」**。`PHAssetChangeRequest.deleteAssets` 只会把资源移入该相册；公开枚举里也没有 `smartAlbumRecentlyDeleted`。能永久删除的只有系统照片 App（需 Face ID / 密码 + 系统确认）。

因此首页入口的可行形态是 **「引导清空」而不是「App 内一键永久抹掉」**。诚实的竞品（Gemini Photos、Phone Diet 等）也是这条路：删完提醒用户去照片 App 清空，而不是声称自己替系统倒掉垃圾桶。

## 现状与产品缺口

| 环节 | 现状 | 问题 |
| --- | --- | --- |
| 整理中上滑 | 写入本地 `deleteCandidates` | 会话内暂存，合理 |
| 退出整理 | `SwipePhotoView.handleBackAction` / `handleFinishAction` → `BatchConfirmView` | 主路径已确认删除 |
| 确认删除 | `PhotoLibraryManager.commitBatchChanges` → `PHAssetChangeRequest.deleteAssets` | 进入系统「最近删除」，空间未立刻释放 |
| 完成页文案 | `BatchReviewViews` 已提示「进最近删除后空间不一定立刻释放」 | 有认知，缺下一步行动 |
| 首页垃圾桶 | `TrashBinView` → 再展示 `deleteCandidates` | 主路径确认后队列通常已空；职责重复，且不解决腾空间 |

主路径下首页角标（`deleteCandidates.count`）经常为 0，入口名存实亡；用户真正卡住的是「删了但存储没掉」。

## 平台能力边界

### 公开 API 能做什么

| 能力 | 结果 |
| --- | --- |
| `deleteAssets` | 仅移入「最近删除」 |
| 公开 `PHAssetCollectionSubtype` | **无** Recently Deleted（SDK `PhotosTypes.h` 到 `smartAlbumScreenRecordings = 220` 为止） |
| 系统删除确认 Alert | 无法压制，由系统弹出 |
| 永久清空 | **只能**在系统照片 App 完成 |

### 非公开 / 高风险手段（不建议上架依赖）

| 手段 | 说明 | 风险 |
| --- | --- | --- |
| 私有 subtype `1000000201` | 历史上可 fetch「最近删除」集合 | 非公开常量，可能失效；审核与兼容风险 |
| 私有 `expungeAssets:` | 社区 gist 用于「真正抹掉」 | 明确私有 API，易触发 2.5.1 拒审 |
| `photos-navigation://album?name=recently-deleted` | 可跳到该相册（逆向结论） | 未文档化 URL scheme；同类 `prefs:root=` 曾被拒 |

**结论：上架方案不得依赖私有清空 API。** 跳转深度链接若要用，只能当增强实验，并准备纯引导降级。

### 只读探测（可选，仍脆）

- 遍历 smart albums，用 `localizedTitle` 匹配「最近删除 / Recently Deleted」等——多语言脆弱。
- 即使用私有 subtype 读到数量，对其中 asset 再调 `deleteAssets` 通常仍无法永久删除（trash 内资源不可再删）。

## 竞品怎么做

| 类型 | 典型做法 | 是否真清空系统垃圾桶 |
| --- | --- | --- |
| Gemini Photos | 删除进 Recently Deleted；FAQ 教用户去照片 App 恢复/等待 30 天 | 否 |
| Phone Diet / CleanupMyPhone | 明确写「第三方不能 empty Apple 的 Recently Deleted」；清理后提醒去照片 App | 否 |
| 部分「一键清垃圾桶」营销 | 多为 App 自建回收站，或跳转/教程；系统相册仍要用户自己倒 | 实质上否 |

「竞品首页有垃圾桶」≠「App 内永久清空」。多数是 **心智对齐 + 引导闭环**，不是突破 Apple 沙箱。

## 推荐方案（上架安全）

### 一句话

把首页垃圾桶从「待删除候选队列」改成 **「清空最近删除」引导入口**；删除成功页补强 CTA；整理页内的会话队列预览可保留。

### 信息架构

```
整理会话
  └─ 上滑 → 本地候选（会话内可纠错）
  └─ 退出 / 完成 → BatchConfirm（已有）
        └─ 成功 → 进系统最近删除
              └─ 完成页 CTA：「去清空垃圾桶，立刻腾出约 X」
首页垃圾桶
  └─ 引导页：说明 + 步骤 +（可选）打开照片 App
  └─ 角标：表达「还有空间锁在最近删除」
```

### 首页入口行为（建议）

点垃圾桶 → 打开 **引导 Sheet / 全屏页**，而不是 `TrashBinView` 候选列表：

1. **标题**：清空最近删除 / Empty Recently Deleted  
2. **价值句**：照片已在系统垃圾桶里，清空后空间才会回来（约 X · N 项）  
3. **步骤**（适配 iOS 18 / 26 文案）：照片 → Collections / Albums → Utilities → Recently Deleted → 解锁 → Select → Delete All  
4. **主按钮**：打开照片 App（优先公开可用的打开方式；深度链到 recently-deleted 仅作可选增强）  
5. **次按钮**：我知道了 / 稍后再说  
6. **空状态**：最近删除侧无可回收估计时，弱化入口或提示「整理后这里会出现可腾空间」

### 角标数据从哪来（三选一，按风险递增）

| 方案 | 做法 | 优点 | 缺点 |
| --- | --- | --- | --- |
| **A. 自有删除账本（推荐默认）** | 用 `CleanupStatsStore` / 会话记录，累计近 30 天本 App 已确认删除的数量与估算体积；用户点「已清空」或超时衰减 | 零私有 API；与产品叙事一致 | 若用户在系统照片里另有删除，或已手动清空，角标会偏高/偏低 |
| **B. 本地「待腾空间」标记** | 每次 `executeBatchOperations` 成功后写入 `pendingReclaimCount/MB`；引导页提供「我已清空」清零；App 回前台可提示核对 | 实现简单，主路径准 | 依赖用户诚实点「已清空」 |
| **C. 只读探测系统相册** | 私有 subtype 或标题匹配读 count | 角标更接近真实 | 审核/多语言/权限（iOS 16+ 需解锁）风险高 |

**建议先做 B，角标展示数量或「约 X MB」；完成页与首页共用同一套 pending reclaim 状态。**

### 完成页衔接（高杠杆）

`BatchCleanupCompletionView` 已有空间文案，应把主行动从「继续整理 / 看成就」扩展为：

- 主 CTA：**去清空最近删除**（进与首页同一引导）  
- 次 CTA：继续整理  

这比只改首页图标更能提升「腾空间闭环」完成率。

### 整理页内能力保留

| 入口 | 去留 |
| --- | --- |
| 整理页内查看待删除（`PendingDeletionView`） | **保留**——会话中纠错 |
| 首页 `TrashBinView` 候选队列 | **替换**为引导清空 |
| `SwipeViewDestination.trashBin` | 改为引导目的地，或新建 `emptyRecentlyDeleted` |

## 明确不做

1. 调用私有 `expungeAssets:` 或任何「绕过 Recently Deleted」删除。  
2. 向用户承诺「一点即永久删除且立刻释放」却实际打不开系统相册。  
3. 把首页垃圾桶继续做成第二遍 `BatchConfirm`（与退出确认重复）。

## 实现切片（供后续开工）

1. **状态**：`pendingReclaim`（count + estimated MB + updatedAt），在 `executeBatchOperations` 成功路径写入。  
2. **UI**：`EmptyRecentlyDeletedGuideView`（步骤 + CTA）；替换首页 `trashBinEntryButton` 目标。  
3. **完成页**：主按钮接同一 Guide。  
4. **角标**：改绑 `pendingReclaim`，空则隐藏。  
5. **文案 / 本地化**：步骤需覆盖 iOS 18 Albums 与 iOS 26 Collections 差异。  
6. **可选实验**：`photos-navigation://album?name=recently-deleted`，失败则 `open` 照片 App 根或仅展示步骤；不进默认上架路径直到验证审核风险。  
7. **测试**：确认删除后角标上升；点「我已清空」清零；无 pending 时入口弱化；Limited Photos 权限下文案不崩溃。

## 成功指标（建议）

- 删除确认后 24h 内，引导页打开率  
- 引导后用户手动标记「已清空」率（或存储相关好评提及）  
- 首页垃圾桶误点进空候选队列的投诉下降  
- 不出现因私有 API 导致的审核驳回

## 决策清单

| # | 问题 | 状态 |
| --- | --- | --- |
| 1 | 角标用方案 B（自有 pending reclaim） | **已定**：可接受与系统真实数量不完全一致 |
| 2 | 打开照片 App：根入口 vs undocumented deep link | **未定** |
| 3 | 完成页主 CTA 接「去清空最近删除」 | **已定：本阶段不做**；后续再单独看完成页怎么接 |

### 本阶段实现范围

- 做：首页垃圾桶 → 引导清空；角标绑自有 `pendingReclaim`；确认删除成功时写入账本  
- 不做：`BatchCleanupCompletionView` 不改主 CTA、不链到引导页  
- 暂缓：深度链接进「最近删除」相册；当前仅 `photos-navigation://` / `photos://` 打开照片 App 根入口

### 落地状态（2026-10-11）

| 项 | 位置 |
| --- | --- |
| 账本 | `Services/PendingReclaimStore.swift` + `DataManager.pendingReclaim` |
| 写入 | `executeBatchOperations` 删除成功路径 |
| 引导页 | `Views/EmptyRecentlyDeletedGuideView.swift` |
| 首页入口 | `HomeView` `trashBin` → 引导页；角标绑 `pendingReclaim.itemCount` |
| 完成页 | 未改 |
