import SwiftUI
import RevenueCat

struct SubscriptionManagementView: View {
    var store: StoreViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("StudySnap Pro")
                                .font(.headline)

                            if store.lifetimePremium && !store.subscriptionPremium {
                                Text("プロモコード適用中")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if store.isPremium {
                                if let expDate = store.subscriptionExpirationDate {
                                    Text(store.willRenew ? "次回更新: \(expDate.formatted(date: .abbreviated, time: .omitted))" : "有効期限: \(expDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        Text("有効")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                }

                if store.lifetimePremium && !store.subscriptionPremium {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("プロモコードでProが有効になっているため、Appleの設定にサブスクリプションは表示されません。支払いや更新の手続きは不要です。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    } label: {
                        Label("Appleでサブスクリプションを管理", systemImage: "arrow.up.forward.app")
                    }

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Label("購入を復元", systemImage: "arrow.clockwise")
                    }
                } footer: {
                    Text("サブスクリプションのキャンセルや変更はAppleの設定から行えます。")
                }
            }
            .navigationTitle("サブスクリプション")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
