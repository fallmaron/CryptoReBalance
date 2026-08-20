enum StorageLocation {
  nx('NX'),
  le('LE'),
  tr('TR'),
  rk('RK');

  const StorageLocation(this.code);

  final String code;

  static StorageLocation fromCode(String code) {
    return StorageLocation.values.firstWhere(
      (location) => location.code == code,
      orElse: () => throw ArgumentError('Unknown location: $code'),
    );
  }
}
