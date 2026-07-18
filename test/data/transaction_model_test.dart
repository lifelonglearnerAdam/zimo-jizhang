import 'package:flutter_test/flutter_test.dart';
import 'package:zimo_jizhang/data/models.dart';

void main() {
  test('copyWith edits requested fields and preserves record identity', () {
    final createdAt = DateTime(2026, 7, 1, 9);
    final transaction = TransactionModel(
      id: 'existing-record',
      amountFen: 1280,
      categoryId: 2,
      transactionDate: '2026-07-01',
      description: '早餐',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final edited = transaction.copyWith(
      amountFen: 1580,
      categoryId: 3,
      description: '午餐',
    );

    expect(edited.id, transaction.id);
    expect(edited.createdAt, createdAt);
    expect(edited.amountFen, 1580);
    expect(edited.categoryId, 3);
    expect(edited.description, '午餐');
    expect(edited.transactionDate, '2026-07-01');
  });

  test('copyWith can clear an existing description', () {
    final now = DateTime(2026, 7, 1);
    final transaction = TransactionModel(
      id: 'clear-note',
      amountFen: 100,
      transactionDate: '2026-07-01',
      description: '旧备注',
      createdAt: now,
      updatedAt: now,
    );

    expect(transaction.copyWith(description: null).description, isNull);
  });
}
