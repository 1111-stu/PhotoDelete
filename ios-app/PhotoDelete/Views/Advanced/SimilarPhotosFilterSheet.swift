import SwiftUI

// MARK: - Filter query

enum SimilarPhotosScopeFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case burst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.string("All similar groups")
        case .burst: return L10n.string("Bursts")
        }
    }
}

enum SimilarPhotosTimeFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case last30Days
    case lastYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.string("Any time")
        case .last30Days: return L10n.string("Last 30 days")
        case .lastYear: return L10n.string("Last year")
        }
    }

    /// Inclusive lookback window from now; `nil` means unlimited.
    var lookbackInterval: TimeInterval? {
        switch self {
        case .all: return nil
        case .last30Days: return 30 * 24 * 60 * 60
        case .lastYear: return 365 * 24 * 60 * 60
        }
    }
}

enum SimilarPhotosMatchTightness: String, CaseIterable, Hashable, Identifiable {
    case stricter
    case standard
    case looser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stricter: return L10n.string("Stricter")
        case .standard: return L10n.string("Default")
        case .looser: return L10n.string("Looser")
        }
    }

    var matchProfile: SimilarPhotoMatchProfile {
        switch self {
        case .stricter: return .stricter
        case .standard: return .standard
        case .looser: return .looser
        }
    }
}

struct SimilarPhotosFilterQuery: Equatable {
    var scope: SimilarPhotosScopeFilter = .all
    var time: SimilarPhotosTimeFilter = .all
    var match: SimilarPhotosMatchTightness = .standard

    static let `default` = SimilarPhotosFilterQuery()

    var isDefault: Bool { self == .default }
}

// MARK: - Sheet

struct SimilarPhotosFilterSheet: View {
    @Binding var query: SimilarPhotosFilterQuery
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if query.isDefault {
                        Text(L10n.string("Showing the default view"))
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FilterSheetSection(title: L10n.string("Scope")) {
                        FilterGlassSegmentedControl(
                            options: SimilarPhotosScopeFilter.allCases.map {
                                FilterSegmentOption(value: $0, title: $0.title)
                            },
                            selection: $query.scope
                        )
                    }

                    FilterSheetSection(title: L10n.string("Time")) {
                        FilterGlassSegmentedControl(
                            options: SimilarPhotosTimeFilter.allCases.map {
                                FilterSegmentOption(value: $0, title: $0.title)
                            },
                            selection: $query.time
                        )
                    }

                    FilterSheetSection(title: L10n.string("Match tightness")) {
                        FilterGlassSegmentedControl(
                            options: SimilarPhotosMatchTightness.allCases.map {
                                FilterSegmentOption(value: $0, title: $0.title)
                            },
                            selection: $query.match
                        )
                    }
                }
                .padding(.horizontal, Theme.space5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(PhotoDeleteScreenBackground())
            .navigationTitle(L10n.string("Filter and sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    FilterSheetToolbar.resetButton(isDefault: query.isDefault) {
                        query = .default
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    FilterSheetToolbar.doneButton {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
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
}
