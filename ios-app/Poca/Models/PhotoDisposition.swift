import Foundation
import Photos

/// 照片在「整理」里的唯一状态。三态互斥且穷尽（当前库照片）：
/// - `.pending`   待整理：没有明确的保留决定，也不在垃圾桶
/// - `.staged`    待确认：已在垃圾桶，尚未提交删除
/// - `.completed` 已完成：在 Poca 内明确保留过（收藏 / 入册 / 保留）或压缩生成
///
/// 关键口径：完成信号来自「用户在 Poca 里做了什么」，
/// 系统相册成员、系统收藏标记只是属性，不构成已完成。
///
/// 已删除照片离开当前库，不属于三态，只进统计账本。
enum PhotoDisposition: Equatable {
    case pending
    case staged
    case completed

    static func resolve(
        assetIdentifier: String,
        isStaged: Bool,
        persistentCompletedIDs: Set<String>
    ) -> PhotoDisposition {
        if isStaged {
            return .staged
        }
        if persistentCompletedIDs.contains(assetIdentifier) {
            return .completed
        }
        return .pending
    }
}

struct PhotoDispositionSnapshot {
    let stagedIDs: Set<String>
    let persistentCompletedIDs: Set<String>

    static let empty = PhotoDispositionSnapshot(
        stagedIDs: [],
        persistentCompletedIDs: []
    )

    func disposition(for asset: PHAsset) -> PhotoDisposition {
        disposition(forIdentifier: asset.localIdentifier)
    }

    func disposition(forIdentifier identifier: String) -> PhotoDisposition {
        PhotoDisposition.resolve(
            assetIdentifier: identifier,
            isStaged: stagedIDs.contains(identifier),
            persistentCompletedIDs: persistentCompletedIDs
        )
    }
}

struct PhotoDispositionCounts: Equatable {
    var pending = 0
    var staged = 0
    var completed = 0

    mutating func add(_ disposition: PhotoDisposition) {
        switch disposition {
        case .pending:
            pending += 1
        case .staged:
            staged += 1
        case .completed:
            completed += 1
        }
    }
}
