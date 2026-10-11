import SwiftUI

struct CleanupAssetFilterSheet: View {
    @Binding var query: AssetQuery
    let defaultQuery: AssetQuery
    var summary: AssetQuerySummary? = nil
    var showsContentFilter = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetent: PresentationDetent = .fraction(0.85)
    @State private var pane: FilterSheetPane = .filter

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                FilterSheetPanePicker(selection: $pane)
                    .padding(.horizontal, Theme.space5)
                    .padding(.top, 8)

                if let summary {
                    Text(String(format: L10n.string("%lld items"), Int64(summary.count)))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.space5)
                        .accessibilityIdentifier("cleanup-filter-result-count")
                }

                ScrollView {
                    Group {
                        switch pane {
                        case .filter:
                            filterPane
                        case .sort:
                            sortPane
                        case .display:
                            displayPane
                        }
                    }
                    .padding(.horizontal, Theme.space5)
                    .padding(.bottom, 20)
                    .animation(.easeInOut(duration: 0.18), value: pane)
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
                    .foregroundStyle(
                        query == defaultQuery
                            ? Theme.tertiaryText
                            : Theme.secondaryText
                    )
                    .accessibilityIdentifier("cleanup-filter-reset")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("cleanup-filter-done")
                }
            }
        }
        .presentationDetents([.fraction(0.85), .large], selection: $selectedDetent)
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

    private var filterPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsContentFilter {
                FilterSheetSection(title: L10n.string("Content")) {
                    FilterGlassSegmentedControl(
                        options: AssetContentFilter.allCases.map {
                            FilterSegmentOption(value: $0, title: contentTitle($0))
                        },
                        selection: $query.content
                    )
                }
            }

            FilterSheetSection(title: L10n.string("Review status")) {
                FilterGlassSegmentedControl(
                    options: AssetReviewFilter.allCases.map {
                        FilterSegmentOption(value: $0, title: reviewTitle($0))
                    },
                    selection: $query.reviewStatus
                )
            }

            FilterSheetSection(title: L10n.string("Taken before")) {
                FilterGlassChoiceGrid(
                    options: AssetAgeFilter.allCases.map {
                        FilterSegmentOption(value: $0, title: ageTitle($0))
                    },
                    selection: $query.age,
                    columns: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                )
            }
        }
    }

    private var displayPane: some View {
        FilterSheetSection(title: L10n.string("Group by time")) {
            FilterGlassSegmentedControl(
                options: AssetTimeGrouping.allCases.map {
                    FilterSegmentOption(value: $0, title: groupingTitle($0))
                },
                selection: $query.grouping
            )
        }
    }

    private var sortPane: some View {
        FilterSheetSection(title: L10n.string("Sort")) {
            FilterGlassSegmentedControl(
                options: AssetSort.allCases.map {
                    FilterSegmentOption(value: $0, title: sortTitle($0))
                },
                selection: $query.sort
            )
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
