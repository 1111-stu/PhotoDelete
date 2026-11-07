import Photos

enum AlbumShortcutEligibility {
    static func shouldInclude(type: AlbumType, hasAssetCollection: Bool, canAddContent: Bool) -> Bool {
        type == .userCreated && hasAssetCollection && canAddContent
    }

    static func canFile(into album: AlbumInfo) -> Bool {
        shouldInclude(
            type: album.type,
            hasAssetCollection: album.assetCollection != nil,
            canAddContent: album.assetCollection?.canPerform(.addContent) == true
        )
    }

    static func filteredAlbums(_ albums: [AlbumInfo]) -> [AlbumInfo] {
        albums.filter(canFile)
    }
}
