import Foundation
import Photos

struct AssetSourceResolution {
    let assets: [PHAsset]
    let isUnavailable: Bool
}

@MainActor
protocol AssetSourceResolving {
    func resolve(_ source: AssetSource) async -> AssetSourceResolution
}

@MainActor
final class AssetSourceResolver: AssetSourceResolving {
    private let dataManager: DataManager

    init(dataManager: DataManager) { self.dataManager = dataManager }

    func resolve(_ source: AssetSource) async -> AssetSourceResolution {
        let authorization = dataManager.photoLibraryManager.authorizationStatus
        guard authorization == .authorized || authorization == .limited else {
            return .init(assets: [], isUnavailable: true)
        }
        switch source {
        case let .category(category):
            return .init(assets: dataManager.getRealPhotos(for: Self.photoCategory(for: category)), isUnavailable: false)
        case let .album(.virtual(identifier)):
            let type = Self.albumType(for: identifier)
            // Recents has a real smart collection; resolve that instead of the
            // legacy virtual-album fallback (which cannot load recent assets).
            if identifier == .recents {
                return await Self.fetchCollectionAssets(id: nil)
            }
            return .init(assets: dataManager.getPhotosForAlbum(.init(assetCollection: nil, type: type)), isUnavailable: false)
        case let .album(.collection(id)):
            // Always re-resolve the stable ID: an AlbumInfo retained by a view
            // may refer to a deleted collection or stale membership/title.
            return await Self.fetchCollectionAssets(id: id)
        }
    }

    private static func fetchCollectionAssets(id: String?) async -> AssetSourceResolution {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let collections: PHFetchResult<PHAssetCollection>
                if let id {
                    collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
                } else {
                    collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyAdded, options: nil)
                }
                guard let collection = collections.firstObject else {
                    continuation.resume(returning: .init(assets: [], isUnavailable: true))
                    return
                }
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let fetched = PHAsset.fetchAssets(in: collection, options: options)
                var assets: [PHAsset] = []
                assets.reserveCapacity(fetched.count)
                fetched.enumerateObjects { asset, _, _ in assets.append(asset) }
                continuation.resume(returning: .init(assets: assets, isUnavailable: false))
            }
        }
    }

    static func photoCategory(for category: AssetCategoryID) -> PhotoCategory {
        switch category {
        case .all: return .all
        case .unclassified: return .unclassified
        case .videos: return .videos
        case .screenshots: return .screenshots
        case .screenRecordings: return .screenRecordings
        case .livePhotos: return .livePhotos
        case .favorites: return .favorites
        }
    }

    static func albumType(for identifier: AssetVirtualAlbumID) -> AlbumType {
        switch identifier {
        case .all: return .all
        case .recents: return .recents
        case .favorites: return .favorites
        case .screenshots: return .screenshots
        case .videos: return .videos
        case .livePhotos: return .livePhotos
        }
    }

    static func reference(for album: AlbumInfo) -> AssetAlbumReference {
        if album.assetCollection != nil { return .collection(id: album.id) }
        if let virtual = AssetVirtualAlbumID(rawValue: album.type.rawValue) { return .virtual(virtual) }
        return .collection(id: album.id)
    }
}
