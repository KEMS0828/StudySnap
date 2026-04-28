import Foundation
import FirebaseFirestore

nonisolated struct StudyingPresence: Sendable {
    let userId: String
    let groupId: String
    let updatedAt: Date
}

actor StudyingPresenceService {
    private var _db: Firestore?
    private var listener: ListenerRegistration?

    private var db: Firestore {
        if let existing = _db { return existing }
        let instance = Firestore.firestore()
        _db = instance
        return instance
    }

    func upsertPresence(userId: String, groupId: String) async {
        do {
            try await db.collection("studyingPresence").document(userId).setData([
                "groupId": groupId,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("[StudyingPresenceService] upsert error: \(error)")
        }
    }

    func removePresence(userId: String) async {
        do {
            try await db.collection("studyingPresence").document(userId).delete()
        } catch {
            print("[StudyingPresenceService] remove error: \(error)")
        }
    }

    func startListening(groupId: String, onUpdate: @Sendable @escaping ([StudyingPresence]) -> Void) {
        listener?.remove()
        listener = db.collection("studyingPresence")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let presences: [StudyingPresence] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let groupId = data["groupId"] as? String else { return nil }
                    let date: Date
                    if let ts = data["updatedAt"] as? Timestamp {
                        date = ts.dateValue()
                    } else {
                        date = .now
                    }
                    return StudyingPresence(userId: doc.documentID, groupId: groupId, updatedAt: date)
                }
                onUpdate(presences)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
