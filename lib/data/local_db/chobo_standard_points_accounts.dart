import 'chobo_records.dart';

class ChoboStandardPointsAccountDefinition {
  const ChoboStandardPointsAccountDefinition({
    required this.pointsAccountId,
    required this.name,
    required this.pointsCurrency,
    required this.exchangeRate,
  });

  final String pointsAccountId;
  final String name;
  final String pointsCurrency;
  final int exchangeRate;
}

class ChoboStandardPointsAccounts {
  ChoboStandardPointsAccounts._();

  static const List<ChoboStandardPointsAccountDefinition> definitions =
      <ChoboStandardPointsAccountDefinition>[
    ChoboStandardPointsAccountDefinition(
      pointsAccountId: 'points:tpoint',
      name: 'T-Point',
      pointsCurrency: 'T',
      exchangeRate: 1,
    ),
    ChoboStandardPointsAccountDefinition(
      pointsAccountId: 'points:rakuten',
      name: 'Rakuten Super Points',
      pointsCurrency: 'R',
      exchangeRate: 1,
    ),
    ChoboStandardPointsAccountDefinition(
      pointsAccountId: 'points:nanaco',
      name: 'nanaco',
      pointsCurrency: 'N',
      exchangeRate: 1,
    ),
    ChoboStandardPointsAccountDefinition(
      pointsAccountId: 'points:waon',
      name: 'WAON',
      pointsCurrency: 'W',
      exchangeRate: 1,
    ),
    ChoboStandardPointsAccountDefinition(
      pointsAccountId: 'points:transport',
      name: '交通系ポイント',
      pointsCurrency: 'P',
      exchangeRate: 1,
    ),
  ];
}

class ChoboPointsAccountSeed {
  const ChoboPointsAccountSeed(this.definition);

  final ChoboStandardPointsAccountDefinition definition;

  ChoboPointsAccountRecord toPointsAccountRecord(String timestamp) {
    return ChoboPointsAccountRecord(
      pointsAccountId: definition.pointsAccountId,
      name: definition.name,
      pointsCurrency: definition.pointsCurrency,
      exchangeRate: definition.exchangeRate,
      isDefault: true,
      isArchived: false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
