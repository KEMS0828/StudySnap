# 起動時クラッシュの修正（レースコンディション対策）

## 修正内容

### 1. BlockService のシングルトン使用方法の修正

- タイムライン画面で `BlockService.shared` を `@State` で保持する誤ったパターンを修正
- `@State` の代わりに直接参照（`let`）を使用し、SwiftUI の observation 競合を防止

### 2. DataStore の起動処理を安全に

- 起動時のデータ読み込み（ユーザー情報、グループ、投稿など）にエラーハンドリングを強化
- 非構造化 `Task {}` 内のクラッシュを防ぐため、各読み込み処理を `do/catch` で保護

### 3. RevenueCat の安全な初期化

- `customerInfoStream` のイテレーションにエラーハンドリングを追加
- RevenueCat が完全に設定される前のアクセスを防止するガードを強化

### 4. 配列アクセスの安全性向上

- 投稿の承認処理で `photoApproved`、`photoApprovedByNames`、`photoApprovedAt` 配列のサイズが `photoUrls` と一致しない場合の防御コードを追加
- Firestore からのデータ読み込み時に配列サイズの整合性チェックを追加

### 影響範囲

- 起動フローの安定性が向上
- 既存の機能・デザインへの変更なし
- ユーザー体験に変更なし（クラッシュが解消されるだけ）

