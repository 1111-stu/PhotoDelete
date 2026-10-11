//
//  FilterSheetControls.swift
//  PhotoDelete
//
//  筛选与排序弹窗共用控件：顶栏三 Tab + 轨道滑动玻璃分段 + 紧凑单选格。
//  选中态用白高光 / 玻璃滑块；琥珀只留给「完成」。
//  轨道与滑块统一用方形圆角（非胶囊），更接近分段控件的原生块面感。
//

import SwiftUI

private enum FilterSheetChrome {
    /// 外轨道圆角
    static let trackRadius: CGFloat = 14
    /// 内滑块圆角（略小于轨道，给 3pt 内边留呼吸）
    static let thumbRadius: CGFloat = 11
}

// MARK: - Pane

enum FilterSheetPane: String, CaseIterable, Identifiable {
    case filter
    case sort
    case display

    var id: String { rawValue }

    var title: String {
        switch self {
        case .filter: return L10n.string("Filter")
        case .sort: return L10n.string("Sort")
        case .display: return L10n.string("Display")
        }
    }
}

// MARK: - Segment option

struct FilterSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var subtitle: String? = nil

    var id: Value { value }
}

// MARK: - Top pane tabs

struct FilterSheetPanePicker: View {
    @Binding var selection: FilterSheetPane
    @Namespace private var thumbNamespace

    var body: some View {
        FilterGlassSegmentTrack(
            options: FilterSheetPane.allCases.map {
                FilterSegmentOption(value: $0, title: $0.title)
            },
            selection: $selection,
            namespace: thumbNamespace,
            minHeight: 40,
            showsSubtitle: false
        )
    }
}

// MARK: - Sliding glass segment (2–4 options)

struct FilterGlassSegmentedControl<Value: Hashable>: View {
    let options: [FilterSegmentOption<Value>]
    @Binding var selection: Value
    @Namespace private var thumbNamespace

    var body: some View {
        FilterGlassSegmentTrack(
            options: options,
            selection: $selection,
            namespace: thumbNamespace,
            minHeight: options.contains(where: { $0.subtitle != nil }) ? 52 : 40,
            showsSubtitle: true
        )
    }
}

private struct FilterGlassSegmentTrack<Value: Hashable>: View {
    let options: [FilterSegmentOption<Value>]
    @Binding var selection: Value
    let namespace: Namespace.ID
    let minHeight: CGFloat
    let showsSubtitle: Bool

    private var trackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FilterSheetChrome.trackRadius, style: .continuous)
    }

    private var thumbShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FilterSheetChrome.thumbRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    HapticManager.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selection = option.value
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        if showsSubtitle, let subtitle = option.subtitle {
                            Text(subtitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(
                                    isSelected
                                        ? PhotoDeleteStyle.primaryText.opacity(0.72)
                                        : PhotoDeleteStyle.tertiaryText
                                )
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(isSelected ? PhotoDeleteStyle.primaryText : PhotoDeleteStyle.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: minHeight)
                    .contentShape(thumbShape)
                    .background {
                        if isSelected {
                            FilterGlassThumb(shape: thumbShape)
                                .matchedGeometryEffect(id: "filter-glass-thumb", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background {
            trackShape
                .fill(Color.white.opacity(0.06))
                .overlay {
                    trackShape
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Compact choice grid (>4 options)

struct FilterGlassChoiceGrid<Value: Hashable>: View {
    let options: [FilterSegmentOption<Value>]
    @Binding var selection: Value
    var columns = 2
    /// 与顶栏 Tab / 整理状态分段同高，避免选项格过高打破平衡。
    var rowHeight: CGFloat = 40

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 8),
                count: columns
            ),
            spacing: 8
        ) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    HapticManager.impact(.light)
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(
                            isSelected
                                ? PhotoDeleteStyle.primaryText
                                : PhotoDeleteStyle.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .padding(.horizontal, 10)
                        .background {
                            RoundedRectangle(cornerRadius: FilterSheetChrome.thumbRadius, style: .continuous)
                                .fill(Color.white.opacity(isSelected ? 0.10 : 0.045))
                                .overlay {
                                    RoundedRectangle(cornerRadius: FilterSheetChrome.thumbRadius, style: .continuous)
                                        .stroke(
                                            Color.white.opacity(isSelected ? 0.34 : 0.08),
                                            lineWidth: isSelected ? 1 : 0.5
                                        )
                                }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Section chrome

struct FilterSheetSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            content()
        }
    }
}

// MARK: - Glass thumb

private struct FilterGlassThumb: View {
    let shape: RoundedRectangle

    var body: some View {
        if #available(iOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(Color.white.opacity(0.10))
                }
                .overlay {
                    shape.stroke(Color.white.opacity(0.26), lineWidth: 0.8)
                }
        }
    }
}
