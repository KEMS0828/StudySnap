# レポート画面の修正：ラベル変更と連続勉強日数の計算修正

## 変更内容

### 1. 「今週の勉強時間」→「1週間の勉強時間」に変更

- レポート画面の棒グラフのタイトルを「1週間の勉強時間」に修正
- ReportView と MemberReportView の両方で変更

### 2. 連続勉強日数をアプリ内の記録のみで計算するように修正

- 現在：アプリ内＋アプリ外の全セッションで連続日数を計算している
- 修正後：アプリ内（`isExternal == false`）のセッションのみで計算
- DataStore の `currentStreak` と `longestStreak` の両方を修正
- MemberReportView の `memberStreak` も同様に修正

