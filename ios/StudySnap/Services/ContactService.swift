import Foundation
import FirebaseFirestore
import FirebaseAuth

nonisolated struct ContactService {
    static func send(category: String, message: String) async throws {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? "anonymous"
        let email = Auth.auth().currentUser?.email ?? ""

        let data: [String: Any] = [
            "userId": userId,
            "email": email,
            "category": category,
            "message": message,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "new"
        ]

        try await db.collection("inquiries").addDocument(data: data)
    }
}
