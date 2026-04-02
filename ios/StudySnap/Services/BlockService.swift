import Foundation

@Observable
class BlockService {
    static let shared = BlockService()

    private static let storageKeyPrefix = "StudySnap_BlockedUserIds_"
    private static let legacyStorageKey = "StudySnap_BlockedUserIds"

    var blockedUserIds: Set<String> = []
    private var currentUserId: String?

    private init() {}

    func configure(for userId: String) {
        currentUserId = userId
        let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        blockedUserIds = Set(stored)
        migrateLegacyDataIfNeeded()
    }

    func reset() {
        blockedUserIds = []
        currentUserId = nil
    }

    func isBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }

    func block(_ userId: String) {
        blockedUserIds.insert(userId)
        save()
    }

    func unblock(_ userId: String) {
        blockedUserIds.remove(userId)
        save()
    }

    private var storageKey: String {
        guard let uid = currentUserId else { return BlockService.legacyStorageKey }
        return BlockService.storageKeyPrefix + uid
    }

    private func save() {
        UserDefaults.standard.set(Array(blockedUserIds), forKey: storageKey)
    }

    private func migrateLegacyDataIfNeeded() {
        guard currentUserId != nil else { return }
        let legacy = UserDefaults.standard.stringArray(forKey: BlockService.legacyStorageKey)
        guard let legacyIds = legacy, !legacyIds.isEmpty else { return }
        for id in legacyIds {
            blockedUserIds.insert(id)
        }
        save()
        UserDefaults.standard.removeObject(forKey: BlockService.legacyStorageKey)
    }
}
