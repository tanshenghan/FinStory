class FinancialPositionSnapshot {
  const FinancialPositionSnapshot({
    required this.month,
    required this.cashAndDeposits,
    required this.physicalAssets,
    required this.receivablesAndOtherAssets,
    required this.shortTermLiabilities,
    required this.longTermLiabilities,
    this.tracksTransactions = false,
  });

  final DateTime month;
  final double cashAndDeposits;
  final double physicalAssets;
  final double receivablesAndOtherAssets;
  final double shortTermLiabilities;
  final double longTermLiabilities;
  final bool tracksTransactions;

  double get nonStockAssets =>
      cashAndDeposits + physicalAssets + receivablesAndOtherAssets;
  double get totalLiabilities => shortTermLiabilities + longTermLiabilities;
  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'month': monthKey,
    'cashAndDeposits': cashAndDeposits,
    'physicalAssets': physicalAssets,
    'receivablesAndOtherAssets': receivablesAndOtherAssets,
    'shortTermLiabilities': shortTermLiabilities,
    'longTermLiabilities': longTermLiabilities,
    'tracksTransactions': tracksTransactions,
  };

  factory FinancialPositionSnapshot.fromJson(Map<String, dynamic> json) {
    final parts = (json['month'] as String).split('-');
    return FinancialPositionSnapshot(
      month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
      cashAndDeposits: (json['cashAndDeposits'] as num?)?.toDouble() ?? 0,
      physicalAssets: (json['physicalAssets'] as num?)?.toDouble() ?? 0,
      receivablesAndOtherAssets:
          (json['receivablesAndOtherAssets'] as num?)?.toDouble() ?? 0,
      shortTermLiabilities:
          (json['shortTermLiabilities'] as num?)?.toDouble() ?? 0,
      longTermLiabilities:
          (json['longTermLiabilities'] as num?)?.toDouble() ?? 0,
      tracksTransactions: json['tracksTransactions'] as bool? ?? false,
    );
  }
}
