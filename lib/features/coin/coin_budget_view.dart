import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_images.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../data/providers.dart';
import '../../domain/calc/budget_breakdown.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../domain/models/trip.dart';
import '../../shared/widgets/fp_action_row.dart';
import '../../shared/widgets/fp_art.dart';
import '../../shared/widgets/fp_card.dart';
import '../../shared/widgets/fp_inputs.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_section_header.dart';

const _uuid = Uuid();

Color _categoryColor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.transport => FpColors.skyDeep,
  ExpenseCategory.food => FpColors.goldDeep,
  ExpenseCategory.parking => FpColors.graphiteMid,
  ExpenseCategory.gear => FpColors.forest,
  ExpenseCategory.other => FpColors.forestSoft,
};

IconData _categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.transport => Icons.directions_bus_rounded,
  ExpenseCategory.food => Icons.restaurant_rounded,
  ExpenseCategory.parking => Icons.local_parking_rounded,
  ExpenseCategory.gear => Icons.backpack_rounded,
  ExpenseCategory.other => Icons.more_horiz_rounded,
};

/// CoinBudget: what the trip costs, split by category and per person. With no
/// entries it says so instead of inventing a figure.
class CoinBudgetView extends ConsumerWidget {
  const CoinBudgetView({required this.analysis, super.key});

  final TripAnalysis analysis;

  Future<void> _editExpense(
    BuildContext context,
    WidgetRef ref, {
    Expense? existing,
  }) async {
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseSheet(
        existing: existing,
        currencySymbol: ref.read(settingsProvider).currencySymbol,
      ),
    );
    if (result == null) return;

    final trip = analysis.trip;
    final expenses = [...trip.expenses];
    final index = expenses.indexWhere((item) => item.id == result.id);
    if (index == -1) {
      expenses.add(result);
      FpFeedback.instance.success(FpSound.addItem);
    } else {
      expenses[index] = result;
      FpFeedback.instance.success(FpSound.successfulAction);
    }
    await ref
        .read(tripsProvider.notifier)
        .save(trip.copyWith(expenses: expenses));
  }

  Future<void> _remove(WidgetRef ref, Expense expense) async {
    final trip = analysis.trip;
    FpFeedback.instance.play(FpSound.removeItem);
    await ref.read(tripsProvider.notifier).save(
      trip.copyWith(
        expenses: trip.expenses
            .where((item) => item.id != expense.id)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = analysis.budget;
    final format = ref.watch(formatProvider);
    final trip = analysis.trip;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            FpSpace.md,
            0,
            FpSpace.md,
            FpSpace.xxl + FpSpace.xl,
          ),
          children: [
            FpCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL BUDGET', style: FpTypography.overline),
                      Text(
                        budget.isEmpty
                            ? 'Not started'
                            : format.money(budget.total),
                        style: budget.isEmpty
                            ? FpTypography.titleLarge
                            : FpTypography.heroMetric.copyWith(fontSize: 44),
                      ),
                      Text(
                        budget.isEmpty
                            ? 'No expenses entered'
                            : '${format.money(budget.perPerson)} per person · '
                                  '${budget.entryCount} '
                                  '${budget.entryCount == 1 ? 'entry' : 'entries'}',
                        style: FpTypography.caption,
                      ),
                    ],
                  ),
                  const Spacer(),
                  FpArt(
                    budget.isEmpty
                        ? FpImages.coinSingle
                        : (budget.total > 200
                              ? FpImages.coinColumn
                              : FpImages.coinStack),
                    size: 70,
                    height: 80,
                  ),
                ],
              ),
            ),
            if (budget.isEmpty) ...[
              const SizedBox(height: FpSpace.md),
              FpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nothing added yet', style: FpTypography.title),
                    const SizedBox(height: FpSpace.xxs),
                    Text(
                      'Add the costs you already know — fuel, permits, a night '
                      'in a hut. Partial is fine; the total only counts what '
                      'you entered.',
                      style: FpTypography.body,
                    ),
                    const SizedBox(height: FpSpace.sm),
                    Wrap(
                      spacing: FpSpace.xs,
                      runSpacing: FpSpace.xs,
                      children: [
                        for (final category in ExpenseCategory.values)
                          OutlinedButton.icon(
                            onPressed: () => _editExpense(
                              context,
                              ref,
                              existing: Expense(
                                id: _uuid.v4(),
                                label: category.label,
                                category: category,
                                amount: 0,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: FpSpace.sm,
                              ),
                            ),
                            icon: Icon(_categoryIcon(category), size: 16),
                            label: Text(category.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: FpSpace.md),
              const FpSectionHeader(label: 'By category'),
              const SizedBox(height: FpSpace.xs),
              FpCard(
                child: Column(
                  children: [
                    for (final portion in budget.portions) ...[
                      _PortionRow(portion: portion),
                      if (portion != budget.portions.last)
                        const SizedBox(height: FpSpace.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: FpSpace.md),
              FpSectionHeader(
                label: 'Entries · ${trip.expenses.length}',
                trailing: TextButton.icon(
                  onPressed: () => _editExpense(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: FpSpace.xs),
              FpCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: FpSpace.sm,
                  vertical: FpSpace.xxs,
                ),
                child: Column(
                  children: [
                    for (final expense in trip.expenses)
                      Dismissible(
                        key: ValueKey(expense.id),
                        direction: DismissDirection.endToStart,
                        background: const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: FpColors.severe,
                          ),
                        ),
                        onDismissed: (_) => _remove(ref, expense),
                        child: InkWell(
                          onTap: () =>
                              _editExpense(context, ref, existing: expense),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcon(expense.category),
                                  size: 18,
                                  color: _categoryColor(expense.category),
                                ),
                                const SizedBox(width: FpSpace.xs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.label,
                                        style: FpTypography.body,
                                      ),
                                      Text(
                                        expense.category.label,
                                        style: FpTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  format.money(expense.amount),
                                  style: FpTypography.bodyStrong,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: FpSpace.md),
            FpNotice(
              message:
                  'All amounts are your own estimates in '
                  '${ref.watch(settingsProvider).currencySymbol}, stored on '
                  'this device. Nothing is fetched, converted or sent anywhere.',
            ),
          ],
        ),
        Positioned(
          right: FpSpace.md,
          bottom: FpSpace.md,
          child: FloatingActionButton.small(
            onPressed: () => _editExpense(context, ref),
            backgroundColor: FpColors.goldDeep,
            foregroundColor: Colors.white,
            tooltip: 'Add expense',
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _PortionRow extends ConsumerWidget {
  const _PortionRow({required this.portion});

  final BudgetPortion portion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(formatProvider);
    return Column(
      children: [
        Row(
          children: [
            Icon(
              _categoryIcon(portion.category),
              size: 18,
              color: _categoryColor(portion.category),
            ),
            const SizedBox(width: FpSpace.xs),
            Expanded(
              child: Text(portion.category.label, style: FpTypography.body),
            ),
            Text(format.money(portion.amount), style: FpTypography.bodyStrong),
            const SizedBox(width: FpSpace.xs),
            SizedBox(
              width: 38,
              child: Text(
                '${(portion.share * 100).round()}%',
                textAlign: TextAlign.right,
                style: FpTypography.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FpShareBar(share: portion.share, color: _categoryColor(portion.category)),
      ],
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({required this.currencySymbol, this.existing});

  final Expense? existing;
  final String currencySymbol;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late ExpenseCategory _category =
      widget.existing?.category ?? ExpenseCategory.transport;
  late double? _amount =
      (widget.existing?.amount ?? 0) == 0 ? null : widget.existing!.amount;

  bool get _isNew => widget.existing == null || widget.existing!.amount == 0;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (_amount == null || _amount == 0) {
      FpFeedback.instance.warn();
      return;
    }
    Navigator.pop(
      context,
      Expense(
        id: widget.existing?.id ?? _uuid.v4(),
        label: label.isEmpty ? _category.label : label,
        category: _category,
        amount: _amount!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FpFormSheet(
      title: _isNew ? 'Add expense' : 'Edit expense',
      description: 'Your own estimate, stored on this device.',
      actionLabel: _isNew ? 'Add to budget' : 'Save expense',
      onSubmit: _submit,
      fields: [
        const FpFieldLabel(text: 'What is it', optional: true),
        TextField(
          controller: _label,
          textCapitalization: TextCapitalization.sentences,
          autofillHints: const [],
          decoration: InputDecoration(hintText: _category.label, isDense: true),
          style: FpTypography.bodyStrong,
        ),
        const SizedBox(height: FpSpace.sm),
        FpNumberField(
          label: 'Amount',
          unit: widget.currencySymbol,
          value: _amount,
          decimals: 2,
          max: 1000000,
          onChanged: (value) => setState(() => _amount = value),
        ),
        const SizedBox(height: FpSpace.sm),
        FpChoiceGroup<ExpenseCategory>(
          label: 'Category',
          options: [
            for (final category in ExpenseCategory.values)
              (category, category.label),
          ],
          selected: _category,
          onChanged: (value) => setState(() => _category = value),
        ),
      ],
    );
  }
}
