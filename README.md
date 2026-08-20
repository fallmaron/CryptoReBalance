# CryptReBalance

BTC 70% / HYPE 15% / USDT 15% の保有バランスを、保管場所（NX / LE / TR / RK）ごとの履歴から管理する Android 向け Flutter アプリです。

## できること

- 保管場所ごとに現在の保有量を登録し、日時（秒まで）付きの履歴として保存する
- CoinMarketCap の listings/latest から USDT 建てレートを取得する
- 直近保有量とレートから総資産を計算し、目標配分との差分（通貨量・USDT 換算）を表示する
- 「更新」でレート再取得と再計算を行う

## 実行

CoinMarketCap の API キーは `lib/core/constants/api_keys.dart` に置きます。このファイルは Git 管理対象外です。初回のみ example をコピーしてキーを入れてください。

```bash
cp lib/core/constants/api_keys.dart.example lib/core/constants/api_keys.dart
flutter pub get
flutter test
flutter run
```
