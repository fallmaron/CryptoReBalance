enum HoldingEntryKind {
  locationMove('location_move', '場所移動'),
  rebalance('rebalance', 'リバランス');

  const HoldingEntryKind(this.code, this.label);

  final String code;
  final String label;

  static HoldingEntryKind fromCode(String? code) {
    return HoldingEntryKind.values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => HoldingEntryKind.locationMove,
    );
  }
}
