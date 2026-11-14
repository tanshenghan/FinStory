import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/financial_baseline.dart';
import '../models/ledger_entry.dart';
import '../models/financial_position_snapshot.dart';
import '../models/special_action.dart';
import '../models/stock_monthly_snapshot.dart';

class LedgerStore extends ChangeNotifier {
  static const _entriesKey = 'ledger_entries_v1';
  static const _budgetKey = 'monthly_budget_v1';
  static const _specialActionsKey = 'special_actions_v1';
  static const _stockSnapshotsKey = 'stock_snapshots_v1';
  static const _financialPositionsKey = 'financial_positions_v1';
  static const _financialBaselineKey = 'financial_baseline_v1';
  final List<LedgerEntry> _entries = [];
  final List<SpecialAction> _specialActions = [];
  final List<StockMonthlySnapshot> _stockSnapshots = [];
  final List<FinancialPositionSnapshot> _financialPositions = [];
  FinancialBaseline? _financialBaseline;
  double _monthlyBudget = 5000;

  List<LedgerEntry> get entries => List.unmodifiable(_entries);
  List<SpecialAction> get specialActions => List.unmodifiable(_specialActions);
  List<StockMonthlySnapshot> get stockSnapshots =>
      List.unmodifiable(_stockSnapshots);
  List<FinancialPositionSnapshot> get financialPositions =>
      List.unmodifiable(_financialPositions);
  FinancialBaseline? get financialBaseline => _financialBaseline;
  double get monthlyBudget => _monthlyBudget;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 5000;
    final actionsRaw = prefs.getString(_specialActionsKey);
    if (actionsRaw != null) {
      final decodedActions = jsonDecode(actionsRaw) as List<dynamic>;
      _specialActions.addAll(
        decodedActions.map(
          (item) => SpecialAction.fromJson(item as Map<String, dynamic>),
        ),
      );
    }
    final stockRaw = prefs.getString(_stockSnapshotsKey);
    if (stockRaw != null) {
      final decodedSnapshots = jsonDecode(stockRaw) as List<dynamic>;
      _stockSnapshots.addAll(
        decodedSnapshots.map(
          (item) => StockMonthlySnapshot.fromJson(item as Map<String, dynamic>),
        ),
      );
      _stockSnapshots.sort((a, b) => a.month.compareTo(b.month));
    }
    final positionsRaw = prefs.getString(_financialPositionsKey);
    if (positionsRaw != null) {
      final decodedPositions = jsonDecode(positionsRaw) as List<dynamic>;
      _financialPositions.addAll(
        decodedPositions.map(
          (item) =>
              FinancialPositionSnapshot.fromJson(item as Map<String, dynamic>),
        ),
      );
      _financialPositions.sort((a, b) => a.month.compareTo(b.month));
    }
    final baselineRaw = prefs.getString(_financialBaselineKey);
    if (baselineRaw != null) {
      _financialBaseline = FinancialBaseline.fromJson(
        jsonDecode(baselineRaw) as Map<String, dynamic>,
      );
    }
    final raw = prefs.getString(_entriesKey);
    if (raw == null) {
      await _migrateLegacyBaseline();
      await _save();
      return;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    _entries.addAll(
      decoded.map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>)),
    );
    _entries.removeWhere((entry) => entry.id.startsWith('seed-'));
    _sort();
    await _migrateLegacyBaseline();
    await _save();
  }

  Future<void> _migrateLegacyBaseline() async {
    if (_financialBaseline != null || _financialPositions.isEmpty) return;
    final legacy = _financialPositions.last;
    final effectiveDate = DateTime(legacy.month.year, legacy.month.month);
    final monthCashMovement = freeCashFlowForMonth(legacy.month);
    final generatedAssets = depreciableAssetValueForMonth(legacy.month);
    _financialBaseline = FinancialBaseline(
      effectiveDate: effectiveDate,
      cashAndDeposits: legacy.tracksTransactions
          ? legacy.cashAndDeposits
          : legacy.cashAndDeposits - monthCashMovement,
      physicalAssets: legacy.tracksTransactions
          ? legacy.physicalAssets
          : (legacy.physicalAssets - generatedAssets).clamp(0, double.infinity),
      receivablesAndOtherAssets: legacy.receivablesAndOtherAssets,
      shortTermLiabilities: legacy.shortTermLiabilities,
      longTermLiabilities: legacy.longTermLiabilities,
    );
    await _saveFinancialBaseline();
  }

  Future<void> add(LedgerEntry entry) async {
    _entries.add(entry);
    _sort();
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> setBudget(double value) async {
    _monthlyBudget = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, value);
  }

  Future<SpecialAction> addSpecialAction(String name) async {
    final normalized = name.trim();
    for (final action in _specialActions) {
      if (action.name == normalized) return action;
    }
    final action = SpecialAction(
      id: 'action-${DateTime.now().microsecondsSinceEpoch}',
      name: normalized,
      createdAt: DateTime.now(),
    );
    _specialActions.add(action);
    notifyListeners();
    await _saveSpecialActions();
    return action;
  }

  Future<void> upsertStockSnapshot(StockMonthlySnapshot snapshot) async {
    _stockSnapshots.removeWhere((item) => item.monthKey == snapshot.monthKey);
    _stockSnapshots.add(snapshot);
    _stockSnapshots.sort((a, b) => a.month.compareTo(b.month));
    notifyListeners();
    await _saveStockSnapshots();
  }

  Future<void> upsertFinancialPosition(
    FinancialPositionSnapshot snapshot,
  ) async {
    _financialPositions.removeWhere(
      (item) => item.monthKey == snapshot.monthKey,
    );
    _financialPositions.add(snapshot);
    _financialPositions.sort((a, b) => a.month.compareTo(b.month));
    notifyListeners();
    await _saveFinancialPositions();
  }

  Future<void> setFinancialBaseline(FinancialBaseline baseline) async {
    _financialBaseline = baseline;
    notifyListeners();
    await _saveFinancialBaseline();
  }

  FinancialPositionSnapshot? financialPositionForMonth(DateTime month) {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    for (final snapshot in _financialPositions) {
      if (snapshot.monthKey == key) return snapshot;
    }
    return null;
  }

  FinancialPositionSnapshot? previousFinancialPosition(DateTime month) {
    FinancialPositionSnapshot? result;
    for (final snapshot in _financialPositions) {
      if (snapshot.month.isBefore(DateTime(month.year, month.month))) {
        result = snapshot;
      }
    }
    return result;
  }

  StockMonthlySnapshot? stockSnapshotForMonth(DateTime month) {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    for (final snapshot in _stockSnapshots) {
      if (snapshot.monthKey == key) return snapshot;
    }
    return null;
  }

  StockMonthlySnapshot? previousStockSnapshot(DateTime month) {
    StockMonthlySnapshot? result;
    for (final snapshot in _stockSnapshots) {
      if (snapshot.month.isBefore(DateTime(month.year, month.month))) {
        result = snapshot;
      }
    }
    return result;
  }

  double stockProfitFor(StockMonthlySnapshot snapshot) {
    final previous = previousStockSnapshot(snapshot.month);
    if (previous == null) return 0;
    final previousAssets = previous.totalAssets;
    return snapshot.totalAssets -
        previousAssets -
        snapshot.externalInflow +
        snapshot.externalOutflow;
  }

  double stockPriceAndTradingProfitFor(StockMonthlySnapshot snapshot) =>
      stockProfitFor(snapshot) -
      snapshot.dividendReceived +
      snapshot.feesAndTaxes;

  double totalAssetsForMonth(DateTime month) {
    return totalAssetsAt(DateTime(month.year, month.month + 1, 0, 23, 59, 59));
  }

  double totalAssetsAt(DateTime asOf) {
    final baseline = _financialBaseline;
    final legacy = financialPositionForMonth(asOf);
    return cashAndDepositsAt(asOf) +
        (baseline?.physicalAssets ?? legacy?.physicalAssets ?? 0) +
        (baseline?.receivablesAndOtherAssets ??
            legacy?.receivablesAndOtherAssets ??
            0) +
        depreciableAssetValueAt(asOf) +
        stockAccountAssetsAt(asOf);
  }

  StockMonthlySnapshot? latestStockSnapshotAt(DateTime asOf) {
    final month = DateTime(asOf.year, asOf.month);
    StockMonthlySnapshot? result;
    for (final snapshot in _stockSnapshots) {
      if (!snapshot.month.isAfter(month)) result = snapshot;
    }
    return result;
  }

  double stockAccountAssetsAt(DateTime asOf) {
    final latest = latestStockSnapshotAt(asOf);
    final firstPendingDate = latest == null
        ? _financialBaseline?.effectiveDate
        : DateTime(latest.month.year, latest.month.month + 1);
    final pending = _entries
        .where(
          (entry) =>
              entry.type == EntryType.investment &&
              !entry.date.isAfter(asOf) &&
              (firstPendingDate == null ||
                  !entry.date.isBefore(firstPendingDate)),
        )
        .fold(
          0.0,
          (sum, entry) =>
              sum + (entry.isStockDeposit ? entry.amount : -entry.amount),
        );
    return (latest?.totalAssets ?? 0) + pending;
  }

  double cashAndDepositsForMonth(DateTime month) =>
      cashAndDepositsAt(DateTime(month.year, month.month + 1, 0, 23, 59, 59));

  double cashAndDepositsAt(DateTime asOf) {
    final baseline = _financialBaseline;
    if (baseline != null) {
      if (asOf.isBefore(baseline.effectiveDate)) return 0;
      return baseline.cashAndDeposits + cumulativeCashMovementAt(asOf);
    }
    final position = financialPositionForMonth(asOf);
    return (position?.cashAndDeposits ?? 0) +
        (position == null || position.tracksTransactions
            ? freeCashFlowForMonth(asOf)
            : 0);
  }

  double cumulativeCashMovementAt(DateTime asOf) {
    final baseline = _financialBaseline;
    return _entries
        .where(
          (entry) =>
              !entry.date.isAfter(asOf) &&
              (baseline == null ||
                  !entry.date.isBefore(baseline.effectiveDate)),
        )
        .fold(0, (sum, entry) => sum + cashMovementForEntry(entry));
  }

  double cashMovementForEntry(LedgerEntry entry) => switch (entry.type) {
    EntryType.income => entry.amount,
    EntryType.expense => -entry.amount,
    EntryType.investment => entry.isStockDeposit ? -entry.amount : entry.amount,
  };

  double freeCashFlowForMonth(DateTime month) =>
      forMonth(month)
          .fold(0, (sum, entry) => sum + cashMovementForEntry(entry));

  double liabilitiesForMonth(DateTime month) =>
      _financialBaseline?.totalLiabilities ??
      financialPositionForMonth(month)?.totalLiabilities ??
      0;

  double netWorthForMonth(DateTime month) =>
      totalAssetsForMonth(month) - liabilitiesForMonth(month);

  double capitalInvestmentForMonth(DateTime month) => forMonth(month)
      .where(
        (entry) =>
            entry.type == EntryType.expense &&
            entry.category == '资本投入' &&
            !entry.isDepreciable,
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  double stockInvestmentForMonth(DateTime month) => forMonth(month)
      .where(
        (entry) => entry.type == EntryType.investment && entry.isStockDeposit,
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  double stockWithdrawalForMonth(DateTime month) => forMonth(month)
      .where(
        (entry) =>
            entry.type == EntryType.investment && entry.isStockWithdrawal,
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  double stockInvestmentSincePreviousSnapshot(DateTime month) {
    final previous = previousStockSnapshot(month);
    final start = previous == null
        ? DateTime(month.year, month.month)
        : DateTime(previous.month.year, previous.month.month + 1);
    final end = DateTime(month.year, month.month + 1);
    return _entries
        .where(
          (entry) =>
              entry.type == EntryType.investment &&
              entry.isStockDeposit &&
              !entry.date.isBefore(start) &&
              entry.date.isBefore(end),
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double stockWithdrawalSincePreviousSnapshot(DateTime month) {
    final previous = previousStockSnapshot(month);
    final start = previous == null
        ? DateTime(month.year, month.month)
        : DateTime(previous.month.year, previous.month.month + 1);
    final end = DateTime(month.year, month.month + 1);
    return _entries
        .where(
          (entry) =>
              entry.type == EntryType.investment &&
              entry.isStockWithdrawal &&
              !entry.date.isBefore(start) &&
              entry.date.isBefore(end),
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  List<LedgerEntry> get depreciableAssets => _entries
      .where(
        (entry) =>
            entry.type == EntryType.expense &&
            entry.category != '股票投资' &&
            entry.isDepreciable,
      )
      .toList();

  LedgerEntry? assetById(String? id) {
    if (id == null) return null;
    for (final entry in depreciableAssets) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  LedgerEntry? disposalForAsset(String assetId) {
    for (final entry in _entries) {
      if (entry.type == EntryType.income && entry.disposedAssetId == assetId) {
        return entry;
      }
    }
    return null;
  }

  List<LedgerEntry> activeDepreciableAssets(DateTime month) =>
      activeDepreciableAssetsAt(DateTime(month.year, month.month + 1, 0));

  List<LedgerEntry> activeDepreciableAssetsAt(DateTime asOf) =>
      depreciableAssets.where((asset) {
        if (asset.date.isAfter(asOf)) return false;
        final disposal = disposalForAsset(asset.id);
        return disposal == null || disposal.date.isAfter(asOf);
      }).toList();

  double monthlyDepreciation(LedgerEntry asset) {
    final depreciableAmount = (asset.amount - asset.residualValue).clamp(
      0,
      asset.amount,
    );
    return depreciableAmount / asset.depreciationMonths;
  }

  double assetBookValueAt(LedgerEntry asset, DateTime month) {
    final elapsed =
        (month.year - asset.date.year) * 12 +
        month.month -
        asset.date.month +
        1;
    if (elapsed <= 0) return asset.amount;
    final months = elapsed.clamp(0, asset.depreciationMonths);
    return (asset.amount - monthlyDepreciation(asset) * months)
        .clamp(asset.residualValue, asset.amount)
        .toDouble();
  }

  double depreciableAssetValueForMonth(DateTime month) =>
      depreciableAssetValueAt(DateTime(month.year, month.month + 1, 0));

  double depreciableAssetValueAt(DateTime asOf) =>
      activeDepreciableAssetsAt(asOf)
          .where(
            (asset) =>
                _financialBaseline == null ||
                !asset.date.isBefore(_financialBaseline!.effectiveDate),
          )
          .fold(0, (sum, asset) => sum + assetBookValueAt(asset, asOf));

  double depreciationExpenseForMonth(DateTime month) => depreciableAssets
      .where((asset) {
        final elapsed =
            (month.year - asset.date.year) * 12 +
            month.month -
            asset.date.month;
        if (elapsed < 0 || elapsed >= asset.depreciationMonths) return false;
        final disposal = disposalForAsset(asset.id);
        return disposal == null ||
            !disposal.date.isBefore(DateTime(month.year, month.month));
      })
      .fold(0, (sum, asset) => sum + monthlyDepreciation(asset));

  double disposalGainLossForMonth(DateTime month) {
    var result = 0.0;
    for (final disposal in forMonth(month).where(
      (entry) =>
          entry.type == EntryType.income && entry.disposedAssetId != null,
    )) {
      final asset = assetById(disposal.disposedAssetId);
      if (asset != null) {
        result += disposal.amount - assetBookValueAt(asset, month);
      }
    }
    return result;
  }

  double recognizedIncomeForMonth(DateTime month) {
    final ordinaryIncome = forMonth(month)
        .where(
          (entry) =>
              entry.type == EntryType.income && entry.disposedAssetId == null,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
    return ordinaryIncome +
        disposalGainLossForMonth(month).clamp(0, double.infinity);
  }

  double recognizedExpenseForMonth(DateTime month) {
    final directExpense = forMonth(month)
        .where(
          (entry) =>
              entry.type == EntryType.expense &&
              entry.category != '股票投资' &&
              !entry.isDepreciable,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final disposalLoss = (-disposalGainLossForMonth(
      month,
    )).clamp(0, double.infinity);
    return directExpense + depreciationExpenseForMonth(month) + disposalLoss;
  }

  double cashMovementForMonth(DateTime month) => freeCashFlowForMonth(month);

  List<LedgerEntry> forMonth(DateTime month) => _entries
      .where(
        (entry) =>
            entry.date.year == month.year && entry.date.month == month.month,
      )
      .toList();
  double totalForMonth(DateTime month, EntryType type) =>
      forMonth(month)
          .where((entry) => entry.type == type)
          .fold(0, (sum, entry) => sum + entry.amount);
  double regularExpenseForMonth(DateTime month) => forMonth(month)
      .where(
        (entry) =>
            entry.type == EntryType.expense &&
            entry.category != '股票投资' &&
            entry.specialActionId == null,
      )
      .fold(0, (sum, entry) => sum + entry.amount);
  double specialExpenseForMonth(DateTime month) => forMonth(month)
      .where(
        (entry) =>
            entry.type == EntryType.expense && entry.specialActionId != null,
      )
      .fold(0, (sum, entry) => sum + entry.amount);
  String? specialActionName(String? id) {
    if (id == null) return null;
    for (final action in _specialActions) {
      if (action.id == id) return action.name;
    }
    return '特别行动';
  }

  double totalForSpecialAction(String id) => _entries
      .where(
        (entry) =>
            entry.type == EntryType.expense && entry.specialActionId == id,
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  Map<String, double> expenseByCategory(DateTime month) {
    final result = <String, double>{};
    for (final entry in forMonth(
      month,
    ).where((entry) => entry.type == EntryType.expense)) {
      final category = entry.specialActionId == null ? entry.category : '特别行动';
      result.update(
        category,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return result;
  }

  String exportBackupJson() => const JsonEncoder.withIndent('  ').convert({
    'format': 'jianzhang-backup',
    'schemaVersion': 3,
    'appVersion': '1.5.6',
    'exportedAt': DateTime.now().toIso8601String(),
    'monthlyBudget': _monthlyBudget,
    'financialBaseline': _financialBaseline?.toJson(),
    'entries': _entries.map((entry) => entry.toJson()).toList(),
    'specialActions': _specialActions.map((action) => action.toJson()).toList(),
    'stockSnapshots': _stockSnapshots.map((item) => item.toJson()).toList(),
    'financialPositions': _financialPositions
        .map((item) => item.toJson())
        .toList(),
  });

  String exportEntriesCsv() {
    String cell(Object? value) {
      var text = value?.toString() ?? '';
      if (text.startsWith('=') ||
          text.startsWith('+') ||
          text.startsWith('-') ||
          text.startsWith('@')) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        '日期',
        '类型',
        '金额',
        '分类',
        '投资方向',
        '备注',
        '特别行动',
        '是否折旧资产',
        '折旧月数',
        '预计残值',
        '出售资产ID',
      ],
      ..._entries.map(
        (entry) => [
          entry.date.toIso8601String().split('T').first,
          switch (entry.type) {
            EntryType.income => '收入',
            EntryType.expense => '支出',
            EntryType.investment => entry.isStockDeposit ? '投资投入' : '投资取出',
          },
          entry.amount.toStringAsFixed(2),
          entry.category,
          entry.isStockDeposit
              ? '投入'
              : entry.isStockWithdrawal
              ? '取出'
              : '',
          entry.note,
          specialActionName(entry.specialActionId) ?? '',
          entry.isDepreciable ? '是' : '否',
          entry.isDepreciable ? entry.depreciationMonths : '',
          entry.isDepreciable ? entry.residualValue.toStringAsFixed(2) : '',
          entry.disposedAssetId ?? '',
        ],
      ),
    ];
    return '\ufeff${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
  }

  Future<void> importBackupJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'jianzhang-backup') {
      throw const FormatException('不是有效的简账 JSON 备份');
    }
    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion < 1 || schemaVersion > 3) {
      throw const FormatException('备份版本不受支持');
    }

    final newEntries = (decoded['entries'] as List<dynamic>? ?? const [])
        .map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    final newActions = (decoded['specialActions'] as List<dynamic>? ?? const [])
        .map((item) => SpecialAction.fromJson(item as Map<String, dynamic>))
        .toList();
    final newStocks = (decoded['stockSnapshots'] as List<dynamic>? ?? const [])
        .map(
          (item) => StockMonthlySnapshot.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final newPositions =
        (decoded['financialPositions'] as List<dynamic>? ?? const [])
            .map(
              (item) => FinancialPositionSnapshot.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
    final baselineJson = decoded['financialBaseline'];
    final newBaseline = baselineJson == null
        ? null
        : FinancialBaseline.fromJson(baselineJson as Map<String, dynamic>);
    final newBudget = (decoded['monthlyBudget'] as num?)?.toDouble() ?? 5000;
    if (newBudget <= 0) throw const FormatException('预算金额无效');

    _entries
      ..clear()
      ..addAll(newEntries);
    _specialActions
      ..clear()
      ..addAll(newActions);
    _stockSnapshots
      ..clear()
      ..addAll(newStocks);
    _financialPositions
      ..clear()
      ..addAll(newPositions);
    _financialBaseline = newBaseline;
    _monthlyBudget = newBudget;
    _sort();
    _stockSnapshots.sort((a, b) => a.month.compareTo(b.month));
    _financialPositions.sort((a, b) => a.month.compareTo(b.month));
    await _saveAll();
    notifyListeners();
  }

  void _sort() => _entries.sort((a, b) => b.date.compareTo(a.date));
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _saveSpecialActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _specialActionsKey,
      jsonEncode(_specialActions.map((action) => action.toJson()).toList()),
    );
  }

  Future<void> _saveStockSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stockSnapshotsKey,
      jsonEncode(_stockSnapshots.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveFinancialPositions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _financialPositionsKey,
      jsonEncode(_financialPositions.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveFinancialBaseline() async {
    final baseline = _financialBaseline;
    final prefs = await SharedPreferences.getInstance();
    if (baseline == null) {
      await prefs.remove(_financialBaselineKey);
      return;
    }
    await prefs.setString(_financialBaselineKey, jsonEncode(baseline.toJson()));
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _monthlyBudget);
    await _save();
    await _saveSpecialActions();
    await _saveStockSnapshots();
    await _saveFinancialPositions();
    await _saveFinancialBaseline();
  }
}
