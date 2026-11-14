import 'package:flutter/material.dart';

enum EntryType { expense, income, investment }

enum InvestmentDirection { deposit, withdraw }

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.account,
    required this.date,
    this.note = '',
    this.specialActionId,
    this.isDepreciable = false,
    this.depreciationMonths = 36,
    this.residualValue = 0,
    this.disposedAssetId,
    this.investmentDirection,
  });
  final String id;
  final EntryType type;
  final double amount;
  final String category;
  final String account;
  final DateTime date;
  final String note;
  final String? specialActionId;
  final bool isDepreciable;
  final int depreciationMonths;
  final double residualValue;
  final String? disposedAssetId;
  final InvestmentDirection? investmentDirection;

  bool get isStockDeposit =>
      type == EntryType.investment &&
      investmentDirection != InvestmentDirection.withdraw;
  bool get isStockWithdrawal =>
      type == EntryType.investment &&
      investmentDirection == InvestmentDirection.withdraw;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'category': category,
    'account': account,
    'date': date.toIso8601String(),
    'note': note,
    'specialActionId': specialActionId,
    'isDepreciable': isDepreciable,
    'depreciationMonths': depreciationMonths,
    'residualValue': residualValue,
    'disposedAssetId': disposedAssetId,
    'investmentDirection': investmentDirection?.name,
  };
  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    var type = switch (json['type']) {
      'income' => EntryType.income,
      'investment' => EntryType.investment,
      _ => EntryType.expense,
    };
    var category = json['category'] as String;
    InvestmentDirection? investmentDirection =
        switch (json['investmentDirection']) {
          'withdraw' => InvestmentDirection.withdraw,
          'deposit' => InvestmentDirection.deposit,
          _ => null,
        };
    if (type == EntryType.expense && category == '股票投资') {
      type = EntryType.investment;
      investmentDirection = InvestmentDirection.deposit;
    }
    if (type == EntryType.expense && category == '人情') {
      category = '资本投入';
    } else if (type == EntryType.income && category == '投资') {
      category = '资本获利';
    } else if (type == EntryType.income && category == '退款') {
      category = '其他';
    }
    return LedgerEntry(
      id: json['id'] as String,
      type: type,
      amount: (json['amount'] as num).toDouble(),
      category: category,
      account: json['account'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
      specialActionId: json['specialActionId'] as String?,
      isDepreciable: json['isDepreciable'] as bool? ?? false,
      depreciationMonths: (json['depreciationMonths'] as num?)?.toInt() ?? 36,
      residualValue: (json['residualValue'] as num?)?.toDouble() ?? 0,
      disposedAssetId: json['disposedAssetId'] as String?,
      investmentDirection: type == EntryType.investment
          ? investmentDirection ?? InvestmentDirection.deposit
          : null,
    );
  }
}

const expenseCategories = <String>[
  '餐饮',
  '交通',
  '购物',
  '居住',
  '娱乐',
  '医疗',
  '教育',
  '通讯',
  '资本投入',
  '其他',
];
const incomeCategories = <String>['工资', '奖金', '资本获利', '兼职', '红包', '其他'];
const accounts = <String>['微信', '支付宝', '银行卡', '现金', '信用卡'];

IconData categoryIcon(String category) => switch (category) {
  '特别行动' => Icons.rocket_launch_rounded,
  '餐饮' => Icons.restaurant_rounded,
  '交通' => Icons.directions_subway_rounded,
  '购物' => Icons.shopping_bag_rounded,
  '居住' => Icons.home_rounded,
  '娱乐' => Icons.sports_esports_rounded,
  '医疗' => Icons.medical_services_rounded,
  '教育' => Icons.school_rounded,
  '通讯' => Icons.phone_iphone_rounded,
  '资本投入' => Icons.savings_rounded,
  '股票投资' => Icons.candlestick_chart_rounded,
  '红包' => Icons.redeem_rounded,
  '工资' => Icons.account_balance_wallet_rounded,
  '奖金' => Icons.workspace_premium_rounded,
  '资本获利' => Icons.trending_up_rounded,
  '兼职' => Icons.work_history_rounded,
  _ => Icons.more_horiz_rounded,
};
