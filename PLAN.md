# Firebase/RevenueCat SDKを最新版にアップデートしてiOS 26起動クラッシュを修正

## 問題の原因

Firebase SDK 11.x は iOS 26.4 で起動時にクラッシュする既知のバグがあります。このバグは Firebase 12.12.0 で修正済みです。今までコードを修正しても治らなかったのは、**SDK自体のバグ**だったためです。

## 修正内容

- **Firebase SDK を 11.x → 12.x にアップデート**（iOS 26.4 起動クラッシュの修正を含む最新版）
- **RevenueCat SDK を最新版にアップデート**（iOS 26 互換性修正を含む）
- **GoogleSignIn SDK を最新版にアップデート**（iOS 26 互換性確保）
- **起動時の初期化コードに防御的な処理を追加**（万が一SDKの初期化が失敗してもアプリが落ちないようにする）
- **RevenueCat の URLSession クラッシュ回避策を追加**（iOS 26 で複数ライブラリが URLSession を使う場合のApple既知バグ対策）

## 期待される結果

- iOS 26.4（iPhone 16 Pro、iPad Air M3）での起動時クラッシュが解消
- App Store レビューを通過できるようになる

