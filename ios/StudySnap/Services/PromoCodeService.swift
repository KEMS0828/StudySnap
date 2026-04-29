import Foundation
import FirebaseFirestore

nonisolated enum PromoCodeError: LocalizedError, Sendable {
    case notFound
    case inactive
    case expired
    case capacityReached
    case alreadyRedeemed
    case notSignedIn
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "このコードは見つかりません"
        case .inactive: return "このコードは現在利用できません"
        case .expired: return "このコードの有効期限が切れています"
        case .capacityReached: return "申し訳ありません、先着枠が終了しました"
        case .alreadyRedeemed: return "このコードはすでに使用済みです"
        case .notSignedIn: return "ログインが必要です"
        case .unknown(let msg): return msg
        }
    }
}

actor PromoCodeService {
    private var _db: Firestore?
    private var db: Firestore {
        if let d = _db { return d }
        let i = Firestore.firestore()
        _db = i
        return i
    }

    func getLifetimePremium(userId: String) async -> Bool {
        guard !userId.isEmpty else { return false }
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return (doc.data()?["lifetimePremium"] as? Bool) ?? false
        } catch {
            print("[PromoCodeService] getLifetimePremium error: \(error)")
            return false
        }
    }

    func redeem(code rawCode: String, userId: String) async throws {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw PromoCodeError.notFound }
        guard !userId.isEmpty else { throw PromoCodeError.notSignedIn }

        let promoRef = db.collection("promoCodes").document(code)
        let redemptionId = "\(userId)_\(code)"
        let redemptionRef = db.collection("redemptions").document(redemptionId)
        let userRef = db.collection("users").document(userId)

        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let promoSnap: DocumentSnapshot
                do {
                    promoSnap = try transaction.getDocument(promoRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                guard promoSnap.exists, let data = promoSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "PromoCode", code: 1)
                    return nil
                }

                let isActive = data["isActive"] as? Bool ?? true
                if !isActive {
                    errorPointer?.pointee = NSError(domain: "PromoCode", code: 2)
                    return nil
                }

                if let expiresAt = data["expiresAt"] as? TimeInterval,
                   expiresAt > 0,
                   Date().timeIntervalSince1970 > expiresAt {
                    errorPointer?.pointee = NSError(domain: "PromoCode", code: 3)
                    return nil
                }

                let maxRedemptions = data["maxRedemptions"] as? Int ?? Int.max
                let current = data["currentRedemptions"] as? Int ?? 0
                if current >= maxRedemptions {
                    errorPointer?.pointee = NSError(domain: "PromoCode", code: 4)
                    return nil
                }

                let redemptionSnap: DocumentSnapshot
                do {
                    redemptionSnap = try transaction.getDocument(redemptionRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                if redemptionSnap.exists {
                    errorPointer?.pointee = NSError(domain: "PromoCode", code: 5)
                    return nil
                }

                let now = Date().timeIntervalSince1970
                transaction.setData([
                    "userId": userId,
                    "code": code,
                    "redeemedAt": now
                ], forDocument: redemptionRef)

                transaction.updateData([
                    "currentRedemptions": current + 1
                ], forDocument: promoRef)

                transaction.setData([
                    "lifetimePremium": true,
                    "lifetimePremiumCode": code,
                    "lifetimePremiumGrantedAt": now
                ], forDocument: userRef, merge: true)

                return nil
            }
        } catch let error as NSError {
            if error.domain == "PromoCode" {
                switch error.code {
                case 1: throw PromoCodeError.notFound
                case 2: throw PromoCodeError.inactive
                case 3: throw PromoCodeError.expired
                case 4: throw PromoCodeError.capacityReached
                case 5: throw PromoCodeError.alreadyRedeemed
                default: break
                }
            }
            print("[PromoCodeService] redeem error: \(error)")
            throw PromoCodeError.unknown(error.localizedDescription)
        }
    }
}
