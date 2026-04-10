# RevenueCat APIキーの参照先を修正

**問題**
コードが存在しないキー名（`EXPO_PUBLIC_REVENUECAT_IOS_API_KEY` / `EXPO_PUBLIC_REVENUECAT_TEST_API_KEY`）を探しているため、本番用APIキー（`EXPO_PUBLIC_REVENUECAT_API_KEY`）が使われていません。結果としてRevenueCatが正しく初期化されず、価格がドル表示のままになっています。

**修正内容**

- アプリ起動時のRevenueCat初期化コードで、`EXPO_PUBLIC_REVENUECAT_API_KEY` を使うように変更
- ストア画面の設定確認コードでも同様に修正
- これにより、環境変数に設定した本番用APIキーが正しく読み込まれ、日本円で価格が表示されるようになります

