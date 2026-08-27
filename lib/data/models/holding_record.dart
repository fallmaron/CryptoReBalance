import 'crypto_asset.dart';
import 'holding_entry_kind.dart';
import 'storage_location.dart';

class HoldingRecord {
  const HoldingRecord({
    this.id,
    required this.recordedAt,
    required this.location,
    required this.amounts,
    this.kind = HoldingEntryKind.locationMove,
  });

  final int? id;
  final DateTime recordedAt;
  final StorageLocation location;
  final Map<CryptoAsset, double> amounts;
  final HoldingEntryKind kind;

  double amountOf(CryptoAsset asset) => amounts[asset] ?? 0;

  HoldingRecord copyWith({
    int? id,
    DateTime? recordedAt,
    StorageLocation? location,
    Map<CryptoAsset, double>? amounts,
    HoldingEntryKind? kind,
  }) {
    return HoldingRecord(
      id: id ?? this.id,
      recordedAt: recordedAt ?? this.recordedAt,
      location: location ?? this.location,
      amounts: amounts ?? this.amounts,
      kind: kind ?? this.kind,
    );
  }
}
