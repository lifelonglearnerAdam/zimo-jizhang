import 'package:flutter_test/flutter_test.dart';
import 'package:zimo_jizhang/data/models.dart';

void main() {
  test('financial goal progress uses fen and clamps at 100 percent', () {
    final now = DateTime(2026, 7, 22);
    final goal = FinancialGoal(
      name: '应急金',
      targetFen: 100000,
      currentFen: 120000,
      createdAt: now,
      updatedAt: now,
    );

    expect(goal.progress, 1);
    expect(goal.remainingFen, 0);
  });

  test('financial goal reports remaining amount in fen', () {
    final now = DateTime(2026, 7, 22);
    final goal = FinancialGoal(
      name: '旅行',
      targetFen: 300000,
      currentFen: 82500,
      createdAt: now,
      updatedAt: now,
    );

    expect(goal.progress, closeTo(0.275, 0.0001));
    expect(goal.remainingFen, 217500);
  });
}
