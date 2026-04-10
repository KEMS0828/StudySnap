import SwiftUI
import RevenueCat

struct StudySnapPaywallView: View {
    var store: StoreViewModel
    var dailyUsedTime: TimeInterval = 0
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    featuresSection
                    packagesSection
                    purchaseButton
                    footerSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
            )) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
            .task {
                if store.offerings == nil {
                    await store.fetchOfferings()
                }
                if selectedPackage == nil {
                    selectedPackage = store.offerings?.current?.availablePackages.first
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)

            Text("StudySnap Pro")
                .font(.title.bold())

            Text("もっと集中、もっと成長")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !store.isPremium {
                let remaining = max(0, store.freeDailyLimit - dailyUsedTime)
                let mins = Int(remaining) / 60
                let secs = Int(remaining) % 60
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    if remaining > 0 {
                        Text("今日の残り: \(mins)分\(secs)秒")
                            .font(.subheadline.bold())
                    } else {
                        Text("今日の無料枠を使い切りました")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundStyle(remaining <= 600 ? .orange : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(remaining <= 600 ? Color.orange.opacity(0.1) : Color(.tertiarySystemBackground), in: Capsule())
            }
        }
        .padding(.bottom, 24)
    }

    private var featuresSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "infinity")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 20)

            Text("勉強時間が無制限に")
                .font(.title3.bold())

            Text("毎日1時間の制限がなくなり、\n無制限に勉強を記録できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.08), .yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var packagesSection: some View {
        VStack(spacing: 10) {
            if store.isLoading {
                ProgressView()
                    .padding(.vertical, 40)
            } else if let packages = store.offerings?.current?.availablePackages, !packages.isEmpty {
                ForEach(packages, id: \.identifier) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedPackage = package
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("プランを読み込めませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let diagnostic = store.offeringsDiagnostic {
                        Text(diagnostic)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    if let error = store.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    Button("再試行") {
                        Task { await store.fetchOfferings() }
                    }
                    .font(.subheadline.bold())
                }
                .padding(.vertical, 30)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                guard let package = selectedPackage else { return }
                Task { await store.purchase(package: package) }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("プランに登録する")
                            .font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 14)
                )
                .foregroundStyle(.white)
            }
            .disabled(selectedPackage == nil || store.isPurchasing)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("購入を復元") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let pkg = selectedPackage {
                VStack(spacing: 4) {
                    Text("\(pkg.storeProduct.localizedTitle) — \(subscriptionPeriodText(for: pkg))")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text("\(pkg.storeProduct.localizedPriceString) / \(subscriptionPeriodShort(for: pkg))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            Text("サブスクリプションは自動更新されます。期間終了の24時間前までにキャンセルしない限り自動更新されます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 4) {
                NavigationLink("利用規約") {
                    TermsOfServiceView()
                }
                Text("・")
                    .foregroundStyle(.tertiary)
                NavigationLink("プライバシーポリシー") {
                    PrivacyPolicyView()
                }
                Text("・")
                    .foregroundStyle(.tertiary)
                Link("EULA", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 24)
    }

    private func subscriptionPeriodText(for package: Package) -> String {
        switch package.packageType {
        case .annual: return "年額自動更新サブスクリプション"
        case .monthly: return "月額自動更新サブスクリプション"
        case .weekly: return "週額自動更新サブスクリプション"
        case .twoMonth: return "2ヶ月自動更新サブスクリプション"
        case .threeMonth: return "3ヶ月自動更新サブスクリプション"
        case .sixMonth: return "6ヶ月自動更新サブスクリプション"
        default:
            if package.identifier.lowercased().contains("year") { return "年額自動更新サブスクリプション" }
            if package.identifier.lowercased().contains("month") { return "月額自動更新サブスクリプション" }
            return "自動更新サブスクリプション"
        }
    }

    private func subscriptionPeriodShort(for package: Package) -> String {
        switch package.packageType {
        case .annual: return "年"
        case .monthly: return "月"
        case .weekly: return "週"
        case .twoMonth: return "2ヶ月"
        case .threeMonth: return "3ヶ月"
        case .sixMonth: return "6ヶ月"
        default:
            if package.identifier.lowercased().contains("year") { return "年" }
            if package.identifier.lowercased().contains("month") { return "月" }
            return "期間"
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.bold())
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    private var isYearly: Bool {
        package.packageType == .annual || package.identifier.lowercased().contains("year")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color(.separator), lineWidth: isSelected ? 2.5 : 1.5)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(package.storeProduct.localizedTitle.isEmpty ? (isYearly ? "年額プラン" : "月額プラン") : package.storeProduct.localizedTitle)
                            .font(.subheadline.bold())

                        if isYearly {
                            Text("おトク")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isYearly, let monthlyPrice = monthlyEquivalent {
                        Text("月あたり \(monthlyPrice)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(package.storeProduct.localizedPriceString)
                    .font(.body.bold())
                    .foregroundStyle(isSelected ? .orange : .primary)
            }
            .padding(16)
            .background(
                isSelected ? Color.orange.opacity(0.06) : Color(.secondarySystemGroupedBackground),
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var periodLabel: String {
        switch package.packageType {
        case .annual: return "1年間 ・ 自動更新"
        case .monthly: return "1ヶ月間 ・ 自動更新"
        case .weekly: return "1週間 ・ 自動更新"
        case .twoMonth: return "2ヶ月間 ・ 自動更新"
        case .threeMonth: return "3ヶ月間 ・ 自動更新"
        case .sixMonth: return "6ヶ月間 ・ 自動更新"
        default:
            if package.identifier.lowercased().contains("year") { return "1年間 ・ 自動更新" }
            if package.identifier.lowercased().contains("month") { return "1ヶ月間 ・ 自動更新" }
            return "自動更新"
        }
    }

    private var monthlyEquivalent: String? {
        let price = package.storeProduct.price as Decimal
        guard price > 0 else { return nil }
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? .current
        return formatter.string(from: monthly as NSDecimalNumber)
    }
}
