import '../models/trip.dart';

class BudgetPortion {
  const BudgetPortion({
    required this.category,
    required this.amount,
    required this.share,
    required this.count,
  });

  final ExpenseCategory category;
  final double amount;

  /// Fraction of the total budget, 0..1.
  final double share;

  /// How many individual entries make up this category.
  final int count;
}

/// CoinBudget. With no entries the result stays empty rather than inventing a
/// plausible-looking budget.
class BudgetResult {
  const BudgetResult({
    required this.total,
    required this.perPerson,
    required this.portions,
    required this.entryCount,
  });

  final double total;
  final double perPerson;
  final List<BudgetPortion> portions;
  final int entryCount;

  bool get isEmpty => entryCount == 0;

  BudgetPortion? get largest => portions.isEmpty ? null : portions.first;

  static BudgetResult of(Trip trip) {
    final sums = <ExpenseCategory, double>{};
    final counts = <ExpenseCategory, int>{};
    for (final expense in trip.expenses) {
      sums[expense.category] = (sums[expense.category] ?? 0) + expense.amount;
      counts[expense.category] = (counts[expense.category] ?? 0) + 1;
    }

    final total = sums.values.fold<double>(0, (sum, value) => sum + value);
    final portions =
        sums.entries
            .map(
              (entry) => BudgetPortion(
                category: entry.key,
                amount: entry.value,
                share: total == 0 ? 0 : entry.value / total,
                count: counts[entry.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return BudgetResult(
      total: total,
      perPerson: trip.people == 0 ? total : total / trip.people,
      portions: portions,
      entryCount: trip.expenses.length,
    );
  }
}
