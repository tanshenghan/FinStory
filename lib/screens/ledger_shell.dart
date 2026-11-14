import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/ledger_store.dart';
import '../models/financial_baseline.dart';
import '../models/ledger_entry.dart';
import '../models/stock_monthly_snapshot.dart';
import '../theme/app_theme.dart';

final _money = NumberFormat('#,##0.00');
const _exportChannel = MethodChannel('com.yohji.ledger_app/export');

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.store});
  final LedgerStore store;

  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  int _index = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _addEntry() async {
    final entry = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute(builder: (_) => AddEntryPage(store: widget.store)),
    );
    if (entry == null) {
      return;
    }
    await widget.store.add(entry);
    if (mounted) {
      setState(() {
        _month = DateTime(entry.date.year, entry.date.month);
        _index = 1;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存这笔账')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pages = [
          OverviewPage(store: widget.store),
          SpendingPage(
            store: widget.store,
            month: _month,
            onMonthChanged: _changeMonth,
            onShowAll: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AllEntriesPage(store: widget.store, initialMonth: _month),
              ),
            ),
          ),
          StatsPage(
            store: widget.store,
            month: _month,
            onMonthChanged: _changeMonth,
          ),
          ProfilePage(store: widget.store),
        ];
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: IndexedStack(index: _index, children: pages),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addEntry,
            elevation: 2,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _LedgerNavigation(
            index: _index,
            onChanged: (value) => setState(() => _index = value),
          ),
        );
      },
    );
  }
}

class _LedgerNavigation extends StatelessWidget {
  const _LedgerNavigation({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    Widget item(int value, IconData icon, String label) => Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: index == value
                    ? color
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: index == value
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: index == value
                      ? color
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return BottomAppBar(
      height: 72 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Theme.of(context).cardColor,
      elevation: 10,
      child: Row(
        children: [
          item(0, Icons.home_rounded, '首页'),
          item(1, Icons.payments_rounded, '支出'),
          const SizedBox(width: 68),
          item(2, Icons.donut_large_rounded, '统计'),
          item(3, Icons.person_rounded, '我的'),
        ],
      ),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.store});

  final LedgerStore store;

  Future<void> _editStockSnapshot(BuildContext context) async {
    final now = DateTime.now();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StockSnapshotPage(store: store, initialMonth: now),
      ),
    );
  }

  Future<void> _editFinancialPosition(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FinancialPositionPage(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        const Text(
          '我的财务',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          '截至 ${DateFormat('yyyy年M月d日').format(now)} · 实时滚动',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 14),
        _FinancialOverviewCard(
          store: store,
          month: month,
          onEdit: () => _editFinancialPosition(context),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                '股票账户',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              key: const Key('edit-stock-snapshot'),
              onPressed: () => _editStockSnapshot(context),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(
                store.stockSnapshotForMonth(month) == null ? '记录' : '修改',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StockSnapshotCard(store: store, month: month),
      ],
    );
  }
}

class SpendingPage extends StatelessWidget {
  const SpendingPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
    required this.onShowAll,
  });
  final LedgerStore store;
  final DateTime month;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onShowAll;

  Future<void> _createSpecialAction(BuildContext context) async {
    var input = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建特别行动'),
        content: TextField(
          key: const Key('special-action-name'),
          autofocus: true,
          maxLength: 20,
          onChanged: (value) => input = value,
          decoration: const InputDecoration(
            labelText: '行动名称',
            hintText: '例如：春节旅行、更换电脑',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = input.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    await store.addSpecialAction(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已创建特别行动“$name”')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = store.totalForMonth(month, EntryType.expense);
    final regularExpense = store.regularExpenseForMonth(month);
    final income = store.totalForMonth(month, EntryType.income);
    final entries = store.forMonth(month).take(4).toList();
    final ratio = store.monthlyBudget == 0
        ? 0.0
        : (regularExpense / store.monthlyBudget).clamp(0.0, 1.0);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('支出管理', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 2),
                        Text(
                          '本月收支与预算',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _MonthPicker(month: month, onChanged: onMonthChanged),
              const SizedBox(height: 14),
              _SummaryCard(income: income, expense: expense),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '常规预算',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '常规支出 ¥${_money.format(regularExpense)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '剩余 ¥${_money.format(math.max(0, store.monthlyBudget - regularExpense))}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '特别行动',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('add-special-action'),
                    onPressed: () => _createSpecialAction(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新建'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (store.specialActions.isEmpty)
                const _EmptyState(message: '还没有特别行动，例如旅行或大宗购物')
              else
                Card(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < store.specialActions.length;
                        index++
                      ) ...[
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0x1A7E57C2),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Color(0xFF7E57C2),
                            ),
                          ),
                          title: Text(
                            store.specialActions[index].name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('不占用常规预算'),
                          trailing: Text(
                            '累计 ¥${_money.format(store.totalForSpecialAction(store.specialActions[index].id))}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (index != store.specialActions.length - 1)
                          const Divider(height: 1, indent: 72),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '最近记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(onPressed: onShowAll, child: const Text('查看全部')),
                ],
              ),
              if (entries.isEmpty)
                const _EmptyState(message: '这个月还没有记录')
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        _EntryTile(
                          entry: entries[i],
                          actionName: store.specialActionName(
                            entries[i].specialActionId,
                          ),
                        ),
                        if (i != entries.length - 1)
                          const Divider(height: 1, indent: 72),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.income, required this.expense});
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFF244A3D), Color(0xFF3E7561)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28315C4C),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('本月结余', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(
          '¥ ${_money.format(income - expense)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _summaryItem(Icons.arrow_downward_rounded, '收入', income),
            ),
            Container(width: 1, height: 38, color: Colors.white24),
            const SizedBox(width: 22),
            Expanded(
              child: _summaryItem(Icons.arrow_upward_rounded, '支出', expense),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _summaryItem(IconData icon, String title, double value) => Row(
    children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: Colors.white12,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            '¥${_money.format(value)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ],
  );
}

class _FinancialOverviewCard extends StatelessWidget {
  const _FinancialOverviewCard({
    required this.store,
    required this.month,
    required this.onEdit,
  });

  final LedgerStore store;
  final DateTime month;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final baseline = store.financialBaseline;
    final stock = store.stockSnapshotForMonth(month);
    final now = DateTime.now();
    final totalAssets = store.totalAssetsAt(now);
    final liabilities = store.liabilitiesForMonth(month);
    final netWorth = totalAssets - liabilities;
    final currentFreeCash = store.cashAndDepositsAt(now);
    final freeCashFlow = store.freeCashFlowForMonth(month);
    final income = store.recognizedIncomeForMonth(month);
    final expense = store.recognizedExpenseForMonth(month);
    final stockProfit = stock == null ? 0.0 : store.stockProfitFor(stock);
    final comprehensiveProfit = income + stockProfit - expense;

    Widget metric(String label, double value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${_money.format(value)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '个人财务总览',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  key: const Key('edit-financial-position'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(baseline == null ? '初始化资产' : '修改初始值'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                metric('总资产', totalAssets),
                const SizedBox(width: 12),
                metric('总负债', liabilities),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                metric(
                  '净资产',
                  netWorth,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                metric(
                  '本月综合盈亏',
                  comprehensiveProfit,
                  color: comprehensiveProfit < 0
                      ? AppTheme.accent
                      : Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                metric(
                  '当前自由现金',
                  currentFreeCash,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                metric(
                  '本月自由现金流',
                  freeCashFlow,
                  color: freeCashFlow < 0
                      ? AppTheme.accent
                      : Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            if (baseline == null) ...[
              const SizedBox(height: 14),
              const Text(
                '请先初始化一次资产。之后每笔收入、支出和折旧都会持续更新，不需要每月重填。',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockSnapshotCard extends StatelessWidget {
  const _StockSnapshotCard({required this.store, required this.month});
  final LedgerStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final snapshot = store.stockSnapshotForMonth(month);
    if (snapshot == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(Icons.candlestick_chart_rounded, size: 32),
              SizedBox(width: 14),
              Expanded(child: Text('本月还没有股票账户快照，记录后可计算真实月度盈亏。')),
            ],
          ),
        ),
      );
    }
    final previous = store.previousStockSnapshot(snapshot.month);
    final profit = store.stockProfitFor(snapshot);
    final profitColor = profit >= 0
        ? const Color(0xFFE05A47)
        : const Color(0xFF2E8B67);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('股票账户总资产', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '¥${_money.format(snapshot.totalAssets)}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MiniValue(label: '持仓市值', value: snapshot.marketValue),
                ),
                Expanded(
                  child: _MiniValue(label: '账户现金', value: snapshot.cashBalance),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        previous == null ? '基准月份' : '本月盈亏',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        previous == null
                            ? '—'
                            : '${profit >= 0 ? '+' : ''}¥${_money.format(profit)}',
                        style: TextStyle(
                          color: profitColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (snapshot.dividendReceived > 0) ...[
              const Divider(height: 28),
              Text(
                '本月分红 ¥${_money.format(snapshot.dividendReceived)}（已包含在账户总资产和本月盈亏中，不重复计算）',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 3),
      Text(
        '¥${_money.format(value)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class AllEntriesPage extends StatefulWidget {
  const AllEntriesPage({
    super.key,
    required this.store,
    required this.initialMonth,
  });

  final LedgerStore store;
  final DateTime initialMonth;

  @override
  State<AllEntriesPage> createState() => _AllEntriesPageState();
}

class _AllEntriesPageState extends State<AllEntriesPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('全部流水', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => DetailPage(
          store: widget.store,
          month: _month,
          onMonthChanged: (delta) => setState(
            () => _month = DateTime(_month.year, _month.month + delta),
          ),
          showHeader: false,
        ),
      ),
    ),
  );
}

class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
    this.showHeader = true,
  });
  final LedgerStore store;
  final DateTime month;
  final ValueChanged<int> onMonthChanged;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final entries = store.forMonth(month);
    final grouped = <DateTime, List<LedgerEntry>>{};
    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    return Column(
      children: [
        if (showHeader)
          _PageHeader(
            title: '账目明细',
            action: IconButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('搜索功能将在下一版开放'))),
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MonthPicker(month: month, onChanged: onMonthChanged),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? const _EmptyState(message: '这个月还没有账目')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final day = grouped.keys.elementAt(index);
                    final list = grouped[day]!;
                    final expense = list
                        .where((e) => e.type == EntryType.expense)
                        .fold<double>(0, (s, e) => s + e.amount);
                    final income = list
                        .where((e) => e.type == EntryType.income)
                        .fold<double>(0, (s, e) => s + e.amount);
                    final investmentIn = list
                        .where((e) => e.isStockDeposit)
                        .fold<double>(0, (s, e) => s + e.amount);
                    final investmentOut = list
                        .where((e) => e.isStockWithdrawal)
                        .fold<double>(0, (s, e) => s + e.amount);
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('M月d日').format(day),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  [
                                    '支 ¥${_money.format(expense)}',
                                    '收 ¥${_money.format(income)}',
                                    if (investmentIn > 0)
                                      '投 ¥${_money.format(investmentIn)}',
                                    if (investmentOut > 0)
                                      '取 ¥${_money.format(investmentOut)}',
                                  ].join('  '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Card(
                            child: Column(
                              children: [
                                for (var i = 0; i < list.length; i++)
                                  Dismissible(
                                    key: ValueKey(list[i].id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (_) =>
                                        store.remove(list[i].id),
                                    child: Column(
                                      children: [
                                        _EntryTile(
                                          entry: list[i],
                                          actionName: store.specialActionName(
                                            list[i].specialActionId,
                                          ),
                                        ),
                                        if (i != list.length - 1)
                                          const Divider(height: 1, indent: 72),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _StatsView { category, trend, reports }

enum _TrendRange { halfYear, oneYear, threeYears, fiveYears, all }

extension on _TrendRange {
  String get label => switch (this) {
    _TrendRange.halfYear => '半年',
    _TrendRange.oneYear => '最近一年',
    _TrendRange.threeYears => '3年',
    _TrendRange.fiveYears => '5年',
    _TrendRange.all => '从开始至今',
  };

  int? get monthCount => switch (this) {
    _TrendRange.halfYear => 6,
    _TrendRange.oneYear => 12,
    _TrendRange.threeYears => 36,
    _TrendRange.fiveYears => 60,
    _TrendRange.all => null,
  };
}

class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.store,
    required this.month,
    required this.onMonthChanged,
  });
  final LedgerStore store;
  final DateTime month;
  final ValueChanged<int> onMonthChanged;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _StatsView _view = _StatsView.category;
  _TrendRange _trendRange = _TrendRange.oneYear;

  @override
  Widget build(BuildContext context) {
    final expense = widget.store.totalForMonth(widget.month, EntryType.expense);
    final regularExpense = widget.store.regularExpenseForMonth(widget.month);
    final income = widget.store.totalForMonth(widget.month, EntryType.income);
    final categories =
        widget.store.expenseByCategory(widget.month).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        const _PageHeader(title: '收支统计'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<_StatsView>(
            segments: const [
              ButtonSegment(
                value: _StatsView.category,
                icon: Icon(Icons.donut_large_rounded),
                label: Text('分类统计'),
              ),
              ButtonSegment(
                value: _StatsView.trend,
                icon: Icon(Icons.show_chart_rounded),
                label: Text('月度趋势'),
              ),
              ButtonSegment(
                value: _StatsView.reports,
                icon: Icon(Icons.account_balance_rounded),
                label: Text('财务报表'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _view = value.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MonthPicker(
            month: widget.month,
            onChanged: widget.onMonthChanged,
          ),
        ),
        Expanded(
          child: switch (_view) {
            _StatsView.category => ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _IncomeExpenseSummary(income: income, expense: expense),
                const SizedBox(height: 20),
                const Text(
                  '支出分类',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const _EmptyState(message: '暂无统计数据')
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 170,
                            child: Center(
                              child: _DonutChart(
                                value: regularExpense,
                                budget: widget.store.monthlyBudget,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in categories)
                            _CategoryBar(
                              name: item.key,
                              value: item.value,
                              maxValue: categories.first.value,
                              total: expense,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _StatsView.trend => _MonthlyTrendView(
              store: widget.store,
              endMonth: widget.month,
              range: _trendRange,
              onRangeChanged: (value) => setState(() => _trendRange = value),
            ),
            _StatsView.reports => _FinancialReportsView(
              store: widget.store,
              month: widget.month,
            ),
          },
        ),
      ],
    );
  }
}

class _FinancialReportsView extends StatelessWidget {
  const _FinancialReportsView({required this.store, required this.month});

  final LedgerStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final stock = store.stockSnapshotForMonth(month);
    final position = store.financialBaseline;
    final income = store.recognizedIncomeForMonth(month);
    final expense = store.recognizedExpenseForMonth(month);
    final depreciation = store.depreciationExpenseForMonth(month);
    final disposalGainLoss = store.disposalGainLossForMonth(month);
    final disposalGain = math.max(0, disposalGainLoss).toDouble();
    final disposalLoss = math.max(0, -disposalGainLoss).toDouble();
    final directConsumption = expense - depreciation - disposalLoss;
    final stockProfit = stock == null ? 0.0 : store.stockProfitFor(stock);
    final comprehensiveProfit = income + stockProfit - expense;
    final capitalInvestment = store.capitalInvestmentForMonth(month);
    final stockInvestment = store.stockInvestmentForMonth(month);
    final stockWithdrawal = store.stockWithdrawalForMonth(month);
    final monthEntries = store.forMonth(month);
    final assetPurchaseCash = monthEntries
        .where(
          (entry) => entry.type == EntryType.expense && entry.isDepreciable,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final assetSaleCash = monthEntries
        .where(
          (entry) =>
              entry.type == EntryType.income && entry.disposedAssetId != null,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final operatingInflow =
        store.totalForMonth(month, EntryType.income) - assetSaleCash;
    final operatingOutflow = math
        .max(
          0,
          store.totalForMonth(month, EntryType.expense) -
              assetPurchaseCash -
              capitalInvestment -
              stockInvestment,
        )
        .toDouble();
    final operatingNet = operatingInflow - operatingOutflow;
    final investingInflow =
        stockWithdrawal + (stock?.dividendReceived ?? 0) + assetSaleCash;
    final investingOutflow =
        stockInvestment + capitalInvestment + assetPurchaseCash;
    final investingNet = investingInflow - investingOutflow;
    final netCashFlow = operatingNet + investingNet;
    final previousMonth = DateTime(month.year, month.month - 1);
    final previousMonthEnd = DateTime(
      previousMonth.year,
      previousMonth.month + 1,
      0,
      23,
      59,
      59,
    );
    final hasPrevious =
        (store.financialBaseline != null &&
            !previousMonthEnd.isBefore(
              store.financialBaseline!.effectiveDate,
            )) ||
        store.stockSnapshotForMonth(previousMonth) != null;
    final openingNetWorth = hasPrevious
        ? store.netWorthForMonth(previousMonth)
        : 0.0;
    final closingNetWorth = store.netWorthForMonth(month);
    final netWorthChange = closingNetWorth - openingNetWorth;
    final otherChange = netWorthChange - comprehensiveProfit;

    Widget statement(String title, List<Widget> rows, {Widget? footer}) =>
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${month.year}年${month.month}月',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Divider(height: 28),
                    ...rows,
                  ],
                ),
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 12), footer],
          ],
        );

    final missingPosition = Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: const Text('初始化资产负债'),
        subtitle: const Text('只需设置一次，之后所有流水都会持续滚动更新。'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => FinancialPositionPage(store: store),
          ),
        ),
      ),
    );

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '利润表'),
              Tab(text: '资产负债表'),
              Tab(text: '现金流量表'),
              Tab(text: '净资产变动表'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                statement('个人利润表', [
                  _StatementRow(label: '日常及其他收入', value: income - disposalGain),
                  if (disposalGain > 0)
                    _StatementRow(label: '资产处置收益', value: disposalGain),
                  _StatementRow(label: '股票公允价值盈亏', value: stockProfit),
                  if ((stock?.dividendReceived ?? 0) > 0)
                    _StatementRow(
                      label: '其中：已到账分红（已含在股票盈亏）',
                      value: stock!.dividendReceived,
                      indent: true,
                    ),
                  _StatementRow(
                    label: '收入与收益合计',
                    value: income + stockProfit,
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _StatementRow(label: '日常及特别行动消费', value: directConsumption),
                  _StatementRow(label: '折旧费用', value: depreciation),
                  if (disposalLoss > 0)
                    _StatementRow(label: '资产处置损失', value: disposalLoss),
                  _StatementRow(label: '支出合计', value: expense, bold: true),
                  const Divider(height: 24),
                  _StatementRow(
                    label: '本月综合盈亏',
                    value: comprehensiveProfit,
                    bold: true,
                  ),
                ]),
                statement('个人资产负债表', [
                  _StatementRow(
                    label: '当前自由现金（现金及存款）',
                    value: store.cashAndDepositsForMonth(month),
                  ),
                  if (stock != null) ...[
                    _StatementRow(label: '股票持仓市值', value: stock.marketValue),
                    _StatementRow(label: '证券账户现金', value: stock.cashBalance),
                  ] else
                    _StatementRow(
                      label: '股票账户（最近快照及待确认转入）',
                      value: store.stockAccountAssetsAt(
                        DateTime(month.year, month.month + 1, 0, 23, 59, 59),
                      ),
                    ),
                  _StatementRow(
                    label: '可变现实物资产',
                    value: position?.physicalAssets ?? 0,
                  ),
                  _StatementRow(
                    label: '自动折旧资产账面价值',
                    value: store.depreciableAssetValueForMonth(month),
                  ),
                  _StatementRow(
                    label: '应收及其他资产',
                    value: position?.receivablesAndOtherAssets ?? 0,
                  ),
                  _StatementRow(
                    label: '资产合计',
                    value: store.totalAssetsForMonth(month),
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _StatementRow(
                    label: '短期负债',
                    value: position?.shortTermLiabilities ?? 0,
                  ),
                  _StatementRow(
                    label: '长期负债',
                    value: position?.longTermLiabilities ?? 0,
                  ),
                  _StatementRow(
                    label: '负债合计',
                    value: store.liabilitiesForMonth(month),
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _StatementRow(
                    label: '净资产',
                    value: closingNetWorth,
                    bold: true,
                  ),
                ], footer: position == null ? missingPosition : null),
                statement('个人现金流量表', [
                  _StatementRow(label: '经营现金流入', value: operatingInflow),
                  _StatementRow(label: '经营现金流出', value: operatingOutflow),
                  _StatementRow(
                    label: '经营活动现金流净额',
                    value: operatingNet,
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _StatementRow(
                    label: '投资现金流入（股票取出、分红、资产出售）',
                    value: investingInflow,
                  ),
                  _StatementRow(
                    label: '投资现金流出（股票投资、资本投入）',
                    value: investingOutflow,
                  ),
                  _StatementRow(
                    label: '投资活动现金流净额',
                    value: investingNet,
                    bold: true,
                  ),
                  const Divider(height: 24),
                  const _StatementRow(label: '融资活动现金流净额', value: 0),
                  _StatementRow(
                    label: '本月现金净变动',
                    value: netCashFlow,
                    bold: true,
                  ),
                  _StatementRow(
                    label: '本月自由现金流',
                    value: store.freeCashFlowForMonth(month),
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '股票投入和取出只在自由现金与股票账户之间划转，不会直接改变总资产或利润；尚未记录借款等融资交易。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ]),
                statement('个人净资产变动表', [
                  _StatementRow(label: '期初净资产', value: openingNetWorth),
                  _StatementRow(label: '本月综合盈亏', value: comprehensiveProfit),
                  _StatementRow(label: '估值、未记录转账及其他变动', value: otherChange),
                  _StatementRow(
                    label: '本月净资产变动',
                    value: netWorthChange,
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _StatementRow(
                    label: '期末净资产',
                    value: closingNetWorth,
                    bold: true,
                  ),
                  if (!hasPrevious) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '上月尚无资产快照，本月暂作为净资产基准月。',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.indent = false,
  });

  final String label;
  final double value;
  final bool bold;
  final bool indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(indent ? 16 : 0, 6, 0, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: indent ? Theme.of(context).colorScheme.outline : null,
            ),
          ),
        ),
        Text(
          '${value < 0 ? '-' : ''}¥${_money.format(value.abs())}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: value < 0 ? AppTheme.accent : null,
          ),
        ),
      ],
    ),
  );
}

class _IncomeExpenseSummary extends StatelessWidget {
  const _IncomeExpenseSummary({required this.income, required this.expense});
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatBox(
          label: '收入',
          value: income,
          color: const Color(0xFF4E8B73),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatBox(label: '支出', value: expense, color: AppTheme.accent),
      ),
    ],
  );
}

class _MonthlyTrendView extends StatelessWidget {
  const _MonthlyTrendView({
    required this.store,
    required this.endMonth,
    required this.range,
    required this.onRangeChanged,
  });
  final LedgerStore store;
  final DateTime endMonth;
  final _TrendRange range;
  final ValueChanged<_TrendRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final end = DateTime(endMonth.year, endMonth.month);
    final fixedCount = range.monthCount;
    final start = fixedCount == null ? _firstRecordedMonth(end) : null;
    final monthCount = fixedCount ?? _monthsBetween(start!, end) + 1;
    final months = List<DateTime>.generate(
      monthCount,
      (index) => fixedCount == null
          ? DateTime(start!.year, start.month + index)
          : DateTime(end.year, end.month - monthCount + 1 + index),
    );
    final income = months
        .map((month) => store.totalForMonth(month, EntryType.income))
        .toList();
    final regularExpense = months.map(store.regularExpenseForMonth).toList();
    final specialExpense = months.map(store.specialExpenseForMonth).toList();
    final expense = List<double>.generate(
      months.length,
      (index) => regularExpense[index] + specialExpense[index],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<_TrendRange>(
              key: const Key('trend-range'),
              value: range,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.expand_more_rounded),
              items: _TrendRange.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text('统计范围：${item.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onRangeChanged(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _IncomeExpenseSummary(income: income.last, expense: expense.last),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _ChartLegend(color: Color(0xFF4E8B73), label: '收入'),
                    _ChartLegend(color: AppTheme.accent, label: '常规支出'),
                    _ChartLegend(color: Color(0xFF7E57C2), label: '特别行动'),
                  ],
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: '${range.label}收入、常规支出和特别行动柱状图',
                  child: SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MonthlyBarPainter(
                        months: months,
                        income: income,
                        regularExpense: regularExpense,
                        specialExpense: specialExpense,
                        gridColor: Theme.of(context).colorScheme.outlineVariant,
                        labelColor: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DateTime _firstRecordedMonth(DateTime end) {
    DateTime? first;
    for (final entry in store.entries) {
      final month = DateTime(entry.date.year, entry.date.month);
      if (month.isAfter(end)) continue;
      if (first == null || month.isBefore(first)) first = month;
    }
    return first ?? end;
  }

  int _monthsBetween(DateTime start, DateTime end) =>
      (end.year - start.year) * 12 + end.month - start.month;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class _MonthlyBarPainter extends CustomPainter {
  const _MonthlyBarPainter({
    required this.months,
    required this.income,
    required this.regularExpense,
    required this.specialExpense,
    required this.gridColor,
    required this.labelColor,
  });
  final List<DateTime> months;
  final List<double> income;
  final List<double> regularExpense;
  final List<double> specialExpense;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0;
    const top = 10.0;
    const right = 8.0;
    const bottom = 30.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final expenseTotals = List<double>.generate(
      months.length,
      (index) => regularExpense[index] + specialExpense[index],
    );
    final rawMax = [...income, ...expenseTotals].fold<double>(0, math.max);
    final maxValue = rawMax <= 0 ? 1.0 : rawMax * 1.1;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final y = top + chartHeight * index / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      _paintLabel(
        canvas,
        _compactMoney(maxValue * (4 - index) / 4),
        Offset(0, y - 7),
      );
    }

    final labelStep = math.max(1, (months.length / 6).ceil());
    final groupWidth = chartWidth / months.length;
    final barWidth = math.min(12.0, math.max(2.0, groupWidth * .28));
    final incomePaint = Paint()..color = const Color(0xFF4E8B73);
    final regularPaint = Paint()..color = AppTheme.accent;
    final specialPaint = Paint()..color = const Color(0xFF7E57C2);
    for (var index = 0; index < months.length; index++) {
      final centerX = left + groupWidth * (index + .5);
      _drawBar(
        canvas,
        x: centerX - barWidth - 1,
        bottom: top + chartHeight,
        value: income[index],
        maxValue: maxValue,
        chartHeight: chartHeight,
        width: barWidth,
        paint: incomePaint,
      );
      final regularHeight = chartHeight * regularExpense[index] / maxValue;
      final specialHeight = chartHeight * specialExpense[index] / maxValue;
      final expenseX = centerX + 1;
      if (regularHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            expenseX,
            top + chartHeight - regularHeight,
            barWidth,
            regularHeight,
          ),
          regularPaint,
        );
      }
      if (specialHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            expenseX,
            top + chartHeight - regularHeight - specialHeight,
            barWidth,
            specialHeight,
          ),
          specialPaint,
        );
      }
      if (index % labelStep == 0 || index == months.length - 1) {
        final month = months[index];
        _paintLabel(
          canvas,
          months.length > 12
              ? '${month.year % 100}/${month.month}'
              : '${month.month}月',
          Offset(centerX - 13, size.height - 18),
        );
      }
    }
  }

  void _drawBar(
    Canvas canvas, {
    required double x,
    required double bottom,
    required double value,
    required double maxValue,
    required double chartHeight,
    required double width,
    required Paint paint,
  }) {
    if (value <= 0) return;
    final height = chartHeight * value / maxValue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - height, width, height),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _compactMoney(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1)}万';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}千';
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarPainter oldDelegate) =>
      oldDelegate.income != income ||
      oldDelegate.regularExpense != regularExpense ||
      oldDelegate.specialExpense != specialExpense ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}

class FinancialPositionPage extends StatefulWidget {
  const FinancialPositionPage({super.key, required this.store});

  final LedgerStore store;

  @override
  State<FinancialPositionPage> createState() => _FinancialPositionPageState();
}

class _FinancialPositionPageState extends State<FinancialPositionPage> {
  late DateTime _effectiveDate;
  final _cash = TextEditingController();
  final _physicalAssets = TextEditingController();
  final _otherAssets = TextEditingController();
  final _shortLiabilities = TextEditingController();
  final _longLiabilities = TextEditingController();

  @override
  void initState() {
    super.initState();
    _effectiveDate =
        widget.store.financialBaseline?.effectiveDate ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _cash.dispose();
    _physicalAssets.dispose();
    _otherAssets.dispose();
    _shortLiabilities.dispose();
    _longLiabilities.dispose();
    super.dispose();
  }

  void _setText(TextEditingController controller, double value) {
    controller.text = value == 0 ? '' : value.toStringAsFixed(2);
  }

  void _load() {
    final snapshot = widget.store.financialBaseline;
    _setText(_cash, snapshot?.cashAndDeposits ?? 0);
    _setText(_physicalAssets, snapshot?.physicalAssets ?? 0);
    _setText(_otherAssets, snapshot?.receivablesAndOtherAssets ?? 0);
    _setText(_shortLiabilities, snapshot?.shortTermLiabilities ?? 0);
    _setText(_longLiabilities, snapshot?.longTermLiabilities ?? 0);
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  Future<void> _save() async {
    final values = [
      _number(_cash),
      _number(_physicalAssets),
      _number(_otherAssets),
      _number(_shortLiabilities),
      _number(_longLiabilities),
    ];
    if (values.any((value) => value < 0)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('金额不能小于零')));
      return;
    }
    await widget.store.setFinancialBaseline(
      FinancialBaseline(
        effectiveDate: _effectiveDate,
        cashAndDeposits: values[0],
        physicalAssets: values[1],
        receivablesAndOtherAssets: values[2],
        shortTermLiabilities: values[3],
        longTermLiabilities: values[4],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget amountField({
      required Key key,
      required String label,
      required TextEditingController controller,
      String? helper,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '¥ ',
          helperText: helper,
          helperMaxLines: 2,
        ),
      ),
    );

    final stock = widget.store.stockSnapshotForMonth(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '初始化资产负债',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('financial-position-list'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_circle_outlined),
              title: const Text('初始化日期'),
              subtitle: const Text('从这一天开始累计后续所有收入和支出'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDate: _effectiveDate,
                  );
                  if (picked != null) setState(() => _effectiveDate = picked);
                },
                child: Text(DateFormat('yyyy年M月d日').format(_effectiveDate)),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '一次性初始资产',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '保存后不需要每月更新。初始化日期之后的每笔收入和支出都会持续累计。股票账户自动计入 ¥${_money.format(stock?.totalAssets ?? 0)}，请勿重复填写。',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 18),
                    amountField(
                      key: const Key('position-cash'),
                      label: '初始自由现金及存款',
                      controller: _cash,
                      helper: '不含证券账户现金',
                    ),
                    amountField(
                      key: const Key('position-physical-assets'),
                      label: '可变现实物资产',
                      controller: _physicalAssets,
                      helper: '初始化时已拥有的手机、电脑、衣物等按预计二手可售价格填写',
                    ),
                    amountField(
                      key: const Key('position-other-assets'),
                      label: '应收款及其他资产',
                      controller: _otherAssets,
                    ),
                    const Divider(height: 28),
                    const Text(
                      '负债',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    amountField(
                      key: const Key('position-short-liabilities'),
                      label: '短期负债',
                      controller: _shortLiabilities,
                      helper: '信用卡、花呗及一年内需偿还借款',
                    ),
                    amountField(
                      key: const Key('position-long-liabilities'),
                      label: '长期负债',
                      controller: _longLiabilities,
                      helper: '一年后偿还的贷款等',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('save-financial-position'),
              onPressed: _save,
              child: const Text(
                '保存初始资产',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StockSnapshotPage extends StatefulWidget {
  const StockSnapshotPage({
    super.key,
    required this.store,
    required this.initialMonth,
  });
  final LedgerStore store;
  final DateTime initialMonth;

  @override
  State<StockSnapshotPage> createState() => _StockSnapshotPageState();
}

class _StockSnapshotPageState extends State<StockSnapshotPage> {
  late DateTime _month;
  final _marketValue = TextEditingController();
  final _cashBalance = TextEditingController();
  final _dividend = TextEditingController();
  final _fees = TextEditingController();

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _loadSnapshot();
  }

  @override
  void dispose() {
    _marketValue.dispose();
    _cashBalance.dispose();
    _dividend.dispose();
    _fees.dispose();
    super.dispose();
  }

  void _loadSnapshot() {
    final snapshot = widget.store.stockSnapshotForMonth(_month);
    _setText(_marketValue, snapshot?.marketValue ?? 0);
    _setText(_cashBalance, snapshot?.cashBalance ?? 0);
    _setText(_dividend, snapshot?.dividendReceived ?? 0);
    _setText(_fees, snapshot?.feesAndTaxes ?? 0);
  }

  void _setText(TextEditingController controller, double value) {
    controller.text = value == 0 ? '' : value.toStringAsFixed(2);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loadSnapshot();
    });
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  Future<void> _save() async {
    final values = [
      _number(_marketValue),
      _number(_cashBalance),
      _number(_dividend),
      _number(_fees),
    ];
    if (values.any((value) => value < 0)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('金额不能小于零')));
      return;
    }
    await widget.store.upsertStockSnapshot(
      StockMonthlySnapshot(
        month: _month,
        marketValue: values[0],
        cashBalance: values[1],
        externalInflow: widget.store.stockInvestmentSincePreviousSnapshot(
          _month,
        ),
        externalOutflow: widget.store.stockWithdrawalSincePreviousSnapshot(
          _month,
        ),
        dividendReceived: values[2],
        feesAndTaxes: values[3],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget amountField({
      required Key key,
      required String label,
      required TextEditingController controller,
      String? helper,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '¥ ',
          helperText: helper,
        ),
      ),
    );

    final existing = widget.store.stockSnapshotForMonth(_month);
    final automaticInflow = widget.store.stockInvestmentSincePreviousSnapshot(
      _month,
    );
    final automaticOutflow = widget.store.stockWithdrawalSincePreviousSnapshot(
      _month,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '股票月度快照',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const Key('stock-snapshot-list'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _MonthPicker(month: _month, onChanged: _changeMonth),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _month = DateTime(now.year, now.month);
                    _loadSnapshot();
                  });
                },
                icon: const Icon(Icons.today_rounded),
                label: const Text('回到本月'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? '建立本月快照' : '修改本月快照',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '账户总资产 = 持仓市值 + 证券账户现金。第一条快照作为计算基准。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 18),
                    amountField(
                      key: const Key('stock-market-value'),
                      label: '月末持仓市值',
                      controller: _marketValue,
                    ),
                    amountField(
                      key: const Key('stock-cash-balance'),
                      label: '月末证券账户现金',
                      controller: _cashBalance,
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '从上次快照至本月：投入 ¥${_money.format(automaticInflow)} · '
                        '取出 ¥${_money.format(automaticOutflow)}\n'
                        '金额由“投资”流水自动汇总，无需重复填写。',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    amountField(
                      key: const Key('stock-dividend'),
                      label: '本月实际到账分红',
                      controller: _dividend,
                      helper: '分红已进入证券账户，仅展示收益构成，不重复增加总盈亏',
                    ),
                    amountField(
                      key: const Key('stock-fees'),
                      label: '本月手续费及税费',
                      controller: _fees,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('save-stock-snapshot'),
              onPressed: _save,
              child: const Text(
                '保存月度快照',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});
  final LedgerStore store;

  Future<void> _editBudget(BuildContext context) async {
    final controller = TextEditingController(
      text: store.monthlyBudget.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置每月预算'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value != null && value > 0) await store.setBudget(value);
  }

  Future<void> _exportData(BuildContext context) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '选择导出格式',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('JSON 可完整恢复；CSV 仅用于查看收支流水'),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: const Text('完整备份（JSON）'),
              subtitle: const Text('包含流水、资产、股票、预算和特别行动'),
              onTap: () => Navigator.pop(sheetContext, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_rounded),
              title: const Text('流水表格（CSV）'),
              subtitle: const Text('可用 Excel 等表格软件查看，不支持导入恢复'),
              onTap: () => Navigator.pop(sheetContext, 'csv'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;

    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final isJson = format == 'json';
    final content = isJson
        ? store.exportBackupJson()
        : store.exportEntriesCsv();
    final name = '简账-$stamp.${isJson ? 'json' : 'csv'}';
    await _exportChannel.invokeMethod<void>('shareFile', {
      'name': name,
      'mimeType': isJson ? 'application/json' : 'text/csv',
      'contentBase64': base64Encode(utf8.encode(content)),
      'chooserTitle': '导出简账数据',
    });
  }

  Future<void> _importData(BuildContext context) async {
    try {
      const jsonType = XTypeGroup(
        label: '简账 JSON 备份',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      final file = await openFile(acceptedTypeGroups: const [jsonType]);
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      final source = utf8.decode(bytes, allowMalformed: false);
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('导入完整备份？'),
          content: const Text(
            '导入将用备份中的流水、资产、股票、预算和特别行动覆盖当前本机数据。建议先导出一份当前 JSON 备份。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await store.importBackupJson(source);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导入完成，所有页面已更新')));
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：${error.message}')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导入失败，请选择由简账导出的 JSON 文件')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(
      IconData icon,
      String title, {
      String? subtitle,
      VoidCallback? onTap,
    }) => ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap:
          onTap ??
          () =>
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$title将在后续版本开放'))),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        const Text(
          '我的',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的个人账本',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('数据仅保存在本机', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          '常规预算',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Card(
          child: tile(
            Icons.savings_outlined,
            '预算设置',
            subtitle: '¥${_money.format(store.monthlyBudget)} / 月',
            onTap: () => _editBudget(context),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '数据与安全',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              tile(
                Icons.file_download_outlined,
                '导出',
                subtitle: '完整 JSON 备份或 CSV 流水',
                onTap: () => _exportData(context),
              ),
              const Divider(height: 1, indent: 72),
              tile(
                Icons.file_upload_outlined,
                '导入',
                subtitle: '从简账 JSON 完整备份恢复',
                onTap: () => _importData(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '关于简账',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Card(
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.new_releases_outlined),
                    SizedBox(width: 10),
                    Text(
                      '版本 1.5.6 更新内容',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Text('• “记一笔”新增独立的“投资”类型'),
                SizedBox(height: 7),
                Text('• 股票投资不再计入收入、支出或消费预算'),
                SizedBox(height: 7),
                Text('• 支持“投入”：自由现金转入股票账户'),
                SizedBox(height: 7),
                Text('• 支持“取出”：股票账户资金转回自由现金'),
                SizedBox(height: 7),
                Text('• 投入和取出金额自动汇总到股票月度快照'),
                Divider(height: 28),
                Text('历史版本', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 7),
                Text('1.5.5 · 股票投资划转与月末快照联动'),
                SizedBox(height: 7),
                Text('1.5.4 · JSON/CSV 导出与 JSON 完整恢复'),
                SizedBox(height: 7),
                Text('1.5.3 · 一次初始化与永久滚动总账'),
                SizedBox(height: 7),
                Text('1.5.2 · 当前自由现金与资产负债表联动'),
                SizedBox(height: 7),
                Text('1.5.1 · 页面重排、折旧资产与实时净资产'),
                SizedBox(height: 7),
                Text('1.5.0 · 个人财务三表与净资产变动表'),
                SizedBox(height: 7),
                Text('1.4.0 · 股票账户月度快照与月度盈亏'),
                SizedBox(height: 7),
                Text('1.3.0 · 特别行动、常规预算隔离与月度柱状图'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key, required this.store});
  final LedgerStore store;
  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  EntryType _type = EntryType.expense;
  String _category = expenseCategories.first;
  String? _specialActionId;
  bool _isDepreciable = false;
  int _depreciationMonths = 36;
  bool _isAssetSale = false;
  String? _disposedAssetId;
  InvestmentDirection _investmentDirection = InvestmentDirection.deposit;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _residualValue = TextEditingController();

  bool get _isStockInvestment => _type == EntryType.investment;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _residualValue.dispose();
    super.dispose();
  }

  void _switchType(EntryType value) {
    setState(() {
      _type = value;
      _category = switch (value) {
        EntryType.expense => expenseCategories.first,
        EntryType.income => incomeCategories.first,
        EntryType.investment => '股票投资',
      };
      if (value == EntryType.income) {
        _specialActionId = null;
        _isDepreciable = false;
      } else if (value == EntryType.expense) {
        _isAssetSale = false;
        _disposedAssetId = null;
      } else {
        _specialActionId = null;
        _isDepreciable = false;
        _isAssetSale = false;
        _disposedAssetId = null;
      }
    });
  }

  void _save() {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入正确的金额')));
      return;
    }
    final residualValue =
        double.tryParse(_residualValue.text.replaceAll(',', '')) ?? 0;
    if (_isDepreciable && (residualValue < 0 || residualValue >= amount)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('预计残值应大于等于零且小于购买金额')));
      return;
    }
    if (_type == EntryType.income && _isAssetSale && _disposedAssetId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择出售的资产')));
      return;
    }
    if (_isStockInvestment &&
        _investmentDirection == InvestmentDirection.withdraw) {
      final available = widget.store.stockAccountAssetsAt(
        DateTime(_date.year, _date.month, _date.day, 23, 59, 59),
      );
      if (amount > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('取出金额不能超过当前股票账户资产 ¥${_money.format(available)}'),
          ),
        );
        return;
      }
    }
    Navigator.pop(
      context,
      LedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        amount: amount,
        category: _category,
        account: '未设置',
        date: _date,
        note: _note.text.trim(),
        specialActionId: _type == EntryType.expense && !_isStockInvestment
            ? _specialActionId
            : null,
        isDepreciable:
            _type == EntryType.expense && !_isStockInvestment && _isDepreciable,
        depreciationMonths: _depreciationMonths,
        residualValue: residualValue,
        disposedAssetId: _type == EntryType.income && _isAssetSale
            ? _disposedAssetId
            : null,
        investmentDirection: _isStockInvestment ? _investmentDirection : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = switch (_type) {
      EntryType.expense => expenseCategories,
      EntryType.income => incomeCategories,
      EntryType.investment => const <String>['股票投资'],
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            children: [
              SegmentedButton<EntryType>(
                segments: const [
                  ButtonSegment(value: EntryType.expense, label: Text('支出')),
                  ButtonSegment(value: EntryType.income, label: Text('收入')),
                  ButtonSegment(value: EntryType.investment, label: Text('投资')),
                ],
                selected: {_type},
                onSelectionChanged: (value) => _switchType(value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('amount-input'),
                controller: _amount,
                autofocus: false,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '¥ ',
                  filled: false,
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              if (_isStockInvestment)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.candlestick_chart_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: const Text(
                      '股票投资',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('当前投资账户类型'),
                    trailing: const Icon(Icons.check_circle_rounded),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: .85,
                    mainAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    final selected = item == _category;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() {
                        _category = item;
                        if (_isStockInvestment) {
                          _isDepreciable = false;
                          _specialActionId = null;
                        }
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            child: Icon(
                              categoryIcon(item),
                              size: 20,
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              if (_isStockInvestment) ...[
                SegmentedButton<InvestmentDirection>(
                  key: const Key('investment-direction'),
                  segments: const [
                    ButtonSegment(
                      value: InvestmentDirection.deposit,
                      icon: Icon(Icons.arrow_forward_rounded),
                      label: Text('投入'),
                    ),
                    ButtonSegment(
                      value: InvestmentDirection.withdraw,
                      icon: Icon(Icons.arrow_back_rounded),
                      label: Text('取出'),
                    ),
                  ],
                  selected: {_investmentDirection},
                  onSelectionChanged: (value) =>
                      setState(() => _investmentDirection = value.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (_type == EntryType.expense && !_isStockInvestment)
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        key: const Key('depreciation-select'),
                        initialValue: _isDepreciable,
                        decoration: const InputDecoration(
                          labelText: '资产处理',
                          prefixIcon: Icon(Icons.devices_other_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: false, child: Text('直接消费')),
                          DropdownMenuItem(value: true, child: Text('计入折旧资产')),
                        ],
                        onChanged: (value) =>
                            setState(() => _isDepreciable = value ?? false),
                      ),
                    )
                  else if (_type == EntryType.income)
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        key: const Key('income-kind-select'),
                        initialValue: _isAssetSale,
                        decoration: const InputDecoration(
                          labelText: '收入类型',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: false, child: Text('普通收入')),
                          DropdownMenuItem(value: true, child: Text('出售资产')),
                        ],
                        onChanged: (value) =>
                            setState(() => _isAssetSale = value ?? false),
                      ),
                    ),
                  if (!_isStockInvestment) const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          initialDate: _date,
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '日期',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(DateFormat('M月d日').format(_date)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isStockInvestment) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '投入：自由现金转入股票账户。\n取出：股票账户资金转回自由现金。\n两者都不属于收入或支出，也不会直接改变总资产和利润。',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == EntryType.expense && _isDepreciable) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const Key('depreciation-months'),
                        initialValue: _depreciationMonths,
                        decoration: const InputDecoration(
                          labelText: '折旧期限',
                          prefixIcon: Icon(Icons.timelapse_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 12, child: Text('1年')),
                          DropdownMenuItem(value: 24, child: Text('2年')),
                          DropdownMenuItem(value: 36, child: Text('3年')),
                          DropdownMenuItem(value: 60, child: Text('5年')),
                        ],
                        onChanged: (value) =>
                            setState(() => _depreciationMonths = value ?? 36),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const Key('residual-value'),
                        controller: _residualValue,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '预计残值',
                          prefixText: '¥ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '购买金额先计入资产，再按月直线折旧；出售时自动确认处置损益。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == EntryType.income && _isAssetSale) ...[
                DropdownButtonFormField<String>(
                  key: const Key('disposed-asset-select'),
                  initialValue: _disposedAssetId,
                  decoration: const InputDecoration(
                    labelText: '出售哪项资产',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    helperText: '售价高于账面价值为处置收益，低于账面价值为处置损失',
                  ),
                  items: widget.store
                      .activeDepreciableAssets(_date)
                      .map(
                        (asset) => DropdownMenuItem(
                          value: asset.id,
                          child: Text(
                            asset.note.isEmpty ? asset.category : asset.note,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _disposedAssetId = value),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == EntryType.expense && !_isStockInvestment) ...[
                DropdownButtonFormField<String>(
                  key: const Key('special-action-select'),
                  initialValue: _specialActionId ?? '',
                  decoration: const InputDecoration(
                    labelText: '预算归属',
                    prefixIcon: Icon(Icons.flag_outlined),
                    helperText: '特别行动支出不会占用常规预算',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('常规预算')),
                    ...widget.store.specialActions.map(
                      (action) => DropdownMenuItem(
                        value: action.id,
                        child: Text('特别行动 · ${action.name}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _specialActionId = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('save-entry'),
              onPressed: _save,
              child: const Text(
                '保存这笔账',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 12, 18),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: () => onChanged(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(
        '${month.year}年 ${month.month}月',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      IconButton(
        onPressed: () => onChanged(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.actionName});
  final LedgerEntry entry;
  final String? actionName;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    final investment = entry.type == EntryType.investment;
    final investmentColor = const Color(0xFF5577B8);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: actionName != null
            ? const Color(0x1A7E57C2)
            : investment
            ? const Color(0x185577B8)
            : income
            ? const Color(0x174E8B73)
            : const Color(0x18F29F67),
        child: Icon(
          actionName == null
              ? categoryIcon(entry.category)
              : Icons.rocket_launch_rounded,
          color: actionName != null
              ? const Color(0xFF7E57C2)
              : investment
              ? investmentColor
              : income
              ? const Color(0xFF4E8B73)
              : const Color(0xFFE48448),
        ),
      ),
      title: Text(
        entry.note.isEmpty ? entry.category : entry.note,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          entry.category,
          if (entry.isStockDeposit) '投入股票账户',
          if (entry.isStockWithdrawal) '取回自由现金',
          if (actionName != null) actionName,
          if (entry.isDepreciable) '折旧资产 · ${entry.depreciationMonths}个月',
          if (entry.disposedAssetId != null) '出售资产',
        ].join(' · '),
      ),
      trailing: Text(
        '${entry.isStockWithdrawal || income ? '+' : '-'}¥${_money.format(entry.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: investment
              ? investmentColor
              : income
              ? const Color(0xFF4E8B73)
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '¥${_money.format(value)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.value, required this.budget});
  final double value;
  final double budget;
  @override
  Widget build(BuildContext context) {
    final ratio = budget == 0 ? 0.0 : (value / budget).clamp(0.0, 1.0);
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 15,
              strokeCap: StrokeCap.round,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              color: AppTheme.accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('预算使用', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.value,
    required this.maxValue,
    required this.total,
  });
  final String name;
  final double value;
  final double maxValue;
  final double total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            categoryIcon(name),
            size: 17,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: maxValue == 0 ? 0 : value / maxValue,
              minHeight: 8,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              color: AppTheme.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${_money.format(value)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '${total == 0 ? 0 : (value / total * 100).round()}%',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    ),
  );
}
