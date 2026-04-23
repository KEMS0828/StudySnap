import Foundation
import FirebaseCore
import FirebaseFirestore

@Observable
class DataStore {
    var currentUser: UserProfile?
    var currentGroup: StudyGroup?
    var allGroups: [StudyGroup] = []
    var timelinePosts: [StudyPost] = []
    var sessions: [StudySession] = []
    var goals: [StudyGoal] = []
    var chatMessages: [ChatMessage] = []
    var isLoading: Bool = false

    private let cloud = CloudService()
    private var currentAuthUserId: String?

    private static let draftKey = "StudySnap_Draft"

    var hasDraft: Bool = false

    func saveDraft(_ draft: DraftData) {
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: DataStore.draftKey)
            hasDraft = true
        }
    }

    func loadDraft() -> DraftData? {
        guard let data = UserDefaults.standard.data(forKey: DataStore.draftKey) else { return nil }
        guard let draft = try? JSONDecoder().decode(DraftData.self, from: data) else { return nil }
        if Date.now.timeIntervalSince(draft.savedAt) > 86400 {
            deleteDraft()
            return nil
        }
        return draft
    }

    func deleteDraft() {
        UserDefaults.standard.removeObject(forKey: DataStore.draftKey)
        hasDraft = false
    }

    func cleanupExpiredDraft() {
        guard let data = UserDefaults.standard.data(forKey: DataStore.draftKey),
              let draft = try? JSONDecoder().decode(DraftData.self, from: data) else {
            hasDraft = false
            return
        }
        if Date.now.timeIntervalSince(draft.savedAt) > 86400 {
            deleteDraft()
        } else {
            hasDraft = true
        }
    }

    func configure(authUserId: String, displayName: String?) {
        self.currentAuthUserId = authUserId
        BlockService.shared.configure(for: authUserId)
        cleanupExpiredDraft()
        Task { [weak self] in
            guard let self else { return }
            guard FirebaseApp.app() != nil else {
                print("[DataStore] Firebase not configured yet, skipping data load")
                return
            }
            do {
                try Task.checkCancellation()
                await self.loadUser(authUserId: authUserId, displayName: displayName)
                try Task.checkCancellation()
                await self.detectKickedFromGroup()
                try Task.checkCancellation()
                await self.loadGroups()
                try Task.checkCancellation()
                await self.loadPosts()
                try Task.checkCancellation()
                await self.loadSessions()
                try Task.checkCancellation()
                await self.loadGoals()
                try Task.checkCancellation()
                await self.loadChatMessages()
                try Task.checkCancellation()
                await self.cleanupExpiredPosts()
            } catch is CancellationError {
                print("[DataStore] Initial load cancelled")
            } catch {
                print("[DataStore] Initial load error: \(error)")
            }
        }
    }

    func reset() {
        currentUser = nil
        currentGroup = nil
        allGroups = []
        timelinePosts = []
        sessions = []
        goals = []
        currentAuthUserId = nil
        BlockService.shared.reset()
    }

    private func loadUser(authUserId: String, displayName: String?) async {
        do {
            if var user = try await cloud.getUser(authUserId: authUserId) {
                if let name = displayName, !name.isEmpty, user.name == "あなた" {
                    user.name = name
                    try await cloud.saveUser(user)
                }
                currentUser = user
                if let groupId = user.currentGroupId {
                    await loadCurrentGroup(groupId: groupId)
                }
            } else {
                let name = (displayName?.isEmpty == false) ? (displayName ?? "あなた") : "あなた"
                let newUser = UserProfile(authUserId: authUserId, name: name)
                try await cloud.saveUser(newUser)
                currentUser = newUser
            }
        } catch {
            let name = (displayName?.isEmpty == false) ? (displayName ?? "あなた") : "あなた"
            currentUser = UserProfile(authUserId: authUserId, name: name)
        }
    }

    private func loadCurrentGroup(groupId: String) async {
        if let group = allGroups.first(where: { $0.id == groupId }) {
            currentGroup = group
        } else {
            await loadGroups()
            currentGroup = allGroups.first(where: { $0.id == groupId })
        }
    }

    func loadGroups() async {
        do {
            allGroups = try await cloud.getAllGroups()
            if let groupId = currentUser?.currentGroupId {
                currentGroup = allGroups.first(where: { $0.id == groupId })
            }
        } catch {}
    }

    func loadPosts() async {
        guard let group = currentGroup else {
            timelinePosts = []
            return
        }
        do {
            timelinePosts = try await cloud.getPostsForGroup(group.id)
        } catch {
            print("[DataStore] loadPosts error: \(error)")
        }
    }

    func loadSessions() async {
        guard let user = currentUser else {
            sessions = []
            return
        }
        do {
            sessions = try await cloud.getSessionsForUser(user.id)
        } catch {}
    }

    func createGroup(name: String, description: String, joinMethod: JoinMethod, photoData: Data? = nil) {
        guard var user = currentUser else { return }
        var group = StudyGroup(name: name, groupDescription: description, adminId: user.id, joinMethod: joinMethod)

        Task {
            do {
                if let data = photoData {
                    let url = try? await cloud.uploadPhoto(data, path: "communities/\(group.id)/cover/photo.jpg")
                    group.groupPhotoUrl = url
                }
                try await cloud.saveGroup(group)
                user.currentGroupId = group.id
                user.isAdmin = true
                try await cloud.saveUser(user)
                currentUser = user
                currentGroup = group
                await loadGroups()
            } catch {
                generalError = "グループの作成に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    static let maxGroupMembers = 8

    func joinGroup(_ group: StudyGroup) {
        guard var user = currentUser else { return }
        var mutableGroup = group
        guard mutableGroup.memberIds.count < DataStore.maxGroupMembers else { return }
        guard !mutableGroup.memberIds.contains(user.id) else { return }
        guard !mutableGroup.pendingMemberIds.contains(user.id) else { return }

        Task {
            if mutableGroup.method == .free {
                mutableGroup.memberIds.append(user.id)
                user.currentGroupId = mutableGroup.id
                user.isAdmin = false
                try? await cloud.saveGroup(mutableGroup)
                try? await cloud.saveUser(user)
                currentUser = user
                currentGroup = mutableGroup
                await loadPosts()
                await loadChatMessages()
            } else {
                mutableGroup.pendingMemberIds.append(user.id)
                try? await cloud.saveGroup(mutableGroup)
            }
            await loadGroups()
        }
    }

    func leaveGroup() {
        guard var user = currentUser, var group = currentGroup else { return }
        group.memberIds.removeAll { $0 == user.id }
        user.currentGroupId = nil
        user.isAdmin = false
        currentUser = user
        currentGroup = nil
        timelinePosts = []

        Task {
            await cloud.refreshAuthTokenOnce()
            try? await cloud.saveGroup(group)
            try? await cloud.saveUserWithRetry(user)
            await loadGroups()
        }
    }

    func leaveAndDeleteGroup() {
        guard var user = currentUser, let group = currentGroup else { return }
        user.currentGroupId = nil
        user.isAdmin = false
        currentUser = user
        currentGroup = nil
        timelinePosts = []

        Task {
            await cloud.refreshAuthTokenOnce()
            try? await cloud.deleteGroup(group.id)
            try? await cloud.saveUserWithRetry(user)
            await loadGroups()
        }
    }

    func transferAdmin(to targetUserId: String) {
        guard var group = currentGroup, var user = currentUser else { return }
        group.adminId = targetUserId
        user.isAdmin = false

        Task {
            try? await cloud.saveGroup(group)
            try? await cloud.saveUser(user)
            currentUser = user
            currentGroup = group
        }
    }

    func approveMember(_ memberId: String) {
        guard var group = currentGroup else { return }
        group.pendingMemberIds.removeAll { $0 == memberId }
        group.memberIds.append(memberId)

        Task {
            if var memberUser = try? await cloud.getUser(authUserId: memberId) {
                memberUser.currentGroupId = group.id
                try? await cloud.saveUser(memberUser)
            }
            try? await cloud.saveGroup(group)
            currentGroup = group
            await loadGroups()
        }
    }

    func rejectMember(_ memberId: String) {
        guard var group = currentGroup else { return }
        group.pendingMemberIds.removeAll { $0 == memberId }

        Task {
            try? await cloud.saveGroup(group)
            currentGroup = group
            await loadGroups()
        }
    }

    func updateGroupInfo(groupId: String, name: String, description: String, joinMethod: JoinMethod, newPhotoData: Data?) async {
        guard var group = (currentGroup?.id == groupId ? currentGroup : allGroups.first(where: { $0.id == groupId })) else { return }
        group.name = name
        group.groupDescription = description
        group.joinMethod = joinMethod.rawValue

        if let data = newPhotoData {
            if let url = try? await cloud.uploadPhoto(data, path: "communities/\(group.id)/cover/photo.jpg") {
                group.groupPhotoUrl = url
            }
        }

        do {
            try await cloud.saveGroup(group)
            if currentGroup?.id == group.id {
                currentGroup = group
            }
            await loadGroups()
        } catch {
            generalError = "グループ情報の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    var wasKickedFromGroup: Bool = false

    private func detectKickedFromGroup() async {
        guard let user = currentUser, let group = currentGroup else { return }
        if let fresh = try? await cloud.getGroupById(group.id) {
            if !fresh.memberIds.contains(user.id) {
                var updatedUser = user
                updatedUser.currentGroupId = nil
                updatedUser.isAdmin = false
                currentUser = updatedUser
                currentGroup = nil
                timelinePosts = []
                chatMessages = []
                wasKickedFromGroup = true
                try? await cloud.saveUser(updatedUser)
            }
        } else {
            var updatedUser = user
            updatedUser.currentGroupId = nil
            updatedUser.isAdmin = false
            currentUser = updatedUser
            currentGroup = nil
            timelinePosts = []
            chatMessages = []
            try? await cloud.saveUser(updatedUser)
        }
    }

    func removeMember(_ memberId: String) {
        guard var group = currentGroup else { return }
        group.memberIds.removeAll { $0 == memberId }

        Task {
            if var memberUser = try? await cloud.getUser(authUserId: memberId) {
                memberUser.currentGroupId = nil
                memberUser.isAdmin = false
                try? await cloud.saveUser(memberUser)
            }
            try? await cloud.saveGroup(group)
            currentGroup = group
            await loadGroups()
        }
    }

    var isPendingApproval: Bool {
        guard let user = currentUser else { return false }
        return allGroups.contains { $0.pendingMemberIds.contains(user.id) }
    }

    func pendingGroupFor(user: UserProfile) -> StudyGroup? {
        allGroups.first { $0.pendingMemberIds.contains(user.id) }
    }

    func cancelJoinRequest(for group: StudyGroup) {
        guard let user = currentUser else { return }
        var mutableGroup = group
        mutableGroup.pendingMemberIds.removeAll { $0 == user.id }

        Task {
            try? await cloud.saveGroup(mutableGroup)
            await loadGroups()
        }
    }

    func cancelPendingRequest() {
        guard let user = currentUser else { return }
        if let group = pendingGroupFor(user: user) {
            cancelJoinRequest(for: group)
        }
    }

    var pendingMemberCount: Int {
        currentGroup?.pendingMemberIds.count ?? 0
    }

    func fetchMembers(for group: StudyGroup) async -> [UserProfile] {
        (try? await cloud.getUsers(authUserIds: group.memberIds)) ?? []
    }

    func fetchMember(by id: String) async -> UserProfile? {
        try? await cloud.getUser(authUserId: id)
    }

    func fetchSessionsForMember(_ memberId: String) async -> [StudySession] {
        (try? await cloud.getSessionsForUser(memberId)) ?? []
    }

    func fetchUsers(ids: [String]) async throws -> [UserProfile] {
        try await cloud.getUsers(authUserIds: ids)
    }

    func saveSession(_ session: StudySession) {
        Task {
            do {
                var mutableSession = session
                if let user = currentUser {
                    mutableSession.ownerUserId = user.id
                }
                try await cloud.saveSession(mutableSession)
                await loadSessions()
            } catch {
                generalError = "セッションの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func saveExternalSession(minutes: Int, subject: String, date: Date) {
        let session = StudySession(
            externalMinutes: minutes,
            subject: subject,
            date: date,
            ownerUserId: currentUser?.id
        )
        sessions.insert(session, at: 0)
        Task {
            try? await cloud.saveSession(session)
        }
    }

    func deleteExternalSession(_ session: StudySession) {
        sessions.removeAll { $0.id == session.id }
        Task {
            try? await cloud.deleteSession(session.id)
        }
    }

    var uploadError: String?
    var approvalError: String?
    var generalError: String?

    func createPost(from session: StudySession, editedPhotos: [Data]) {
        guard let user = currentUser, let group = currentGroup else { return }

        Task {
            isLoading = true
            uploadError = nil
            defer { isLoading = false }

            var photoUrls: [String] = []
            if !editedPhotos.isEmpty {
                let result = await cloud.uploadPhotos(editedPhotos, basePath: "sessions/\(session.id)/photos")
                photoUrls = result.urls
                if result.failedCount > 0 {
                    let detail = result.lastErrorDetail ?? "不明なエラー"
                    if result.urls.isEmpty {
                        uploadError = "写真のアップロードに失敗しました。\n原因: \(detail)"
                        return
                    } else {
                        uploadError = "\(result.failedCount)枚の写真のアップロードに失敗しました。\n原因: \(detail)"
                    }
                }
            }

            var post = StudyPost(
                sessionId: session.id,
                userId: user.id,
                userName: user.name,
                groupId: group.id,
                subject: session.subject,
                reflection: session.reflection,
                photoUrls: photoUrls,
                duration: session.duration
            )
            post.userPhotoUrl = user.profilePhotoUrl
            do {
                try await cloud.savePost(post)
            } catch {
                print("[DataStore] savePost error: \(error)")
                uploadError = "投稿の保存に失敗しました。\n原因: \(error.localizedDescription)"
                return
            }
            await loadPosts()
        }
    }

    func approvePost(_ post: StudyPost) {
        guard let user = currentUser else { return }
        var mutablePost = post
        let previouslyApprovedCount = mutablePost.photoApproved.filter { $0 }.count
        mutablePost.isApproved = true
        mutablePost.approvedByUserId = user.id
        mutablePost.approvedByUserName = user.name
        mutablePost.approvedAt = .now

        let photoCount = mutablePost.photoUrls.count
        if mutablePost.photoApproved.count != photoCount {
            mutablePost.photoApproved = Array(repeating: false, count: photoCount)
        }
        if mutablePost.photoApprovedByNames.count != photoCount {
            mutablePost.photoApprovedByNames = Array(repeating: "", count: photoCount)
        }
        if mutablePost.photoApprovedAt.count != photoCount {
            mutablePost.photoApprovedAt = Array(repeating: 0, count: photoCount)
        }
        for i in 0..<photoCount {
            mutablePost.photoApproved[i] = true
            mutablePost.photoApprovedByNames[i] = user.name
            mutablePost.photoApprovedAt[i] = Date.now.timeIntervalSince1970
        }

        let newlyApprovedCount = mutablePost.photoApproved.count - previouslyApprovedCount

        Task {
            await cloud.refreshAuthTokenOnce()

            let postFields: [String: Any] = [
                "isApproved": true,
                "approvedByUserId": user.id,
                "approvedByUserName": user.name,
                "approvedAt": Date.now.timeIntervalSince1970,
                "photoApproved": mutablePost.photoApproved,
                "photoApprovedByNames": mutablePost.photoApprovedByNames,
                "photoApprovedAt": mutablePost.photoApprovedAt
            ]

            do {
                try await cloud.updatePostApprovalFields(post.id, fields: postFields)
            } catch {
                print("[DataStore] approvePost updateFields failed: \(error)")
                approvalError = cloud.firestoreErrorDescription(error)
                return
            }

            if let idx = timelinePosts.firstIndex(where: { $0.id == post.id }) {
                timelinePosts[idx] = mutablePost
            }

            do {
                if let session = try await cloud.getSession(byId: mutablePost.sessionId) {
                    let sessionFields: [String: Any] = [
                        "isApproved": true,
                        "approvedBy": user.name,
                        "approvedPhotoCount": mutablePost.photoApproved.count
                    ]
                    try await cloud.updateSessionApprovalFields(mutablePost.sessionId, fields: sessionFields)


                }
            } catch {
                print("[DataStore] approvePost session/user update failed: \(error)")
            }
            await loadSessions()
        }
    }

    func approvePhoto(in post: StudyPost, at index: Int) {
        guard let user = currentUser else { return }
        guard index >= 0 && index < post.photoApproved.count else { return }
        guard index < post.photoApprovedByNames.count else { return }
        guard index < post.photoApprovedAt.count else { return }
        guard !post.photoApproved[index] else { return }

        var mutablePost = post
        mutablePost.photoApproved[index] = true
        mutablePost.photoApprovedByNames[index] = user.name
        mutablePost.photoApprovedAt[index] = Date.now.timeIntervalSince1970

        let allApproved = mutablePost.photoApproved.allSatisfy { $0 }
        if allApproved {
            mutablePost.isApproved = true
            mutablePost.approvedByUserId = user.id
            mutablePost.approvedByUserName = user.name
            mutablePost.approvedAt = .now
        }

        Task {
            await cloud.refreshAuthTokenOnce()

            var postFields: [String: Any] = [
                "photoApproved": mutablePost.photoApproved,
                "photoApprovedByNames": mutablePost.photoApprovedByNames,
                "photoApprovedAt": mutablePost.photoApprovedAt
            ]
            if allApproved {
                postFields["isApproved"] = true
                postFields["approvedByUserId"] = user.id
                postFields["approvedByUserName"] = user.name
                postFields["approvedAt"] = Date.now.timeIntervalSince1970
            }

            do {
                try await cloud.updatePostApprovalFields(post.id, fields: postFields)
            } catch {
                print("[DataStore] approvePhoto updateFields failed: \(error)")
                approvalError = cloud.firestoreErrorDescription(error)
                return
            }

            if let idx = timelinePosts.firstIndex(where: { $0.id == post.id }) {
                timelinePosts[idx] = mutablePost
            }

            do {
                if let session = try await cloud.getSession(byId: mutablePost.sessionId) {
                    var sessionFields: [String: Any] = [
                        "approvedPhotoCount": session.approvedPhotoCount + 1
                    ]
                    if allApproved {
                        sessionFields["isApproved"] = true
                        sessionFields["approvedBy"] = user.name
                    }
                    try await cloud.updateSessionApprovalFields(mutablePost.sessionId, fields: sessionFields)
                }
            } catch {
                print("[DataStore] approvePhoto session/user update failed: \(error)")
            }
            await loadSessions()
        }
    }

    func rejectPhoto(in post: StudyPost, at index: Int) {
        guard index >= 0 && index < post.photoApproved.count else { return }
        guard index < post.photoApprovedByNames.count else { return }
        guard index < post.photoApprovedAt.count else { return }
        let wasPhotoApproved = post.photoApproved[index]

        var mutablePost = post
        mutablePost.photoApproved[index] = false
        mutablePost.photoApprovedByNames[index] = ""
        mutablePost.photoApprovedAt[index] = 0

        let wasFullyApproved = mutablePost.isApproved
        if mutablePost.isApproved {
            mutablePost.isApproved = false
            mutablePost.approvedByUserId = nil
            mutablePost.approvedByUserName = nil
            mutablePost.approvedAt = nil
        }

        if let idx = timelinePosts.firstIndex(where: { $0.id == post.id }) {
            timelinePosts[idx] = mutablePost
        }

        Task {
            await cloud.refreshAuthTokenOnce()

            var postFields: [String: Any] = [
                "photoApproved": mutablePost.photoApproved,
                "photoApprovedByNames": mutablePost.photoApprovedByNames,
                "photoApprovedAt": mutablePost.photoApprovedAt
            ]
            if wasFullyApproved {
                postFields["isApproved"] = false
                postFields["approvedByUserId"] = FieldValue.delete()
                postFields["approvedByUserName"] = FieldValue.delete()
                postFields["approvedAt"] = FieldValue.delete()
            }
            try? await cloud.updatePostApprovalFields(post.id, fields: postFields)

            if wasPhotoApproved {
                if let session = try? await cloud.getSession(byId: mutablePost.sessionId) {
                    let newCount = max(0, session.approvedPhotoCount - 1)
                    var sessionFields: [String: Any] = [
                        "approvedPhotoCount": newCount
                    ]
                    if newCount == 0 {
                        sessionFields["isApproved"] = false
                        sessionFields["approvedBy"] = FieldValue.delete()
                    }
                    try? await cloud.updateSessionApprovalFields(mutablePost.sessionId, fields: sessionFields)
                }
            }
            await loadSessions()
        }
    }

    func updatePost(_ post: StudyPost, subject: String, reflection: String, photoData: [Data]) {
        var mutablePost = post
        mutablePost.subject = subject
        mutablePost.reflection = reflection

        Task {
            isLoading = true
            defer { isLoading = false }

            for url in post.photoUrls {
                await cloud.deletePhoto(at: url)
            }
            let userId = currentUser?.id ?? post.userId
            let uploadResult = await cloud.uploadPhotos(photoData, basePath: "sessions/\(post.sessionId)/photos")
            if let detail = uploadResult.lastErrorDetail {
                print("[DataStore] Photo upload error detail: \(detail)")
            }
            let newUrls = uploadResult.urls
            mutablePost.photoUrls = newUrls

            try? await cloud.savePost(mutablePost)

            if var session = try? await cloud.getSession(byId: mutablePost.sessionId) {
                session.subject = subject
                session.reflection = reflection
                try? await cloud.saveSession(session)
            }
            await loadPosts()
            await loadSessions()
        }
    }

    func deletePost(_ post: StudyPost) {
        Task {
            for url in post.photoUrls {
                await cloud.deletePhoto(at: url)
            }

            if let session = try? await cloud.getSession(byId: post.sessionId), !session.isApproved {
                try? await cloud.deleteSession(session.id)
            }
            try? await cloud.deletePost(post.id)
            await loadPosts()
            await loadSessions()
        }
    }

    func saveUserProfile(_ user: UserProfile) {
        let oldName = currentUser?.name
        currentUser = user
        Task {
            await cloud.refreshAuthTokenOnce()
            try? await cloud.saveUserWithRetry(user)
            if let oldName, oldName != user.name {
                await cloud.updateUserNameOnPosts(userId: user.id, newName: user.name, newPhotoUrl: user.profilePhotoUrl)
                await loadPosts()
            }
        }
    }

    func uploadProfilePhoto(_ data: Data) async -> String? {
        guard let user = currentUser else { return nil }
        return try? await cloud.uploadPhoto(data, path: "users/\(user.id)/profile/photo.jpg")
    }

    func uploadGroupPhoto(_ data: Data, groupId: String) async -> String? {
        guard let user = currentUser else { return nil }
        return try? await cloud.uploadPhoto(data, path: "communities/\(groupId)/cover/photo.jpg")
    }

    func loadGoals() async {
        guard let user = currentUser else {
            goals = []
            return
        }
        do {
            goals = try await cloud.getGoalsForUser(user.id)
        } catch {}
    }

    func addGoal(title: String, targetMinutes: Int, type: GoalType) {
        guard let user = currentUser else { return }
        let calendar = Calendar.current
        var weekStart: Date? = nil
        if type == .weekly {
            weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
        }
        let goal = StudyGoal(ownerUserId: user.id, title: title, targetMinutes: targetMinutes, goalType: type, weekStartDate: weekStart)
        goals.insert(goal, at: 0)

        Task {
            do {
                try await cloud.saveGoal(goal)
            } catch {
                generalError = "目標の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func deleteGoal(_ goal: StudyGoal) {
        goals.removeAll { $0.id == goal.id }
        Task {
            do {
                try await cloud.deleteGoal(goal.id)
            } catch {
                generalError = "目標の削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func toggleGoalCompleted(_ goal: StudyGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index].isCompleted.toggle()
        }
        var mutableGoal = goal
        mutableGoal.isCompleted.toggle()
        Task {
            do {
                try await cloud.saveGoal(mutableGoal)
            } catch {
                generalError = "目標の更新に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    var todayGoals: [StudyGoal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return goals.filter { $0.type == .daily && calendar.startOfDay(for: $0.createdAt) == today }
    }

    var currentWeekGoals: [StudyGoal] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return goals.filter { $0.type == .weekly && $0.createdAt >= weekInterval.start && $0.createdAt < weekInterval.end }
    }

    var weeklyStudyTime: TimeInterval {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return sessions
            .filter { !$0.isExternal && $0.approvedPhotoCount > 0 && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end }
            .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
    }

    var allTimeStudyTime: TimeInterval {
        sessions
            .filter { !$0.isExternal && $0.approvedPhotoCount > 0 }
            .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
    }

    var allTimeExternalStudyTime: TimeInterval {
        sessions
            .filter { $0.isExternal }
            .reduce(0) { $0 + Double($1.externalMinutes) * 60 }
    }

    var allTimeTotalStudyTime: TimeInterval {
        allTimeStudyTime + allTimeExternalStudyTime
    }

    var unapprovedPostsCount: Int {
        guard let user = currentUser else { return 0 }
        return timelinePosts.filter { !$0.isApproved && $0.userId != user.id }.count
    }

    var todayStudyTime: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return sessions
            .filter { !$0.isExternal && $0.approvedPhotoCount > 0 && calendar.startOfDay(for: $0.startTime) == today }
            .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
    }

    var todayExternalStudyTime: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return sessions
            .filter { $0.isExternal && calendar.startOfDay(for: $0.startTime) == today }
            .reduce(0) { $0 + Double($1.externalMinutes) * 60 }
    }

    var todayTotalStudyTime: TimeInterval {
        todayStudyTime + todayExternalStudyTime
    }

    var todayShootingTime: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return timelinePosts
            .filter { $0.userId == currentUser?.id && calendar.startOfDay(for: $0.createdAt) == today }
            .reduce(0) { $0 + $1.duration }
    }

    var todayTotalUsedTime: TimeInterval {
        var total = todayShootingTime
        if let draft = loadDraft() {
            let calendar = Calendar.current
            if calendar.isDateInToday(draft.savedAt) {
                total += draft.duration
            }
        }
        return total
    }

    var todaySubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let approvedToday = sessions.filter { !$0.isExternal && $0.approvedPhotoCount > 0 && calendar.startOfDay(for: $0.startTime) == today }
        return subjectBreakdown(from: approvedToday)
    }

    var weeklySubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let approvedWeek = sessions.filter { !$0.isExternal && $0.approvedPhotoCount > 0 && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end }
        return subjectBreakdown(from: approvedWeek)
    }

    var monthlySubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        let approvedMonth = sessions.filter { !$0.isExternal && $0.approvedPhotoCount > 0 && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end }
        return subjectBreakdown(from: approvedMonth)
    }

    var allTimeSubjectBreakdown: [(String, TimeInterval)] {
        let approved = sessions.filter { !$0.isExternal && $0.approvedPhotoCount > 0 }
        return subjectBreakdown(from: approved)
    }

    // MARK: - External Study Breakdowns

    var todayExternalSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let externalToday = sessions.filter { $0.isExternal && calendar.startOfDay(for: $0.startTime) == today }
        return externalSubjectBreakdown(from: externalToday)
    }

    var weeklyExternalSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let externalWeek = sessions.filter { $0.isExternal && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end }
        return externalSubjectBreakdown(from: externalWeek)
    }

    var monthlyExternalSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        let externalMonth = sessions.filter { $0.isExternal && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end }
        return externalSubjectBreakdown(from: externalMonth)
    }

    // MARK: - Combined Study Breakdowns

    var todayCombinedSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let allToday = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && calendar.startOfDay(for: $0.startTime) == today
        }
        return combinedSubjectBreakdown(from: allToday)
    }

    var weeklyCombinedSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let allWeek = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end
        }
        return combinedSubjectBreakdown(from: allWeek)
    }

    var monthlyCombinedSubjectBreakdown: [(String, TimeInterval)] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        let allMonth = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end
        }
        return combinedSubjectBreakdown(from: allMonth)
    }

    var todayCombinedSubjectBreakdownSplit: [(String, TimeInterval, Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let allToday = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && calendar.startOfDay(for: $0.startTime) == today
        }
        return combinedSubjectBreakdownSplit(from: allToday)
    }

    var weeklyCombinedSubjectBreakdownSplit: [(String, TimeInterval, Bool)] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let allWeek = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end
        }
        return combinedSubjectBreakdownSplit(from: allWeek)
    }

    var monthlyCombinedSubjectBreakdownSplit: [(String, TimeInterval, Bool)] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        let allMonth = sessions.filter {
            ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end
        }
        return combinedSubjectBreakdownSplit(from: allMonth)
    }

    func deleteAllAccountData() async throws {
        guard let user = currentUser else { return }

        if let group = currentGroup {
            try await cloud.removeUserFromGroup(userId: user.id, group: group)
        } else if let groupId = user.currentGroupId, !groupId.isEmpty {
            if let group = try? await cloud.getGroupById(groupId) {
                try await cloud.removeUserFromGroup(userId: user.id, group: group)
            }
        }

        try await cloud.deleteAllUserData(userId: user.id)

        clearAllLocalData()
        reset()
    }

    private func clearAllLocalData() {
        deleteDraft()
        UserDefaults.standard.removeObject(forKey: "customSubjects")
        UserDefaults.standard.removeObject(forKey: "subjectColors")
        UserDefaults.standard.removeObject(forKey: "studyReminderEnabled")
        UserDefaults.standard.removeObject(forKey: "studyReminderTime")
    }

    func refreshTimeline() {
        Task {
            await refreshTimelineAsync()
        }
    }

    func refreshTimelineAsync() async {
        await detectKickedFromGroup()
        await loadGroups()
        await cleanupExpiredPosts()
        await loadPosts()
        await loadSessions()
        await loadGoals()
        await loadChatMessages()
    }

    // MARK: - Chat

    func loadChatMessages() async {
        guard let group = currentGroup else {
            chatMessages = []
            return
        }
        do {
            await cloud.deleteExpiredChatMessages(groupId: group.id)
            chatMessages = try await cloud.getChatMessages(groupId: group.id)
        } catch {
            print("[DataStore] loadChatMessages error: \(error)")
        }
    }

    func sendChatMessage(_ quickMessage: QuickMessage) {
        guard let user = currentUser, let group = currentGroup else { return }
        let message = ChatMessage(
            groupId: group.id,
            userId: user.id,
            userName: user.name,
            userPhotoUrl: user.profilePhotoUrl,
            message: quickMessage.rawValue
        )
        chatMessages.append(message)
        Task {
            try? await cloud.saveChatMessage(message)
        }
    }

    private func subjectBreakdown(from sessions: [StudySession]) -> [(String, TimeInterval)] {
        var dict: [String: TimeInterval] = [:]
        for session in sessions {
            let key = session.subject.isEmpty ? "未設定" : (session.subject == "なし" ? "教科なし" : session.subject)
            dict[key, default: 0] += session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
        }
        return dict.sorted { $0.value > $1.value }
    }

    private func externalSubjectBreakdown(from sessions: [StudySession]) -> [(String, TimeInterval)] {
        var dict: [String: TimeInterval] = [:]
        for session in sessions {
            let key = session.subject.isEmpty ? "未設定" : session.subject
            dict[key, default: 0] += Double(session.externalMinutes) * 60
        }
        return dict.sorted { $0.value > $1.value }
    }

    private func combinedSubjectBreakdown(from sessions: [StudySession]) -> [(String, TimeInterval)] {
        var dict: [String: TimeInterval] = [:]
        for session in sessions {
            let key = session.subject.isEmpty ? "未設定" : (session.subject == "なし" ? "教科なし" : session.subject)
            if session.isExternal {
                dict[key, default: 0] += Double(session.externalMinutes) * 60
            } else {
                dict[key, default: 0] += session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
            }
        }
        return dict.sorted { $0.value > $1.value }
    }

    private func combinedSubjectBreakdownSplit(from sessions: [StudySession]) -> [(String, TimeInterval, Bool)] {
        var appDict: [String: TimeInterval] = [:]
        var extDict: [String: TimeInterval] = [:]
        for session in sessions {
            let key = session.subject.isEmpty ? "未設定" : (session.subject == "なし" ? "教科なし" : session.subject)
            if session.isExternal {
                extDict[key, default: 0] += Double(session.externalMinutes) * 60
            } else {
                appDict[key, default: 0] += session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
            }
        }
        var result: [(String, TimeInterval, Bool)] = []
        for (key, value) in appDict {
            result.append((key, value, false))
        }
        for (key, value) in extDict {
            result.append((key, value, true))
        }
        return result.sorted { $0.1 > $1.1 }
    }

    func cleanupExpiredPosts() async {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let expired = timelinePosts.filter { $0.createdAt < twoWeeksAgo }
        for post in expired {
            for url in post.photoUrls {
                await cloud.deletePhoto(at: url)
            }
            if let session = try? await cloud.getSession(byId: post.sessionId), !session.isApproved {
                try? await cloud.deleteSession(session.id)
            }
            try? await cloud.deletePost(post.id)
        }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let studyDates = Set(sessions.filter { !$0.isExternal && $0.isApproved }.map { calendar.startOfDay(for: $0.startTime) })
        guard !studyDates.isEmpty else { return 0 }
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)
        if !studyDates.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while studyDates.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let studyDates = Set(sessions.filter { !$0.isExternal && $0.isApproved }.map { calendar.startOfDay(for: $0.startTime) })
        guard !studyDates.isEmpty else { return 0 }
        let sorted = studyDates.sorted()
        var maxStreak = 1
        var current = 1
        for i in 1..<sorted.count {
            if calendar.date(byAdding: .day, value: 1, to: sorted[i - 1]) == sorted[i] {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 1
            }
        }
        return maxStreak
    }

    var weeklyStudyTimes: [(String, TimeInterval)] {
        weeklyStudyTimesFiltered(includeApp: true, includeExternal: false)
    }

    var weeklyExternalStudyTimes: [(String, TimeInterval)] {
        weeklyStudyTimesFiltered(includeApp: false, includeExternal: true)
    }

    var weeklyCombinedStudyTimes: [(String, TimeInterval, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var result: [(String, TimeInterval, TimeInterval)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let appTotal = sessions
                .filter { !$0.isExternal && $0.approvedPhotoCount > 0 && $0.startTime >= dayStart && $0.startTime < dayEnd }
                .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }

            let externalTotal = sessions
                .filter { $0.isExternal && $0.startTime >= dayStart && $0.startTime < dayEnd }
                .reduce(0) { $0 + Double($1.externalMinutes) * 60 }

            let label = DataStore.weekdayFormatter.string(from: date)
            result.append((label, appTotal, externalTotal))
        }
        return result
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "E"
        return f
    }()

    private func weeklyStudyTimesFiltered(includeApp: Bool, includeExternal: Bool) -> [(String, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var result: [(String, TimeInterval)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            var dayTotal: TimeInterval = 0
            if includeApp {
                dayTotal += sessions
                    .filter { !$0.isExternal && $0.approvedPhotoCount > 0 && $0.startTime >= dayStart && $0.startTime < dayEnd }
                    .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
            }
            if includeExternal {
                dayTotal += sessions
                    .filter { $0.isExternal && $0.startTime >= dayStart && $0.startTime < dayEnd }
                    .reduce(0) { $0 + Double($1.externalMinutes) * 60 }
            }

            let label = DataStore.weekdayFormatter.string(from: date)
            result.append((label, dayTotal))
        }
        return result
    }
}
