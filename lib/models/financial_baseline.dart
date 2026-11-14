class FinancialBaseline {
  const FinancialBaseline({
    required this.effectiveDate,
    required this.cashAndDeposits,
    required this.physicalAssets,
    required this.receivablesAndOtherAssets,
    required this.shortTermLiabilities,
    required this.longTermLiabilities,
  });

  final DateTime effectiveDate;
  final double cashAndDeposits;
  final double physicalAssets;
  final double receivablesAndOtherAssets;
  final double shortTermLiabilities;
  final double longTermLiabilities;

  double get totalLiabilities => shortTermLiabilities + longTermLiabilities;

  Map<String, dynamic> toJson() => {
    'effectiveDate': effectiveDate.toIso8601String(),
    'cashAndDeposits': cashAndDeposits,
    'physicalAssets': physicalAssets,
    'receivablesAndOtherAssets': receivablesAndOtherAssets,
    'shortTermLiabilities': shortTermLiabilities,
    'longTermLiabilities': longTermLiabilities,
  };

  factory FinancialBaseline.fromJson(Map<String, dynamic> json) =>
      FinancialBaseline(
        effectiveDate: DateTime.parse(json['effectiveDate'] as String),
        cashAndDeposits: (json['cashAndDeposits'] as num?)?.toDouble() ?? 0,
        physicalAssets: (json['physicalAssets'] as num?)?.toDouble() ?? 0,
        receivablesAndOtherAssets:
            (json['receivablesAndOtherAssets'] as num?)?.toDouble() ?? 0,
        shortTermLiabilities:
            (json['shortTermLiabilities'] as num?)?.toDouble() ?? 0,
        longTermLiabilities:
            (json['longTermLiabilities'] as num?)?.toDouble() ?? 0,
      );
}
