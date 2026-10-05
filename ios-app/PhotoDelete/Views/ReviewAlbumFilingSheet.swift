import SwiftUI

struct ReviewAlbumFilingSheet: View {
    let albums: [AlbumInfo]
    let shortcutAlbums: [AlbumInfo]
    let selectedAlbumIDs: Set<String>
    let onFile: (AlbumInfo) -> Void
    let onContinue: () -> Void

    @EnvironmentObject private var dataManager: DataManager
    @State private var searchText = ""
    @State private var showsCreateAlbum = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        shortcutSection
                        if !filteredOtherAlbums.isEmpty {
                            albumSection(filteredOtherAlbums)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }

                Button(action: onContinue) {
                    Text(selectedAlbumIDs.isEmpty ? L10n.string("还未选择") : L10n.string("完成并继续"))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selectedAlbumIDs.isEmpty ? PhotoDeleteStyle.secondaryText.opacity(0.45) : PhotoDeleteStyle.accent)
                )
                .disabled(selectedAlbumIDs.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .accessibilityIdentifier("review-album-filing-continue")
            }
            .background(Color.black)
            .navigationTitle(L10n.string("放进哪个相册?"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: L10n.string("搜索相册"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsCreateAlbum = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.string("创建新相册"))
                }
            }
        }
        .sheet(isPresented: $showsCreateAlbum) {
            CreateAlbumView()
                .environmentObject(dataManager)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("快捷相册"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.secondaryText)

            if filteredShortcuts.isEmpty {
                Text(L10n.string("暂未添加快捷相册"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredShortcuts) { album in
                        albumRow(album)
                    }
                }
            }
        }
    }

    private func albumSection(_ albums: [AlbumInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("相册"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.secondaryText)

            VStack(spacing: 8) {
                ForEach(albums) { album in
                    albumRow(album)
                }
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .lineLimit(1)
                Text(L10n.photoCount(album.photosCount))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                onFile(album)
            } label: {
                Image(systemName: selectedAlbumIDs.contains(album.id) ? "checkmark.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(selectedAlbumIDs.contains(album.id))
            .accessibilityLabel(
                String(
                    format: L10n.string(selectedAlbumIDs.contains(album.id) ? "已归类到 %@" : "归类到 %@"),
                    album.title
                )
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PhotoDeleteStyle.surface)
        )
    }

    private var filteredShortcuts: [AlbumInfo] {
        filter(shortcutAlbums)
    }

    private var filteredOtherAlbums: [AlbumInfo] {
        let shortcutIDs = Set(shortcutAlbums.map(\.id))
        return filter(albums.filter { !shortcutIDs.contains($0.id) })
    }

    private func filter(_ albums: [AlbumInfo]) -> [AlbumInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return albums }
        return albums.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
