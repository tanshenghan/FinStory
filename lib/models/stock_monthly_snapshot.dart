class StockMonthlySnapshot {
  const StockMonthlySnapshot({
    required this.month,
    required this.marketValue,
    required this.cashBalance,
    required this.externalInflow,
    required this.externalOutflow,
    required this.dividendReceived,
    required this.feesAndTaxes,
    this.stockPurchases = 0,
    this.stockSales = 0,
  });

  final DateTime month;
  final double marketValue;
  final double cashBalance;
  final double externalInflow;
  final double externalOutflow;
  final double dividendReceived;
  final double feesAndTaxes;
  final double stockPurchases;
  final double stockSales;

  double get totalAssets => marketValue + cashBalance;

  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'month': monthKey,
    'marketValue': marketValue,
    'cashBalance': cashBalance,
    'externalInflow': externalInflow,
    'externalOutflow': externalOutflow,
    'dividendReceived': dividendReceived,
    'feesAndTaxes': feesAndTaxes,
    'stockPurchases': stockPurchases,
    'stockSales': stockSales,
  };

  factory StockMonthlySnapshot.fromJson(Map<String, dynamic> json) {
    final parts = (json['month'] as String).split('-');
    return StockMonthlySnapshot(
      month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
      marketValue: (json['marketValue'] as num).toDouble(),
      cashBalance: (json['cashBalance'] as num).toDouble(),
      externalInflow: (json['externalInflow'] as num?)?.toDouble() ?? 0,
      externalOutflow: (json['externalOutflow'] as num?)?.toDouble() ?? 0,
      dividendReceived: (json['dividendReceived'] as num?)?.toDouble() ?? 0,
      feesAndTaxes: (json['feesAndTaxes'] as num?)?.toDouble() ?? 0,
      stockPurchases: (json['stockPurchases'] as num?)?.toDouble() ?? 0,
      stockSales: (json['stockSales'] as num?)?.toDouble() ?? 0,
    );
  }
}
