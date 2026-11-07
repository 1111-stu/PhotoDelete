# 付费页重做：订阅制 + 参考页 dark 移植

> 2026-10-09 立项，2026-11-07 更新为**月度 / 年度 / 买断三档**（原季度档已彻底移除）。
> 本文记录付费页的完整决策与实现锚点，以及把 UI 从琥珀暖黑语言换成参考页冷调 dark 的方案。

## 1. 决策

| 项 | 决定 |
| --- | --- |
| 付费模型 | 月度 + 年度 + 买断三档订阅制（旧文档「一次买断」作废） |
| 视觉基准 | 照搬 `../eisenhower-matrix-app` 的 paywall dark 配色，**不用** PhotoDelete 的琥珀体系 |
| 入口 | 沿用现状：设置页横幅 + 进阶页锁定底栏，都指向新的 `PaywallView` |
| 埋点 | 不引入。`SubscriptionManager` 原有 `AnalyticsService.*` 调用全部删除（AGENTS.md 禁止未批准的分析 SDK） |
| 试用 | 本机 3 天试用退役，改由 Apple 年度订阅的 7 天 intro offer 承担 |
| 兑换码 | 移除（对齐参考页；保留它会成为唯一的非订阅遗留入口） |

## 2. 商品

沿用两个已上线 ID（品牌规范：已上线内购 ID 不随意更换），用月度替换原季度档：

| 档位 | Product ID | 周期 | 价格 |
| --- | --- | --- | --- |
| 月度 | `com.01mvp.photodelete.pro.monthly` | P1M | 2.99 |
| 年度 | `com.01mvp.photodelete.pro.annual` | P1Y | 9.90，含 7 天免费试用（`P1W` × 1，`paymentMode: free`） |
| 买断 | `com.01mvp.photodelete.supporter.stats` | NonConsumable | 29.90 |

三档同处「OnePhoto Pro」订阅组（intro offer 资格按组判定，跨组不是 Apple 的语义）。

**App Store Connect 待办**（代码之外，上线前必须做）：
1. 在 OnePhoto Pro 组内创建月度订阅 `com.01mvp.photodelete.pro.monthly`，展示名与本地 `PhotoDelete.storekit` 一致。
2. 给年度订阅配置 7 天免费试用 introductory offer。
3. 月度定价已确认为 2.99；月度 × 12 = 35.88，年度 9.90 时 `SAVE` 徽章算出 72%。

## 3. 视觉 token 对照

付费页自己的 token 在 `ios-app/PhotoDelete/Views/Paywall/PaywallTheme.swift`（命名空间 `PaywallDS`），
**刻意不放进 `PhotoDeleteTheme`**，避免污染全局琥珀样式层。风格要点：

| 组 | dark 值 |
| --- | --- |
| 画布 | `#121722` + 24pt 点阵（白 5%，点径 2.4） |
| 强调色 | 樱粉 `#F0AAC8`（选中 radio 圆点 / 徽章底 / 功能勾选 / crown） |
| 套餐卡（未选中） | 纯黑填充 + 白 12% 发丝描边 |
| 套餐卡（选中） | `#1E222E` **不透明**提亮 + 3pt 粉→奶→薄荷渐变描边（`#F0AAC8` → `#EBCDBE` → `#8CD2BE`） |
| CTA | 反色白胶囊 + `#111111` 字 + 白 22% 描边 + 黑 18% 投影 |
| 底栏 | 22pt 圆角玻璃（iOS 26 `glassEffect(.regular, in: .rect)`；更低版本 `ultraThinMaterial` + 发丝边 + 投影） |
| 字体 | hero 用 Georgia 26 bold（衬线只留给 hero）；分区路标 14 rounded medium；价格 20 bold rounded |

两个容易踩的坑：
- **选中卡必须用不透明提亮色**。半透明白（如 white 0.05）会让点阵透上来，选中卡比未选中卡更"虚"，层级倒挂。
- **渐变中站必须走暖色区**。粉→薄荷直插会穿过低饱和灰区，过渡带发灰。

## 4. 结构

```
PaywallView（Views/Paywall/PaywallView.swift）
├── backdrop       画布 + 点阵 Canvas（allowsHitTesting(false)，否则滚动手势被点阵截断）
├── closeButton    iOS 26 用 .glass buttonStyle + .circle（挂 label 上会让 hit 区缩成 glyph）
├── hero           OnePhoto Pro + crown + 副标题
├── PaywallFeatureSection   5 项 Pro 权益，默认 3 项，可展开
├── PaywallPlanSection      单选套餐卡（radio + 徽章 + 价格 + 月均价 + 说明）
├── PaywallReviewPromptSection    评论引导（星标 + 去 App Store 写评论）
├── linksSection   恢复购买 ｜ 隐私政策 ｜ 使用条款
└── PaywallFooter  .safeAreaInset(edge: .bottom)，玻璃卡 + 56pt CTA + 试用副文案 + 信任行
```

状态派生全部在 `PaywallView` 里：`visiblePlans` 跟随 `availablePurchaseTypes`（月订用户只见年度升级档），
`shouldHidePurchaseUI` 对年度 / 买断用户隐藏全部购买入口与底栏，
`.task` 里**先 `checkSubscriptionStatus()` 再 `fetchProducts()`**（顺序反了会让已订阅用户闪一下试用 CTA）。

## 5. 与参考页的差异（有意为之）

| 参考页 | 本仓 | 原因 |
| --- | --- | --- |
| `PaywallReviewCarousel`（展示 6 条真实 App Store 评论） | **换成评论引导**（`PaywallReviewPromptSection`）：星标 + 「去 App Store 给个好评」，点按深链到 `action=write-review` | PhotoDelete 没有可引用的真实评论，**展示**编造的评价不诚实。改成**引导本人**去写评论，既真实又保留了这一格的转化作用。与设置页同款兜底：`itms-apps://` 打不开时退回商品页 |
| 免费 vs Pro 对比表（`SupporterPlanComparisonCard`） | **不进付费页**，只保留在进阶页的「功能差异」弹窗 | 付费页要的是「买不买」的决策路径；11 行对比表属于「Pro 到底有什么」的答疑，放在被质疑时打开的地方更合适 |
| `AnalyticsService.Source` 情境化 hero 副标题 | 单句固定副标题 | 埋点整体移除，不再需要 source 维度 |
| `fullScreenCover` 呈现 | `.sheet`（沿用现状） | iPhone 上 sheet 默认 large detent，观感一致；不改入口结构 |
| Notion / Apple EULA 硬编码链接 | `AppConstants.privacyPolicyURL` / `termsOfUseURL` | 沿用本仓既有链接 |
| `String(localized:)` / `LocalizedStringKey` | `L10n.string` + `String(format:)` | `String(localized:)` 不经过 `AppLanguage` 的 bundle 覆盖，会忽略 App 内语言选择器；`String(format:)` 同时绕开 `%` 的两层转义坑 |
| 两参数 `onChange(of:) { _, _ in }` | 单参数形式 | 本仓部署目标是 iOS 16 |
| 关闭按钮继承全页 tint | 付费页显式 `.tint(PaywallDS.Color.accent)` | App 全局 tint 是琥珀，不覆盖的话 iOS 26 玻璃关闭按钮会是琥珀色，破坏本页「只有樱粉 + 星标金」的配色约束 |
| 玻璃底栏直接浮在内容上 | 底栏背景叠一层画布色渐显遮罩（`bottomScrim`） | 底栏下方的安全区同样属于 ScrollView 可视区，不改的话滚动内容会从卡片下缘一路露到屏幕底部。**必须是灵活视图 + `ignoresSafeArea`**：先固定 `frame` 高度的话，`safeAreaInset` 内容就停在安全区边界，遮不住下面那条 |

## 6. 权益与缓存

`SubscriptionManager`（`Services/SubscriptionManager.swift`）是权益的唯一真相来源，
用 `Transaction.currentEntitlements` 解析后写回**既有的 supporter UserDefaults 键**：

- `supporterEntitlementKey` / `supporterProductIDKey` / `supporterPurchaseDateKey` / `supporterExpirationDateKey`
- 买断没有到期时间，会显式移除过期时间键，避免误判为已过期

这样 `SupporterCachedEntitlementPolicy`（`Services/SupporterEntitlementPolicy.swift`）与
`PhotoDeleteTheme.hasStoredThemeAccess` 不用改就能继续工作——离线解锁与主题门禁都建立在它之上。
`SupporterAccessKind` 新增了 `.monthly` 分支，否则缓存的月度权益会被静默判为无效。

判定优先级（`resolveCurrentEntitlement`）：只认 verified → 跳过撤销/退款 → 只认已声明的 SKU →
买断优先（在 `isUpgraded` / `expirationDate` 判定之前，所以非续订型买断不会被误判过期）→
否则取有效订阅里到期最晚的一个。已上线的买断用户因此继续解锁。

## 7. 测试

- `PhotoDeleteTests`：三档商品映射（含「商品 ID 只在 AppConstants 取一处」的防漂移断言）、
  `SubscriptionType.from(productID:)` 往返、升级规则、`.storekit` 配置（月度 P1M / 年度 P1Y + 7 天 free intro / 三档三语言）、
  缓存策略（含月度）、以及 `PaywallPricing` 的文案分支（试用 CTA 只在「年度 + 有资格」出现、缺产品时的降级、`%%` 转义）。
  `Product` 没有公开构造器，价格与节省百分比分支无法单测——那里靠模拟器人工验收。
- `PhotoDeleteUITests`：三档套餐卡（用 `paywall-plan-*` identifier）+ `paywall-unlock-cta` + legal link，
  以及已购态不出现购买入口。启动钩子从 `PHOTO_DELETE_UI_TEST_SUPPORTER_TRIAL_ACTIVE` 换成
  `PHOTO_DELETE_UI_TEST_SUPPORTER_UNLOCKED`。

## 8. 人工验收

本地 `PhotoDelete.storekit` 已挂在 scheme 的 Run → Options → StoreKit Configuration 上，
模拟器里可直接跑真实购买流程。要核对的点：点阵是纹理而非灰雾、选中卡比未选中卡更亮、
渐变描边没穿过发灰区、反色白 CTA 与玻璃底栏的对比度、三档价格与月均价随选中切换、
年度的「试用 7 天」与「试用期内可随时取消 · 之后 ¥9.90 / 年 · 自动续订」、
购买成功后 sheet 关闭且设置页主题选择器可用（证明 UserDefaults 键写对了）。
