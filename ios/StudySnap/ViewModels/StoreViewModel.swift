import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
class StoreViewModel {
    var offerings: Offerings?
    var isPremium = false
    var isLoading = false
    var isPurchasing = false
    var error: String?
    var infoMessage: String?
    var offeringsDiagnostic: String?
    var subscriptionExpirationDate: Date?
    var willRenew = false
    var isConfigured = false

    private let entitlementID = "StudySnap Pro"
    let freeDailyLimit: TimeInterval = 1 * 3600

    private var hasStarted = false

    init() {
        refreshConfigured()
    }

    private func refreshConfigured() {
        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_API_KEY
        isConfigured = !rcKey.isEmpty && Purchases.isConfigured
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        refreshConfigured()
        guard isConfigured else { return }
        hasStarted = true
        Task { [weak self] in await self?.listenForUpdates() }
        Task { [weak self] in await self?.fetchOfferings() }
    }

    private func listenForUpdates() async {
        guard Purchases.isConfigured else { return }
        do {
            for try await info in Purchases.shared.customerInfoStream {
                updatePremiumStatus(from: info)
            }
        } catch is CancellationError {
        } catch {
            print("[StoreViewModel] customerInfoStream error: \(error)")
        }
    }

    func fetchOfferings() async {
        guard isConfigured, Purchases.isConfigured else {
            error = "ストアが設定されていません"
            return
        }
        isLoading = true
        offeringsDiagnostic = nil
        do {
            let fetched = try await Purchases.shared.offerings()
            offerings = fetched

            let allIds = fetched.all.keys.sorted()
            print("[RevenueCat] Offerings fetched: \(allIds)")

            if fetched.current == nil {
                if fetched.all.isEmpty {
                    offeringsDiagnostic = "RevenueCatにOfferingが登録されていません。ダッシュボードでOfferingと商品を設定してください。"
                } else {
                    offeringsDiagnostic = "Offeringはありますが、\"Current\"が未設定です。RevenueCatダッシュボードでCurrent Offeringを設定してください。(offerings: \(allIds.joined(separator: ", ")))"
                }
            } else if let current = fetched.current {
                print("[RevenueCat] Current offering: \(current.identifier), packages: \(current.availablePackages.count)")
                if current.availablePackages.isEmpty {
                    offeringsDiagnostic = "Current Offering (\(current.identifier)) にパッケージがありません。App Store Connectで商品のステータスを確認してください（却下・メタデータ不足の場合は取得できません）。"
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("[RevenueCat] Fetch offerings error: \(error)")
        }
        isLoading = false
    }

    func purchase(package: Package) async {
        guard Purchases.isConfigured else {
            error = "ストアが初期化されていません。アプリを再起動してください。"
            print("[StoreViewModel] purchase failed: Purchases not configured")
            return
        }
        isPurchasing = true
        error = nil
        infoMessage = nil
        print("[StoreViewModel] Starting purchase for: \(package.identifier)")
        do {
            let result = try await Purchases.shared.purchase(package: package)
            print("[StoreViewModel] Purchase result - cancelled: \(result.userCancelled)")
            if result.userCancelled {
                infoMessage = "購入がキャンセルされました。"
            } else {
                updatePremiumStatus(from: result.customerInfo)
                try? await Task.sleep(for: .seconds(1))
                let info = try await Purchases.shared.customerInfo()
                updatePremiumStatus(from: info)
                print("[StoreViewModel] Premium status after purchase: \(isPremium)")

                if !isPremium {
                    let activeEntitlements = info.entitlements.active.keys.joined(separator: ", ")
                    print("[StoreViewModel] Active entitlements: \(activeEntitlements)")
                    print("[StoreViewModel] Expected entitlement: \(entitlementID)")
                    if info.entitlements.active.isEmpty {
                        infoMessage = "購入は完了しましたが、プランがまだ反映されていません。しばらく待ってからアプリを再起動してください。"
                    } else {
                        infoMessage = "購入は完了しましたが、エンタイトルメントID(\"\(entitlementID)\")が一致しません。RevenueCatダッシュボードの設定を確認してください。(active: \(activeEntitlements))"
                    }
                } else {
                    infoMessage = "プランに登録しました！"
                }
            }
        } catch let purchaseError as ErrorCode {
            print("[StoreViewModel] RevenueCat error: \(purchaseError) (\(purchaseError.rawValue))")
            switch purchaseError {
            case .purchaseCancelledError:
                infoMessage = "購入がキャンセルされました。"
            case .paymentPendingError:
                infoMessage = "決済が保留中です。承認されるまでしばらくお待ちください。"
            case .storeProblemError:
                self.error = "App Storeに一時的な問題が発生しています。しばらくしてからお試しください。"
            case .networkError:
                self.error = "ネットワークエラーが発生しました。接続を確認してもう一度お試しください。"
            case .purchaseNotAllowedError:
                self.error = "このデバイスでは購入が許可されていません。設定を確認してください。"
            case .purchaseInvalidError:
                self.error = "無効な購入です。App Store Connectの商品設定を確認してください。"
            default:
                self.error = "購入エラー(\(purchaseError.rawValue)): \(purchaseError.localizedDescription)"
            }
        } catch {
            print("[StoreViewModel] Purchase error: \(error)")
            self.error = "購入処理中にエラーが発生しました: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    func restore() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updatePremiumStatus(from: info)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkStatus() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            updatePremiumStatus(from: info)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func canStartStudy(dailyStudyTime: TimeInterval) -> Bool {
        if isPremium { return true }
        return dailyStudyTime < freeDailyLimit
    }

    private func updatePremiumStatus(from info: CustomerInfo) {
        let entitlement = info.entitlements[entitlementID]
        isPremium = entitlement?.isActive == true
        subscriptionExpirationDate = entitlement?.expirationDate
        willRenew = entitlement?.willRenew == true
    }
}
