# App Store審査リジェクト対応（3.1.2c + 2.1）

## リジェクト理由と対応

### 1. Guideline 3.1.2(c) — サブスクリプション情報の不足

**対応（App Store Connect側 — あなたが手動で行う作業）：**

- App Store Connectの「アプリ情報」→「プライバシーポリシー」フィールドにURLを設定
- App Store Connectの「アプリ情報」→「EULA」にApple標準EULAを使用するか、カスタムEULAのURLを設定
- アプリの説明文の末尾に以下を追記：
  ```
  利用規約(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
  プライバシーポリシー: [あなたのURL]
  ```

**対応（アプリ内 — コード変更）：**

- ペイウォール画面のフッターに、サブスクリプションの詳細情報をより明確に表示
  - サブスクリプション名（例: "StudySnap Pro 月額プラン"）
  - 期間と価格（例: "¥480/月"）
  - 自動更新の説明
  - プライバシーポリシーとEULAへのリンク（既にあるが、より見やすく）

### 2. Guideline 2.1 — PassKitフレームワークの問題

**状況：** PassKitはRevenueCat SDKの依存関係として自動的にバイナリに含まれています。アプリはサブスクリプション（IAP）のみで、Apple Payでの直接決済は不要です（StoreKitの購入フローでユーザーのApple Pay設定が自動的に使われます）。

**対応（App Review返信 — あなたが手動で行う作業）：**

- App Reviewに返信して以下を説明：
  > "The PassKit framework is included as a transitive dependency of the RevenueCat SDK (purchases-ios-spm), which we use for subscription management. Our app does not directly implement Apple Pay — all payments are processed through StoreKit In-App Purchases. Users who have Apple Pay configured as their Apple ID payment method can already use it during the StoreKit purchase flow."

### まとめ

- **コード変更**: ペイウォールのフッターにサブスク情報をより詳細に表示
- **あなたの作業**: App Store Connectでプライバシーポリシー/EULA URLを設定 + アプリ説明文に追記 + App Reviewに返信

