import 'package:flutter_test/flutter_test.dart';
import 'package:chobo/integration/integration.dart';

void main() {
  group('ImportedTransaction', () {
    test('creates from constructor', () {
      final transaction = ImportedTransaction(
        date: DateTime(2026, 3, 15),
        description: 'Test Store',
        amount: 1500,
        counterparty: 'Test Store',
      );

      expect(transaction.date, DateTime(2026, 3, 15));
      expect(transaction.description, 'Test Store');
      expect(transaction.amount, 1500);
      expect(transaction.counterparty, 'Test Store');
      expect(transaction.inferredType, isNull);
    });

    test('creates with inferred type', () {
      final transaction = ImportedTransaction(
        date: DateTime(2026, 3, 15),
        description: 'Grocery Store',
        amount: 2500,
        inferredType: InferredTransactionType.expense,
      );

      expect(transaction.inferredType, InferredTransactionType.expense);
      expect(transaction.inferredType?.displayName, 'Expense');
    });

    test('serializes to JSON', () {
      final transaction = ImportedTransaction(
        externalId: 'ext_123',
        date: DateTime(2026, 3, 15),
        description: 'Test',
        amount: 1000,
        confidence: 0.95,
      );

      final json = transaction.toJson();

      expect(json['externalId'], 'ext_123');
      expect(json['description'], 'Test');
      expect(json['amount'], 1000);
      expect(json['confidence'], 0.95);
    });

    test('deserializes from JSON', () {
      final json = {
        'externalId': 'ext_456',
        'date': '2026-03-15T00:00:00.000',
        'description': 'Store Purchase',
        'amount': 2000,
        'inferredType': 'expense',
        'confidence': 0.9,
      };

      final transaction = ImportedTransaction.fromJson(json);

      expect(transaction.externalId, 'ext_456');
      expect(transaction.description, 'Store Purchase');
      expect(transaction.amount, 2000);
      expect(transaction.inferredType, InferredTransactionType.expense);
    });

    test('copyWith creates modified copy', () {
      final original = ImportedTransaction(
        date: DateTime(2026, 3, 15),
        description: 'Original',
        amount: 1000,
      );

      final modified = original.copyWith(
        description: 'Modified',
        amount: 2000,
      );

      expect(modified.description, 'Modified');
      expect(modified.amount, 2000);
      expect(modified.date, original.date);
    });
  });

  group('InferredTransactionType', () {
    test('has correct display names', () {
      expect(InferredTransactionType.income.displayName, 'Income');
      expect(InferredTransactionType.expense.displayName, 'Expense');
      expect(InferredTransactionType.transfer.displayName, 'Transfer');
      expect(InferredTransactionType.creditExpense.displayName, 'Credit Card');
      expect(InferredTransactionType.liabilityPayment.displayName, 'Payment');
    });
  });
}
