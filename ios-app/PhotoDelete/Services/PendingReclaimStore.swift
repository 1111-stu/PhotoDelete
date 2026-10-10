//
//  PendingReclaimStore.swift
//  PhotoDelete
//
//  Local ledger for space still held in system Recently Deleted after
//  OnePhoto confirms deletion. Cleared when the user marks trash emptied.
//

import Foundation
import Combine

struct PendingReclaimState: Codable, Equatable {
    var itemCount: Int
    var estimatedSpaceMB: Double
    var updatedAt: Date

    static let empty = PendingReclaimState(
        itemCount: 0,
        estimatedSpaceMB: 0,
        updatedAt: .distantPast
    )

    var hasPendingItems: Bool {
        itemCount > 0
    }

    var formattedSpace: String {
        CleanupStatsFormatter.space(max(estimatedSpaceMB, 0))
    }

    func isExpired(
        referenceDate: Date = Date(),
        retentionDays: Int = PendingReclaimStore.retentionDays,
        calendar: Calendar = .current
    ) -> Bool {
        guard hasPendingItems else { return false }
        guard let expiry = calendar.date(byAdding: .day, value: retentionDays, to: updatedAt) else {
            return false
        }
        return referenceDate >= expiry
    }

    func adding(
        count: Int,
        spaceMB: Double,
        at date: Date = Date()
    ) -> PendingReclaimState {
        let safeCount = max(count, 0)
        let safeSpace = spaceMB.isFinite ? max(spaceMB, 0) : 0
        guard safeCount > 0 || safeSpace > 0 else { return self }
        return PendingReclaimState(
            itemCount: itemCount + safeCount,
            estimatedSpaceMB: estimatedSpaceMB + safeSpace,
            updatedAt: date
        )
    }
}

final class PendingReclaimStore: ObservableObject {
    static let retentionDays = 30

    @Published private(set) var state: PendingReclaimState = .empty

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = AppConstants.pendingReclaimStateKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    @discardableResult
    func recordDeletion(
        itemCount: Int,
        estimatedSpaceMB: Double,
        at date: Date = Date()
    ) -> PendingReclaimState {
        guard itemCount > 0 else { return state }
        let next = currentState(referenceDate: date)
            .adding(count: itemCount, spaceMB: estimatedSpaceMB, at: date)
        persist(next)
        return next
    }

    @discardableResult
    func clear(at date: Date = Date()) -> PendingReclaimState {
        let next = PendingReclaimState(
            itemCount: 0,
            estimatedSpaceMB: 0,
            updatedAt: date
        )
        persist(next)
        return next
    }

    /// Returns live state, expiring stale ledgers past the 30-day window.
    func currentState(referenceDate: Date = Date()) -> PendingReclaimState {
        if state.isExpired(referenceDate: referenceDate) {
            return clear(at: referenceDate)
        }
        return state
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            state = .empty
            return
        }

        do {
            let decoded = try decoder.decode(PendingReclaimState.self, from: data)
            if decoded.isExpired() {
                state = .empty
                userDefaults.removeObject(forKey: storageKey)
            } else {
                state = decoded
            }
        } catch {
            state = .empty
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    private func persist(_ next: PendingReclaimState) {
        state = next
        if next.hasPendingItems {
            if let data = try? encoder.encode(next) {
                userDefaults.set(data, forKey: storageKey)
            }
        } else {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
}
