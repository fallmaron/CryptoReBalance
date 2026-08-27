import 'storage_location.dart';

class RebalanceProfit {
  const RebalanceProfit({
    this.id,
    required this.recordedAt,
    required this.location,
    this.holdingId,
    required this.sessionStartedAt,
    required this.sessionEndedAt,
    required this.sessionStartId,
    required this.sessionEndId,
    required this.withUsdt,
    required this.withoutUsdt,
    required this.profitUsdt,
  });

  final int? id;
  final DateTime recordedAt;
  final StorageLocation location;
  final int? holdingId;
  final DateTime sessionStartedAt;
  final DateTime sessionEndedAt;
  final int sessionStartId;
  final int sessionEndId;
  final double withUsdt;
  final double withoutUsdt;
  final double profitUsdt;

  bool belongsTo(int holdingRecordId) => holdingId == holdingRecordId;
}
