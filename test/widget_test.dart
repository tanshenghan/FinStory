import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finstory/data/ledger_store.dart';
import 'package:finstory/main.dart';
import 'package:finstory/models/financial_baseline.dart';
import 'package:finstory/models/financial_position_snapshot.dart';
import 'package:finstory/models/ledger_entry.dart';
import 'package:finstory/models/stock_monthly_snapshot.dart';
import 'package:finstory/screens/ledger_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首页展示账本汇总和导航', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore();
    await store.load();

    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byType(LedgerShell), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('当前自由现金'), findsOneWidget);
    expect(find.text('本月自由现金流'), findsOneWidget);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.text('首页')).dy,
      greaterThan(screenHeight - 100),
    );

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('统计分析'), findsOneWidget);
    expect(find.text('月统计'), findsOneWidget);
    expect(find.text('年统计'), findsOneWidget);
    expect(find.text('自定义'), findsNothing);
    expect(find.text('财务报表'), findsOneWidget);
    expect(find.text('收支流向'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分类占比'),
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('monthly-stats-dashboard')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('分类占比'), findsOneWidget);

    await tester.tap(find.text('年统计'));
    await tester.pumpAndSettle();
    expect(find.text('最近一年'), findsOneWidget);
    expect(find.text('统计范围：最近一年'), findsOneWidget);
    expect(find.text('常规支出'), findsOneWidget);
    expect(find.text('特别行动'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trend-range')));
    await tester.pumpAndSettle();
    expect(find.text('统计范围：3年'), findsWidgets);
    expect(find.text('统计范围：5年'), findsWidgets);
    expect(find.text('统计范围：从开始至今'), findsWidgets);
    await tester.tap(find.text('统计范围：半年').last);
    await tester.pumpAndSettle();
    expect(find.text('半年'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('我的个人账本'), findsOneWidget);
    expect(find.text('常规预算'), findsOneWidget);
    expect(find.text('账户管理'), findsNothing);
    expect(find.text('分类管理'), findsNothing);
    expect(find.text('应用锁'), findsNothing);
    expect(find.text('导出'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('版本 1.6.1 更新内容'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('版本 1.6.1 更新内容'), findsOneWidget);
  });

  testWidgets('财务报表包含个人三表和净资产变动表', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('财务报表'));
    await tester.pumpAndSettle();

    expect(find.text('利润表'), findsOneWidget);
    expect(find.text('资产负债表'), findsOneWidget);
    expect(find.text('现金流量表'), findsOneWidget);
    expect(find.text('净资产变动表'), findsOneWidget);
    expect(find.text('个人利润表'), findsOneWidget);
  });

  testWidgets('分类明细进入对应分类流水并可继续编辑', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final now = DateTime.now();
    await store.add(
      LedgerEntry(
        id: 'education-entry',
        type: EntryType.expense,
        amount: 120,
        category: '教育',
        account: '银行卡',
        date: now,
        note: '课程资料',
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'food-entry',
        type: EntryType.expense,
        amount: 35,
        category: '餐饮',
        account: '微信',
        date: now,
        note: '午餐',
      ),
    );

    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    final educationRow = find.byKey(const ValueKey('category-row-教育'));
    final monthlyScrollable = find.descendant(
      of: find.byKey(const Key('monthly-stats-dashboard')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      educationRow,
      220,
      scrollable: monthlyScrollable,
    );
    await tester.drag(monthlyScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(educationRow);
    await tester.pumpAndSettle();

    expect(find.text('教育支出'), findsOneWidget);
    expect(find.text('课程资料'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);

    await tester.tap(find.text('课程资料'));
    await tester.pumpAndSettle();
    expect(find.text('编辑记录'), findsOneWidget);
  });

  testWidgets('支出页最近记录位于特别行动上方', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .toList();
    expect(labels.indexOf('最近记录'), lessThan(labels.indexOf('特别行动')));
  });

  testWidgets('新增记录后跳转到明细并立即显示', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();

    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount-input')), '25.50');
    await tester.tap(find.byKey(const Key('save-entry')));
    await tester.pumpAndSettle();

    expect(find.text('本月收支与预算'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('-¥25.50'),
      220,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('-¥25.50'), findsOneWidget);
    expect(store.entries, hasLength(1));
  });

  testWidgets('最近记录可以修改金额和类别', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await store.add(
      LedgerEntry(
        id: 'editable-entry',
        type: EntryType.expense,
        amount: 25.5,
        category: '餐饮',
        account: '微信',
        date: DateTime.now(),
        note: '可编辑记录',
      ),
    );
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();
    final editableEntry = find.text('可编辑记录');
    await tester.scrollUntilVisible(
      editableEntry,
      180,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(editableEntry);
    await tester.pumpAndSettle();

    expect(find.text('编辑记录'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('amount-input')))
          .controller
          ?.text,
      '25.50',
    );

    await tester.enterText(find.byKey(const Key('amount-input')), '42.50');
    await tester.tap(find.text('交通'));
    await tester.tap(find.byKey(const Key('save-entry')));
    await tester.pumpAndSettle();

    expect(store.entries, hasLength(1));
    expect(store.entries.single.id, 'editable-entry');
    expect(store.entries.single.amount, 42.5);
    expect(store.entries.single.category, '交通');
    expect(store.entries.single.account, '微信');
    expect(find.text('-¥42.50'), findsOneWidget);
  });

  testWidgets('统一资产管理可以出售资产并确认处置损益', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await store.add(
      LedgerEntry(
        id: 'test-asset',
        type: EntryType.expense,
        amount: 3600,
        category: '购物',
        account: '银行卡',
        date: DateTime.now(),
        note: '测试手机',
        isDepreciable: true,
        depreciationMonths: 36,
        residualValue: 600,
      ),
    );
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('manage-assets')));
    await tester.pumpAndSettle();
    expect(find.text('统一资产管理'), findsOneWidget);
    expect(find.text('测试手机'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sell-test-asset')));
    await tester.pumpAndSettle();
    expect(find.text('出售资产'), findsOneWidget);
    expect(find.text('处置时账面价值：¥3,600.00'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('asset-sale-price')), '3000');
    await tester.tap(find.byKey(const Key('confirm-asset-disposal')));
    await tester.pumpAndSettle();

    final disposal = store.disposalForAsset('test-asset');
    expect(disposal, isNotNull);
    expect(disposal!.amount, 3000);
    expect(store.disposalGainLossForMonth(DateTime.now()), -600);
    expect(find.text('已处置'), findsOneWidget);
    expect(find.textContaining('处置损失 ¥600.00'), findsOneWidget);
  });

  testWidgets('投资作为收入支出之外的独立记账类型', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投资'));
    await tester.pumpAndSettle();

    expect(find.text('股票投资'), findsOneWidget);
    expect(find.text('投入'), findsOneWidget);
    expect(find.text('取出'), findsOneWidget);
    expect(find.byKey(const Key('depreciation-select')), findsNothing);
    expect(find.byKey(const Key('special-action-select')), findsNothing);

    await tester.enterText(find.byKey(const Key('amount-input')), '2000');
    await tester.tap(find.byKey(const Key('save-entry')));
    await tester.pumpAndSettle();

    expect(store.entries.single.type, EntryType.investment);
    expect(
      store.entries.single.investmentDirection,
      InvestmentDirection.deposit,
    );
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    expect(store.totalForMonth(month, EntryType.expense), 0);
    expect(store.totalForMonth(month, EntryType.income), 0);
  });

  testWidgets('特别行动支出不占用常规预算并单独统计', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();

    final addAction = find.byKey(const Key('add-special-action'));
    await tester.scrollUntilVisible(
      addAction,
      180,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(addAction);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('special-action-name')),
      '春节旅行',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(store.specialActions.single.name, '春节旅行');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-input')), '88');
    final actionSelect = find.byKey(const Key('special-action-select'));
    await tester.ensureVisible(actionSelect);
    await tester.tap(actionSelect);
    await tester.pumpAndSettle();
    await tester.tap(find.text('特别行动 · 春节旅行').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-entry')));
    await tester.pumpAndSettle();

    final month = DateTime(DateTime.now().year, DateTime.now().month);
    expect(store.regularExpenseForMonth(month), 0);
    expect(store.specialExpenseForMonth(month), 88);
    expect(store.expenseByCategory(month)['特别行动'], 88);
    expect(find.text('餐饮 · 春节旅行'), findsOneWidget);
  });

  testWidgets('首页可以填写股票月度快照', (tester) async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await tester.pumpWidget(LedgerApp(store: store));
    await tester.pumpAndSettle();

    final editSnapshot = find.byKey(const Key('edit-stock-snapshot'));
    await tester.ensureVisible(editSnapshot);
    await tester.tap(editSnapshot);
    await tester.pumpAndSettle();

    expect(find.text('股票月度快照'), findsOneWidget);
    expect(find.text('回到本月'), findsOneWidget);
    expect(find.byKey(const Key('stock-purchases')), findsNothing);
    expect(find.byKey(const Key('stock-sales')), findsNothing);
    expect(find.textContaining('投入 ¥'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('stock-market-value')),
      '100000',
    );
    await tester.enterText(find.byKey(const Key('stock-cash-balance')), '5000');
    final dividendField = find.byKey(const Key('stock-dividend'));
    await tester.scrollUntilVisible(
      dividendField,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('stock-snapshot-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('分红已进入证券账户'), findsOneWidget);
    await tester.enterText(dividendField, '1000');
    await tester.tap(find.byKey(const Key('save-stock-snapshot')));
    await tester.pumpAndSettle();

    expect(store.stockSnapshots, hasLength(1));
    expect(store.stockSnapshots.single.totalAssets, 105000);
    expect(find.text('¥105,000.00'), findsWidgets);
  });

  test('新增记录会写入本地存储', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final action = await store.addSpecialAction('更换电脑');
    await store.add(
      LedgerEntry(
        id: 'persist-test',
        type: EntryType.expense,
        amount: 18,
        category: '餐饮',
        account: '微信',
        date: DateTime(2026, 11, 8),
        specialActionId: action.id,
      ),
    );

    final reloaded = LedgerStore();
    await reloaded.load();
    expect(reloaded.entries.single.id, 'persist-test');
    expect(reloaded.specialActions.single.name, '更换电脑');
    expect(reloaded.entries.single.specialActionId, action.id);
  });

  test('股票盈亏排除外部资金且分红不重复计算', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final first = StockMonthlySnapshot(
      month: DateTime(2026, 10),
      marketValue: 90000,
      cashBalance: 10000,
      externalInflow: 0,
      externalOutflow: 0,
      dividendReceived: 1000,
      feesAndTaxes: 100,
    );
    final second = StockMonthlySnapshot(
      month: DateTime(2026, 11),
      marketValue: 105000,
      cashBalance: 5000,
      externalInflow: 8000,
      externalOutflow: 2000,
      dividendReceived: 1000,
      feesAndTaxes: 200,
    );
    await store.upsertStockSnapshot(first);
    await store.upsertStockSnapshot(second);

    expect(store.stockProfitFor(first), 0);
    expect(store.stockProfitFor(second), 4000);
    expect(store.stockPriceAndTradingProfitFor(second), 3200);

    final reloaded = LedgerStore();
    await reloaded.load();
    expect(reloaded.stockSnapshots, hasLength(2));
    expect(reloaded.stockSnapshots.last.dividendReceived, 1000);
  });

  test('股票投资只转移资产位置并由月末快照确认盈亏', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await store.setFinancialBaseline(
      FinancialBaseline(
        effectiveDate: DateTime(2026, 1, 1),
        cashAndDeposits: 10000,
        physicalAssets: 0,
        receivablesAndOtherAssets: 0,
        shortTermLiabilities: 0,
        longTermLiabilities: 0,
      ),
    );
    await store.upsertStockSnapshot(
      StockMonthlySnapshot(
        month: DateTime(2025, 12),
        marketValue: 0,
        cashBalance: 0,
        externalInflow: 0,
        externalOutflow: 0,
        dividendReceived: 0,
        feesAndTaxes: 0,
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'stock-transfer',
        type: EntryType.investment,
        amount: 2000,
        category: '股票投资',
        account: '未设置',
        date: DateTime(2026, 1, 10),
        investmentDirection: InvestmentDirection.deposit,
      ),
    );

    final beforeSnapshot = DateTime(2026, 1, 10, 23, 59);
    expect(store.cashAndDepositsAt(beforeSnapshot), 8000);
    expect(store.stockAccountAssetsAt(beforeSnapshot), 2000);
    expect(store.totalAssetsAt(beforeSnapshot), 10000);
    expect(store.stockInvestmentForMonth(DateTime(2026, 1)), 2000);
    expect(store.stockInvestmentSincePreviousSnapshot(DateTime(2026, 1)), 2000);
    expect(store.freeCashFlowForMonth(DateTime(2026, 1)), -2000);
    expect(store.regularExpenseForMonth(DateTime(2026, 1)), 0);
    expect(store.recognizedExpenseForMonth(DateTime(2026, 1)), 0);

    await store.add(
      LedgerEntry(
        id: 'stock-withdrawal',
        type: EntryType.investment,
        amount: 500,
        category: '股票投资',
        account: '未设置',
        date: DateTime(2026, 1, 15),
        investmentDirection: InvestmentDirection.withdraw,
      ),
    );
    expect(store.cashAndDepositsAt(DateTime(2026, 1, 15, 23, 59)), 8500);
    expect(store.stockAccountAssetsAt(DateTime(2026, 1, 15, 23, 59)), 1500);
    expect(store.totalAssetsAt(DateTime(2026, 1, 15, 23, 59)), 10000);
    expect(store.stockWithdrawalForMonth(DateTime(2026, 1)), 500);

    final january = StockMonthlySnapshot(
      month: DateTime(2026, 1),
      marketValue: 1900,
      cashBalance: 200,
      externalInflow: 2000,
      externalOutflow: 500,
      dividendReceived: 0,
      feesAndTaxes: 0,
    );
    await store.upsertStockSnapshot(january);
    expect(store.stockProfitFor(january), 600);
    expect(store.totalAssetsForMonth(DateTime(2026, 1)), 10600);
  });

  test('资产负债快照会持久化并计算净资产', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final month = DateTime(2026, 11);
    await store.upsertFinancialPosition(
      FinancialPositionSnapshot(
        month: month,
        cashAndDeposits: 10000,
        physicalAssets: 5000,
        receivablesAndOtherAssets: 2000,
        shortTermLiabilities: 1500,
        longTermLiabilities: 500,
      ),
    );
    await store.upsertStockSnapshot(
      StockMonthlySnapshot(
        month: month,
        marketValue: 90000,
        cashBalance: 10000,
        externalInflow: 0,
        externalOutflow: 0,
        dividendReceived: 0,
        feesAndTaxes: 0,
      ),
    );

    expect(store.totalAssetsForMonth(month), 117000);
    expect(store.liabilitiesForMonth(month), 2000);
    expect(store.netWorthForMonth(month), 115000);

    final reloaded = LedgerStore();
    await reloaded.load();
    expect(reloaded.financialPositions, hasLength(1));
    expect(reloaded.netWorthForMonth(month), 115000);
  });

  test('折旧资产从购买后的下一个自然月开始计提', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final month = DateTime(2026, 11);
    await store.upsertFinancialPosition(
      FinancialPositionSnapshot(
        month: month,
        cashAndDeposits: 10000,
        physicalAssets: 0,
        receivablesAndOtherAssets: 0,
        shortTermLiabilities: 0,
        longTermLiabilities: 0,
        tracksTransactions: true,
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'salary',
        type: EntryType.income,
        amount: 1000,
        category: '工资',
        account: '未设置',
        date: DateTime(2026, 11, 2),
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'phone',
        type: EntryType.expense,
        amount: 3600,
        category: '购物',
        account: '未设置',
        date: DateTime(2026, 11, 3),
        note: '手机',
        isDepreciable: true,
        depreciationMonths: 36,
      ),
    );

    expect(store.cashAndDepositsForMonth(month), 7400);
    expect(store.freeCashFlowForMonth(month), -2600);
    expect(store.depreciableAssetValueForMonth(month), 3600);
    expect(store.depreciationExpenseForMonth(month), 0);
    expect(store.recognizedExpenseForMonth(month), 0);
    expect(store.netWorthForMonth(month), 11000);
    expect(store.depreciableAssetValueForMonth(DateTime(2026, 12)), 3500);
    expect(store.depreciationExpenseForMonth(DateTime(2026, 12)), 100);

    await store.add(
      LedgerEntry(
        id: 'sell-phone',
        type: EntryType.income,
        amount: 3000,
        category: '其他',
        account: '未设置',
        date: DateTime(2026, 11, 20),
        disposedAssetId: 'phone',
      ),
    );
    expect(store.depreciableAssetValueForMonth(month), 0);
    expect(store.disposalGainLossForMonth(month), -600);
    expect(store.recognizedExpenseForMonth(month), 600);
    expect(store.freeCashFlowForMonth(month), 400);
    expect(store.netWorthForMonth(month), 10400);
  });

  test('出售当月不计提折旧并按月初账面价值确认损益', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    final asset = LedgerEntry(
      id: 'december-sale-asset',
      type: EntryType.expense,
      amount: 3600,
      category: '购物',
      account: '银行卡',
      date: DateTime(2026, 11, 3),
      note: '测试设备',
      isDepreciable: true,
      depreciationMonths: 36,
    );
    await store.add(asset);
    await store.add(
      LedgerEntry(
        id: 'december-sale',
        type: EntryType.income,
        amount: 3000,
        category: '其他',
        account: '银行卡',
        date: DateTime(2026, 12, 10),
        disposedAssetId: asset.id,
      ),
    );

    expect(store.depreciationExpenseForMonth(DateTime(2026, 11)), 0);
    expect(store.depreciationExpenseForMonth(DateTime(2026, 12)), 0);
    expect(store.assetBookValueAtDisposal(asset, DateTime(2026, 12, 10)), 3600);
    expect(store.disposalGainLossForMonth(DateTime(2026, 12)), -600);
  });

  test('初始资产只设置一次并跨月累计全部流水', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await store.setFinancialBaseline(
      FinancialBaseline(
        effectiveDate: DateTime(2026, 1, 1),
        cashAndDeposits: 10000,
        physicalAssets: 2000,
        receivablesAndOtherAssets: 0,
        shortTermLiabilities: 500,
        longTermLiabilities: 0,
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'jan-income',
        type: EntryType.income,
        amount: 1000,
        category: '工资',
        account: '未设置',
        date: DateTime(2026, 1, 20),
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'feb-expense',
        type: EntryType.expense,
        amount: 200,
        category: '餐饮',
        account: '未设置',
        date: DateTime(2026, 2, 3),
      ),
    );

    expect(store.cashAndDepositsAt(DateTime(2026, 1, 31)), 11000);
    expect(store.cashAndDepositsAt(DateTime(2026, 2, 3)), 10800);
    expect(store.totalAssetsAt(DateTime(2026, 2, 3)), 12800);
    expect(store.netWorthForMonth(DateTime(2026, 2)), 12300);
    expect(store.freeCashFlowForMonth(DateTime(2026, 1)), 1000);
    expect(store.freeCashFlowForMonth(DateTime(2026, 2)), -200);

    final reloaded = LedgerStore();
    await reloaded.load();
    expect(reloaded.financialBaseline?.cashAndDeposits, 10000);
    expect(reloaded.cashAndDepositsAt(DateTime(2026, 2, 3)), 10800);
  });

  test('JSON 可以完整导出并恢复，CSV 可以导出流水', () async {
    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final store = LedgerStore();
    await store.load();
    await store.setBudget(8888);
    final action = await store.addSpecialAction('年度旅行');
    await store.setFinancialBaseline(
      FinancialBaseline(
        effectiveDate: DateTime(2026, 1, 1),
        cashAndDeposits: 12000,
        physicalAssets: 3000,
        receivablesAndOtherAssets: 500,
        shortTermLiabilities: 1000,
        longTermLiabilities: 0,
      ),
    );
    await store.add(
      LedgerEntry(
        id: 'backup-entry',
        type: EntryType.expense,
        amount: 99,
        category: '购物',
        account: '未设置',
        date: DateTime(2026, 2, 3),
        note: '备份测试',
        specialActionId: action.id,
      ),
    );
    await store.upsertStockSnapshot(
      StockMonthlySnapshot(
        month: DateTime(2026, 2),
        marketValue: 10000,
        cashBalance: 1000,
        externalInflow: 0,
        externalOutflow: 0,
        dividendReceived: 0,
        feesAndTaxes: 0,
      ),
    );

    final json = store.exportBackupJson();
    final csv = store.exportEntriesCsv();
    expect(json, contains('jianzhang-backup'));
    expect(csv, contains('备份测试'));
    expect(csv, contains('是否折旧资产'));

    SharedPreferences.setMockInitialValues({'ledger_entries_v1': '[]'});
    final restored = LedgerStore();
    await restored.load();
    await restored.importBackupJson(json);
    expect(restored.entries.single.id, 'backup-entry');
    expect(restored.specialActions.single.name, '年度旅行');
    expect(restored.stockSnapshots.single.totalAssets, 11000);
    expect(restored.financialBaseline?.cashAndDeposits, 12000);
    expect(restored.monthlyBudget, 8888);

    await expectLater(
      restored.importBackupJson('{"not":"a backup"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('新类别生效并兼容旧记录', () {
    expect(expenseCategories, contains('资本投入'));
    expect(expenseCategories, isNot(contains('股票投资')));
    expect(expenseCategories, isNot(contains('人情')));
    expect(incomeCategories, contains('资本获利'));
    expect(incomeCategories, isNot(contains('投资')));
    expect(incomeCategories, isNot(contains('退款')));

    Map<String, dynamic> oldEntry(String type, String category) => {
      'id': '$type-$category',
      'type': type,
      'amount': 10,
      'category': category,
      'account': '微信',
      'date': '2026-11-08T00:00:00.000',
      'note': '',
    };

    expect(LedgerEntry.fromJson(oldEntry('expense', '人情')).category, '资本投入');
    expect(LedgerEntry.fromJson(oldEntry('income', '投资')).category, '资本获利');
    expect(LedgerEntry.fromJson(oldEntry('income', '退款')).category, '其他');
    final oldStockInvestment = LedgerEntry.fromJson(
      oldEntry('expense', '股票投资'),
    );
    expect(oldStockInvestment.type, EntryType.investment);
    expect(oldStockInvestment.investmentDirection, InvestmentDirection.deposit);
  });

  test('首次启动为空账本并清理旧版示例数据', () async {
    SharedPreferences.setMockInitialValues({});
    final freshStore = LedgerStore();
    await freshStore.load();
    expect(freshStore.entries, isEmpty);

    final oldDemo = LedgerEntry(
      id: 'seed-1',
      type: EntryType.expense,
      amount: 32,
      category: '餐饮',
      account: '微信',
      date: DateTime(2026, 11, 8),
    );
    final userEntry = LedgerEntry(
      id: 'user-entry',
      type: EntryType.income,
      amount: 100,
      category: '工资',
      account: '银行卡',
      date: DateTime(2026, 11, 8),
    );
    SharedPreferences.setMockInitialValues({
      'ledger_entries_v1': jsonEncode([oldDemo.toJson(), userEntry.toJson()]),
    });
    final upgradedStore = LedgerStore();
    await upgradedStore.load();
    expect(upgradedStore.entries.map((entry) => entry.id), ['user-entry']);
  });
}
