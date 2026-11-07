//
//  SimilarPhotoVisualMatcher.swift
//  Poca
//
//  Vision Feature Print confirmation for metadata-prefiltered similar-photo groups.
//

import Foundation
import Photos
import UIKit
import Vision

/// Confirms (and may split) metadata candidate clusters using Apple Vision feature prints.
///
/// Call site: `DataManager.makeSimilarPhotoGroups` after `similarPhotoIdentifierGroups`.
/// UI only passes a `SimilarPhotoMatchProfile`; Vision details stay here.
enum SimilarPhotoVisualMatcher {
    /// Thumbnail side used for feature-print generation (local pixels only).
    static let featurePrintThumbnailSide: CGFloat = 256

    /// Visual distance ceilings (lower = stricter). Calibrate in one place.
    static let stricterMaxDistance: Float = 0.35
    static let standardMaxDistance: Float = 0.55
    static let looserMaxDistance: Float = 0.75

    // MARK: - Public seam

    /// Confirms each candidate group; emits subgroups with size ≥ 2.
    ///
    /// - Burst groups: Vision when all members have local prints; if any member lacks
    ///   pixels/prints, the original burst group is kept (not dissolved for missing data).
    /// - Temporal groups: members without local prints are dropped; remaining edges
    ///   kept only when distance ≤ `maxDistance`.
    static func confirmCandidateGroups(
        _ candidateGroups: [[String]],
        assetsByID: [String: PHAsset],
        maxDistance: Float,
        imageManager: PHImageManager = PHImageManager.default()
    ) -> [[String]] {
        guard !candidateGroups.isEmpty else { return [] }

        var confirmed: [[String]] = []
        confirmed.reserveCapacity(candidateGroups.count)

        for group in candidateGroups {
            guard group.count >= 2 else { continue }

            let isBurst = isSystemBurstGroup(group, assetsByID: assetsByID)
            let prints = featurePrints(
                for: group,
                assetsByID: assetsByID,
                imageManager: imageManager
            )
            let subgroups = confirmedSubgroups(
                identifiers: group,
                availableIdentifiers: Set(prints.keys),
                maxDistance: maxDistance,
                preserveWhenUnavailable: isBurst,
                distanceBetween: { lhs, rhs in
                    distance(between: prints[lhs], and: prints[rhs])
                }
            )
            confirmed.append(contentsOf: subgroups)
        }

        return confirmed
    }

    // MARK: - Pure clustering (testable)

    /// Splits a candidate cluster by pairwise visual distance.
    ///
    /// `distanceBetween` should return a distance when both sides are available, or `nil`
    /// when comparison is impossible. Identifiers not in `availableIdentifiers` are treated
    /// as missing prints.
    static func confirmedSubgroups(
        identifiers: [String],
        availableIdentifiers: Set<String>,
        maxDistance: Float,
        preserveWhenUnavailable: Bool,
        distanceBetween: (_ lhs: String, _ rhs: String) -> Float?
    ) -> [[String]] {
        guard identifiers.count >= 2 else { return [] }

        let missingCount = identifiers.reduce(into: 0) { count, id in
            if !availableIdentifiers.contains(id) { count += 1 }
        }

        if missingCount > 0, preserveWhenUnavailable {
            return [identifiers]
        }

        let printable = identifiers.filter { availableIdentifiers.contains($0) }
        guard printable.count >= 2 else { return [] }

        var parent = Dictionary(uniqueKeysWithValues: printable.map { ($0, $0) })
        var rank = Dictionary(uniqueKeysWithValues: printable.map { ($0, 0) })

        func find(_ id: String) -> String {
            var current = id
            while parent[current] != current {
                let next = parent[current] ?? current
                parent[current] = parent[next] ?? next
                current = next
            }
            return current
        }

        func union(_ lhs: String, _ rhs: String) {
            let leftRoot = find(lhs)
            let rightRoot = find(rhs)
            guard leftRoot != rightRoot else { return }
            let leftRank = rank[leftRoot] ?? 0
            let rightRank = rank[rightRoot] ?? 0
            if leftRank < rightRank {
                parent[leftRoot] = rightRoot
            } else if leftRank > rightRank {
                parent[rightRoot] = leftRoot
            } else {
                parent[rightRoot] = leftRoot
                rank[leftRoot] = leftRank + 1
            }
        }

        for i in 0..<printable.count {
            for j in (i + 1)..<printable.count {
                let lhs = printable[i]
                let rhs = printable[j]
                guard let distance = distanceBetween(lhs, rhs),
                      distance <= maxDistance else {
                    continue
                }
                union(lhs, rhs)
            }
        }

        var buckets: [String: [String]] = [:]
        for id in printable {
            buckets[find(id), default: []].append(id)
        }

        // Preserve original encounter order within each component.
        let order = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($0.element, $0.offset) })
        return buckets.values
            .map { component in
                component.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
            }
            .filter { $0.count >= 2 }
            .sorted { lhs, rhs in
                (order[lhs[0]] ?? 0) < (order[rhs[0]] ?? 0)
            }
    }

    // MARK: - Vision / Photos

    private static func isSystemBurstGroup(
        _ identifiers: [String],
        assetsByID: [String: PHAsset]
    ) -> Bool {
        let burstIDs = identifiers.compactMap { id -> String? in
            guard let burst = assetsByID[id]?.burstIdentifier, !burst.isEmpty else { return nil }
            return burst
        }
        guard burstIDs.count == identifiers.count,
              let first = burstIDs.first else {
            return false
        }
        return burstIDs.allSatisfy { $0 == first }
    }

    private static func featurePrints(
        for identifiers: [String],
        assetsByID: [String: PHAsset],
        imageManager: PHImageManager
    ) -> [String: VNFeaturePrintObservation] {
        var prints: [String: VNFeaturePrintObservation] = [:]
        prints.reserveCapacity(identifiers.count)

        for id in identifiers {
            guard let asset = assetsByID[id],
                  let cgImage = loadLocalCGImage(for: asset, imageManager: imageManager),
                  let print = makeFeaturePrint(from: cgImage) else {
                continue
            }
            prints[id] = print
        }

        return prints
    }

    private static func loadLocalCGImage(
        for asset: PHAsset,
        imageManager: PHImageManager
    ) -> CGImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true

        let side = featurePrintThumbnailSide
        var result: CGImage?

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: side, height: side),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) == true
            guard !isCancelled, !isInCloud, let image else { return }
            result = image.cgImage
        }

        return result
    }

    private static func makeFeaturePrint(from cgImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            return nil
        }
    }

    private static func distance(
        between lhs: VNFeaturePrintObservation?,
        and rhs: VNFeaturePrintObservation?
    ) -> Float? {
        guard let lhs, let rhs else { return nil }
        var value: Float = 0
        do {
            try lhs.computeDistance(&value, to: rhs)
            return value
        } catch {
            return nil
        }
    }
}
