import SwiftUI

struct CleanupAssetFilterSheet: View {
    @Binding var query: AssetQuery
    let defaultQuery: AssetQuery
    var summary: AssetQuerySummary? = nil
    var showsContentFilter = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetent: PresentationDetent = .fraction(0.75)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: PhotoDeleteStyle.sectionSpacing) {
                        if let summary {
                            Text(String(format: L10n.string("%lld items"), Int64(summary.count)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("cleanup-filter-result-count")
                        }

                        if showsContentFilter {
                            optionSection(
                                title: L10n.string("Content"),
                                options: AssetContentFilter.allCases,
                                selection: $query.content,
                                columns: columns(for: geometry.size.width),
                                label: contentTitle
                            )
                        }

                        optionSection(
                            title: L10n.string("Taken before"),
                            options: AssetAgeFilter.allCases,
                            selection: $query.age,
                            columns: columns(for: geometry.size.width),
                            label: ageTitle
                        )

                        optionSection(
                            title: L10n.string("Review status"),
                            options: AssetReviewFilter.allCases,
                            selection: $query.reviewStatus,
                            columns: columns(for: geometry.size.width),
                            label: reviewTitle
                        )

                        optionSection(
                            title: L10n.string("Group by time"),
                            options: AssetTimeGrouping.allCases,
                            selection: $query.grouping,
                            columns: columns(for: geometry.size.width),
                            label: groupingTitle
                        )

                        optionSection(
                            title: L10n.string("Sort"),
                            options: AssetSort.allCases,
                            selection: $query.sort,
                            columns: columns(for: geometry.size.width),
                            label: sortTitle
                        )
                    }
                    .padding(PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.bottom, 12)
                }
            }
            .background(PhotoDeleteScreenBackground())
            .navigationTitle(L10n.string("Filter and sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("Reset")) {
                        query = defaultQuery
                    }
                    .disabled(query == defaultQuery)
                    .accessibilityIdentifier("cleanup-filter-reset")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("cleanup-filter-done")
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            if dynamicTypeSize.isAccessibilitySize {
                selectedDetent = .large
            }
        }
        .onChange(of: dynamicTypeSize) { size in
            if size.isAccessibilitySize {
                selectedDetent = .large
            }
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : (width < 360 ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private func optionSection<Value: Identifiable & Equatable>(
        title: String,
        options: [Value],
        selection: Binding<Value>,
        columns: [GridItem],
        label: @escaping (Value) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue == option
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 18)
                            .foregroundStyle(.primary)
                            .background(
                                isSelected ? PhotoDeleteStyle.elevatedSurface : PhotoDeleteStyle.surface,
                                in: RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                    .stroke(
                                        isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.cardStroke,
                                        lineWidth: isSelected ? 1.5 : PhotoDeleteStyle.Metrics.cardStrokeWidth
                                    )
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(PhotoDeleteStyle.accent)
                                        .padding(7)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("cleanup-filter-option-\(String(describing: Value.self))-\(option.id)")
                }
            }
        }
    }

    private func contentTitle(_ value: AssetContentFilter) -> String {
        switch value {
        case .all: return L10n.string("All")
        case .photos: return L10n.string("Photos")
        case .videos: return L10n.string("Videos")
        case .favorites: return L10n.string("Favorites")
        }
    }

    private func ageTitle(_ value: AssetAgeFilter) -> String {
        switch value {
        case .all: return L10n.string("All")
        case .olderThan15Days: return L10n.string("Older than 15 days")
        case .olderThan30Days: return L10n.string("Older than 30 days")
        case .olderThan180Days: return L10n.string("Older than 180 days")
        case .olderThanOneYear: return L10n.string("Older than 1 year")
        }
    }

    private func reviewTitle(_ value: AssetReviewFilter) -> String {
        switch value {
        case .all: return L10n.string("All")
        case .pending: return L10n.string("To review")
        case .reviewed: return L10n.string("Reviewed")
        }
    }

    private func groupingTitle(_ value: AssetTimeGrouping) -> String {
        switch value {
        case .none: return L10n.string("None")
        case .day: return L10n.string("By Day")
        case .month: return L10n.string("By Month")
        }
    }

    private func sortTitle(_ value: AssetSort) -> String {
        switch value {
        case .largestFirst: return L10n.string("Largest first")
        case .newestFirst: return L10n.string("Newest")
        case .oldestFirst: return L10n.string("Oldest")
        }
    }
}
