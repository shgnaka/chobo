import 'chobo_records.dart';

class ChoboStandardAccounts {
  ChoboStandardAccounts._();

  static const List<ChoboStandardAccountDefinition> definitions =
      <ChoboStandardAccountDefinition>[
    ChoboStandardAccountDefinition(
      accountId: 'asset:cash',
      kind: 'asset',
      displayName: 'Cash',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'asset:bank:main',
      kind: 'asset',
      displayName: 'Main Bank',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'asset:e_money',
      kind: 'asset',
      displayName: 'E Money',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'asset:saving',
      kind: 'asset',
      displayName: 'Savings',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'liability:card:main',
      kind: 'liability',
      displayName: 'Main Card',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'liability:other_payable',
      kind: 'liability',
      displayName: 'Other Payable',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'income:salary',
      kind: 'income',
      displayName: 'Salary',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'income:side_job',
      kind: 'income',
      displayName: 'Side Job',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'income:refund',
      kind: 'income',
      displayName: 'Refund',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'income:point_reward',
      kind: 'income',
      displayName: 'Point Reward',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'income:adjustment',
      kind: 'income',
      displayName: 'Adjustment',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:food',
      kind: 'expense',
      displayName: 'Food',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:housing',
      kind: 'expense',
      displayName: 'Housing',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:utilities',
      kind: 'expense',
      displayName: 'Utilities',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:communication',
      kind: 'expense',
      displayName: 'Communication',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:transport',
      kind: 'expense',
      displayName: 'Transport',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:daily_goods',
      kind: 'expense',
      displayName: 'Daily Goods',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:medical',
      kind: 'expense',
      displayName: 'Medical',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:education',
      kind: 'expense',
      displayName: 'Education',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:entertainment',
      kind: 'expense',
      displayName: 'Entertainment',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:social',
      kind: 'expense',
      displayName: 'Social',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:special',
      kind: 'expense',
      displayName: 'Special',
    ),
    ChoboStandardAccountDefinition(
      accountId: 'expense:adjustment',
      kind: 'expense',
      displayName: 'Adjustment',
    ),
  ];
}
