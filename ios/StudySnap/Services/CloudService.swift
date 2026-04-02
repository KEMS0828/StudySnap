import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

@Observable
class CloudService {
    private var _db: Firestore?
    private var _storage: Storage?

    private var db: Firestore {
        if _db == nil { _db = Firestore.firestore() }
        return _db!
    }

    private var storage: Storage {
        if _storage == nil { _storage = Storage.storage() }
        return _storage!
    }

    // MARK: - User Profile

    func saveUser(_ user: UserProfile) async throws {
        let data = user.toFirestore()
        try await db.collection("users").document(user.id).setData(data, merge: true)
    }

    func getUser(authUserId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(authUserId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return UserProfile.fromFirestore(data, id: authUserId)
    }

    // MARK: - Groups

    func saveGroup(_ group: StudyGroup) async throws {
        let data = group.toFirestore()
        try await db.collection("groups").document(group.id).setData(data, merge: true)
    }

    func getAllGroups() async throws -> [StudyGroup] {
        let snapshot = try await db.collection("groups")
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            StudyGroup.fromFirestore(doc.data(), id: doc.documentID)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteGroup(_ groupId: String) async throws {
        try await db.collection("groups").document(groupId).delete()
    }

    // MARK: - Posts

    func savePost(_ post: StudyPost) async throws {
        let data = post.toFirestore()
        try await db.collection("posts").document(post.id).setData(data, merge: true)
    }

    func savePostWithRetry(_ post: StudyPost) async throws {
        do {
            try await savePost(post)
        } catch {
            print("[CloudService] savePost first attempt failed: \(error), retrying with token refresh...")
            await refreshAuthTokenOnce()
            try await savePost(post)
        }
    }

    func saveSessionWithRetry(_ session: StudySession) async throws {
        do {
            try await saveSession(session)
        } catch {
            print("[CloudService] saveSession first attempt failed: \(error), retrying with token refresh...")
            await refreshAuthTokenOnce()
            try await saveSession(session)
        }
    }

    func saveUserWithRetry(_ user: UserProfile) async throws {
        do {
            try await saveUser(user)
        } catch {
            print("[CloudService] saveUser first attempt failed: \(error), retrying with token refresh...")
            await refreshAuthTokenOnce()
            try await saveUser(user)
        }
    }

    func firestoreErrorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: return "権限エラー: この操作を実行する権限がありません。"
            case 14: return "サーバーが一時的に利用できません。しばらく後にお試しください。"
            case 4: return "リクエストがタイムアウトしました。ネットワーク接続を確認してください。"
            default: return "Firestoreエラー(code:\(nsError.code)): \(nsError.localizedDescription)"
            }
        }
        if nsError.domain == NSURLErrorDomain {
            return "ネットワークエラー: インターネット接続を確認してください。"
        }
        return "エラー: \(nsError.localizedDescription)"
    }

    func getPostsForGroup(_ groupId: String) async throws -> [StudyPost] {
        let snapshot = try await db.collection("posts")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            StudyPost.fromFirestore(doc.data(), id: doc.documentID)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func deletePost(_ postId: String) async throws {
        try await db.collection("posts").document(postId).delete()
    }

    func deletePostsForGroup(_ groupId: String) async throws {
        let snapshot = try await db.collection("posts")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    func updateUserNameOnPosts(userId: String, newName: String, newPhotoUrl: String?) async {
        do {
            let snapshot = try await db.collection("posts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            for doc in snapshot.documents {
                var updates: [String: Any] = ["userName": newName]
                if let url = newPhotoUrl {
                    updates["userPhotoUrl"] = url
                }
                try await doc.reference.updateData(updates)
            }
        } catch {
            print("[CloudService] updateUserNameOnPosts error: \(error)")
        }
    }

    // MARK: - Sessions

    func saveSession(_ session: StudySession) async throws {
        let data = session.toFirestore()
        try await db.collection("sessions").document(session.id).setData(data, merge: true)
    }

    func getSession(byId sessionId: String) async throws -> StudySession? {
        let doc = try await db.collection("sessions").document(sessionId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return StudySession.fromFirestore(data, id: sessionId)
    }

    func getSessionsForUser(_ authUserId: String) async throws -> [StudySession] {
        let snapshot = try await db.collection("sessions")
            .whereField("ownerUserId", isEqualTo: authUserId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            StudySession.fromFirestore(doc.data(), id: doc.documentID)
        }.sorted { $0.startTime > $1.startTime }
    }

    func deleteSession(_ sessionId: String) async throws {
        try await db.collection("sessions").document(sessionId).delete()
    }

    // MARK: - Goals

    func saveGoal(_ goal: StudyGoal) async throws {
        let data = goal.toFirestore()
        try await db.collection("goals").document(goal.id).setData(data, merge: true)
    }

    func getGoalsForUser(_ authUserId: String) async throws -> [StudyGoal] {
        let snapshot = try await db.collection("goals")
            .whereField("ownerUserId", isEqualTo: authUserId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            StudyGoal.fromFirestore(doc.data(), id: doc.documentID)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteGoal(_ goalId: String) async throws {
        try await db.collection("goals").document(goalId).delete()
    }

    // MARK: - Photo Upload

    private func compressPhoto(_ data: Data, maxBytes: Int = 150_000) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 800
        var targetImage = image
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        var quality: CGFloat = 0.5
        var compressed = targetImage.jpegData(compressionQuality: quality) ?? data
        while compressed.count > maxBytes && quality > 0.05 {
            quality -= 0.1
            compressed = targetImage.jpegData(compressionQuality: max(quality, 0.05)) ?? compressed
        }
        print("[CloudService] Compressed photo: \(data.count / 1024)KB -> \(compressed.count / 1024)KB (quality: \(String(format: "%.2f", quality)))")
        return compressed
    }

    func refreshAuthTokenOnce() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            let _ = try await user.getIDTokenResult(forcingRefresh: true)
            print("[CloudService] Auth token refreshed")
        } catch {
            print("[CloudService] Token refresh failed: \(error.localizedDescription)")
        }
    }

    func uploadPhoto(_ data: Data, path: String, skipTokenRefresh: Bool = false) async throws -> String {
        guard Auth.auth().currentUser != nil else {
            throw NSError(domain: "CloudService", code: -2, userInfo: [NSLocalizedDescriptionKey: "認証されていません。再ログインしてください。"])
        }

        if !skipTokenRefresh {
            await refreshAuthTokenOnce()
        }

        let compressed = compressPhoto(data)
        guard !compressed.isEmpty else {
            throw NSError(domain: "CloudService", code: -3, userInfo: [NSLocalizedDescriptionKey: "写真データが空です"])
        }
        print("[CloudService] Uploading \(compressed.count / 1024)KB to \(path)")

        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let resultMetadata = try await ref.putDataAsync(compressed, metadata: metadata)
        print("[CloudService] putDataAsync completed for \(path), server size=\(resultMetadata.size) bytes")

        if resultMetadata.size == 0 {
            print("[CloudService] WARNING: Server reported 0 bytes, upload may have failed")
            throw NSError(domain: "CloudService", code: -4, userInfo: [NSLocalizedDescriptionKey: "アップロードが正しく完了しませんでした（サーバーサイズ0）"])
        }

        var lastError: Error?
        for attempt in 1...3 {
            do {
                let url = try await ref.downloadURL()
                print("[CloudService] Upload success: \(url.absoluteString.prefix(80))...")
                return url.absoluteString
            } catch {
                lastError = error
                print("[CloudService] downloadURL attempt \(attempt)/3 failed: \(error.localizedDescription)")
                if attempt < 3 {
                    try await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
        throw lastError ?? NSError(domain: "CloudService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました"])
    }

    func uploadPhotoWithRetry(_ data: Data, path: String, maxAttempts: Int = 2, skipTokenRefresh: Bool = false) async throws -> String {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let url = try await uploadPhoto(data, path: path, skipTokenRefresh: skipTokenRefresh)
                return url
            } catch {
                lastError = error
                let nsError = error as NSError
                print("[CloudService] Upload attempt \(attempt)/\(maxAttempts) failed: [\(nsError.domain)] code=\(nsError.code) \(nsError.localizedDescription)")

                if nsError.domain == StorageErrorDomain {
                    let storageCode = StorageErrorCode(rawValue: nsError.code)
                    if storageCode == .unauthenticated || storageCode == .unauthorized {
                        throw error
                    }
                    if storageCode == .bucketNotFound || storageCode == .projectNotFound {
                        throw error
                    }
                }

                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        throw lastError ?? NSError(domain: "CloudService", code: -1, userInfo: [NSLocalizedDescriptionKey: "アップロードに失敗しました"])
    }

    func uploadPhotos(_ photos: [Data], basePath: String) async -> (urls: [String], failedCount: Int, lastErrorDetail: String?) {
        await refreshAuthTokenOnce()

        let indexed = photos.enumerated().map { ($0.offset, $0.element) }
        var results: [(index: Int, url: String?, errorDetail: String?)] = []

        await withTaskGroup(of: (Int, String?, String?).self) { group in
            for (index, photoData) in indexed {
                let path = "\(basePath)/\(index)_\(UUID().uuidString).jpg"
                group.addTask {
                    do {
                        let url = try await self.uploadPhotoWithRetry(photoData, path: path, skipTokenRefresh: true)
                        return (index, url, nil)
                    } catch {
                        let nsError = error as NSError
                        print("[CloudService] Photo \(index) permanently failed: [\(nsError.domain)] code=\(nsError.code) \(nsError.localizedDescription)")
                        return (index, nil, self.storageErrorDescription(nsError))
                    }
                }
            }
            for await result in group {
                results.append((index: result.0, url: result.1, errorDetail: result.2))
            }
        }

        results.sort { $0.index < $1.index }
        let urls = results.compactMap { $0.url }
        let failedCount = results.filter { $0.url == nil }.count
        let lastErrorDetail = results.last(where: { $0.errorDetail != nil })?.errorDetail
        return (urls, failedCount, lastErrorDetail)
    }

    private func storageErrorDescription(_ error: NSError) -> String {
        if error.domain == StorageErrorDomain {
            switch StorageErrorCode(rawValue: error.code) {
            case .unauthenticated:
                return "認証エラー: 再ログインしてください"
            case .unauthorized:
                return "権限エラー: Storageルールを確認してください"
            case .bucketNotFound:
                return "Storageバケットが見つかりません"
            case .quotaExceeded:
                return "ストレージ容量が上限に達しました"
            case .retryLimitExceeded:
                return "タイムアウト: ネットワーク接続を確認してください"
            case .cancelled:
                return "アップロードがキャンセルされました"
            default:
                return "Storageエラー(code:\(error.code)): \(error.localizedDescription)"
            }
        }
        if error.domain == NSURLErrorDomain {
            return "ネットワークエラー: インターネット接続を確認してください"
        }
        return "エラー: \(error.localizedDescription)"
    }

    func deletePhoto(at url: String) async {
        guard let ref = try? storage.reference(forURL: url) else { return }
        try? await ref.delete()
    }

    // MARK: - Approval Methods (using setData merge to avoid permission issues)

    func updatePostApprovalFields(_ postId: String, fields: [String: Any]) async throws {
        try await db.collection("posts").document(postId).setData(fields, merge: true)
    }

    func updateSessionApprovalFields(_ sessionId: String, fields: [String: Any]) async throws {
        try await db.collection("sessions").document(sessionId).setData(fields, merge: true)
    }

    func updateUserStudyTime(_ userId: String, additionalTime: TimeInterval) async throws {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard doc.exists, let data = doc.data() else { return }
        let currentTime = data["totalStudyTime"] as? TimeInterval ?? 0
        try await db.collection("users").document(userId).setData([
            "totalStudyTime": currentTime + additionalTime
        ], merge: true)
    }

    // MARK: - Chat Messages

    func saveChatMessage(_ message: ChatMessage) async throws {
        let data = message.toFirestore()
        try await db.collection("chatMessages").document(message.id).setData(data)
    }

    func getChatMessages(groupId: String) async throws -> [ChatMessage] {
        let snapshot = try await db.collection("chatMessages")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            ChatMessage.fromFirestore(doc.data(), id: doc.documentID)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    func deleteExpiredChatMessages(groupId: String) async {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let cutoff = fourteenDaysAgo.timeIntervalSince1970
        do {
            let snapshot = try await db.collection("chatMessages")
                .whereField("groupId", isEqualTo: groupId)
                .whereField("createdAt", isLessThan: cutoff)
                .getDocuments()
            for doc in snapshot.documents {
                try? await doc.reference.delete()
            }
        } catch {
            print("[CloudService] deleteExpiredChatMessages error: \(error)")
        }
    }

    func deleteAllChatMessages(groupId: String) async throws {
        let snapshot = try await db.collection("chatMessages")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Delete User Data

    func deleteAllUserData(userId: String) async throws {
        let postsSnapshot = try await db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in postsSnapshot.documents {
            if let photoUrls = doc.data()["photoUrls"] as? [String] {
                for url in photoUrls {
                    await deletePhoto(at: url)
                }
            }
            try await doc.reference.delete()
        }

        let sessionsSnapshot = try await db.collection("sessions")
            .whereField("ownerUserId", isEqualTo: userId)
            .getDocuments()
        for doc in sessionsSnapshot.documents {
            try await doc.reference.delete()
        }

        let chatSnapshot = try await db.collection("chatMessages")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in chatSnapshot.documents {
            try await doc.reference.delete()
        }

        let goalsSnapshot = try await db.collection("goals")
            .whereField("ownerUserId", isEqualTo: userId)
            .getDocuments()
        for doc in goalsSnapshot.documents {
            try await doc.reference.delete()
        }

        let notificationsSnapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in notificationsSnapshot.documents {
            try await doc.reference.delete()
        }

        if let profilePhotoUrl = try await db.collection("users").document(userId).getDocument().data()?["profilePhotoUrl"] as? String {
            await deletePhoto(at: profilePhotoUrl)
        }

        try await db.collection("users").document(userId).delete()
    }

    func getGroupById(_ groupId: String) async throws -> StudyGroup? {
        let doc = try await db.collection("groups").document(groupId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return StudyGroup.fromFirestore(data, id: groupId)
    }

    func removeUserFromGroup(userId: String, group: StudyGroup) async throws {
        var mutableGroup = group
        mutableGroup.memberIds.removeAll { $0 == userId }
        mutableGroup.pendingMemberIds.removeAll { $0 == userId }

        if mutableGroup.memberIds.isEmpty {
            try await deleteGroup(group.id)
        } else {
            if group.adminId == userId, let newAdmin = mutableGroup.memberIds.first {
                mutableGroup.adminId = newAdmin
            }
            try await saveGroup(mutableGroup)
        }
    }

    // MARK: - Batch User Fetch

    func getUsers(authUserIds: [String]) async throws -> [UserProfile] {
        guard !authUserIds.isEmpty else { return [] }
        let chunks = authUserIds.chunked(into: 10)
        var results: [UserProfile] = []
        for chunk in chunks {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            let users = snapshot.documents.compactMap { doc in
                UserProfile.fromFirestore(doc.data(), id: doc.documentID)
            }
            results.append(contentsOf: users)
        }
        return results
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
