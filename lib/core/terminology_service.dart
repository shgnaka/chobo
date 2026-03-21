import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db/chobo_records.dart';
import '../data/repository/settings_repository.dart';
import '../app/chobo_providers.dart';
import 'terminology_labels.dart';

final terminologyModeProvider =
    StateNotifierProvider<TerminologyModeNotifier, String>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return TerminologyModeNotifier(settingsRepo);
});

class TerminologyModeNotifier extends StateNotifier<String> {
  final SettingsRepository _settingsRepo;

  TerminologyModeNotifier(this._settingsRepo)
      : super(ChoboAppSettings.defaultTerminologyMode) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final setting = await _settingsRepo.getSetting(
      ChoboAppSettings.terminologyMode,
    );
    if (setting != null) {
      state = setting.settingValue;
    }
  }

  Future<void> setMode(String mode) async {
    await _settingsRepo.setSetting(
      ChoboSettingRecord(
        settingKey: ChoboAppSettings.terminologyMode,
        settingValue: mode,
      ),
    );
    state = mode;
  }

  bool get isAdvancedMode => state == ChoboAppSettings.terminologyModeAdvanced;
}

final terminologyServiceProvider = Provider<TerminologyService>((ref) {
  final mode = ref.watch(terminologyModeProvider);
  return TerminologyService(mode);
});

class TerminologyService {
  final String _mode;

  TerminologyService(this._mode);

  String get mode => _mode;

  bool get isAdvanced => _mode == ChoboAppSettings.terminologyModeAdvanced;

  String _getLabel<T>(Map<T, Map<String, String>> map, T key) {
    final modeKey = isAdvanced
        ? ChoboAppSettings.terminologyModeAdvanced
        : ChoboAppSettings.terminologyModeBasic;
    return map[key]?[modeKey] ?? '';
  }

  String getTransactionLabel(TransactionTerm term) {
    return _getLabel(TerminologyLabels.transactions, term);
  }

  String getDirectionLabel(DirectionTerm term) {
    return _getLabel(TerminologyLabels.directions, term);
  }

  String getEntryLabel(EntryTerm term) {
    return _getLabel(TerminologyLabels.entries, term);
  }

  String getStatusLabel(StatusTerm term) {
    return _getLabel(TerminologyLabels.statuses, term);
  }

  String getSectionLabel(SectionTerm term) {
    return _getLabel(TerminologyLabels.sections, term);
  }

  String getActionLabel(ActionTerm term) {
    return _getLabel(TerminologyLabels.actions, term);
  }

  String getFieldLabel(FieldTerm term) {
    return _getLabel(TerminologyLabels.fields, term);
  }

  String getAccountKindLabel(AccountKindTerm term) {
    return _getLabel(TerminologyLabels.accountKinds, term);
  }

  String getStandardAccountName(String englishName) {
    final names = TerminologyLabels.standardAccountNames[englishName];
    if (names == null) return englishName;
    final modeKey = isAdvanced
        ? ChoboAppSettings.terminologyModeAdvanced
        : ChoboAppSettings.terminologyModeBasic;
    return names[modeKey] ?? englishName;
  }

  String? getTooltip(String key) {
    if (isAdvanced) return null;
    return TerminologyLabels.tooltips[key];
  }

  String getTransactionLabelForType(String type) {
    switch (type) {
      case 'income':
        return getTransactionLabel(TransactionTerm.income);
      case 'expense':
        return getTransactionLabel(TransactionTerm.expense);
      case 'transfer':
        return getTransactionLabel(TransactionTerm.transfer);
      case 'credit_expense':
        return getTransactionLabel(TransactionTerm.creditExpense);
      case 'liability_payment':
        return getTransactionLabel(TransactionTerm.liabilityPayment);
      default:
        return type;
    }
  }

  String getDirectionLabelForDirection(String direction) {
    switch (direction) {
      case 'increase':
        return getDirectionLabel(DirectionTerm.increase);
      case 'decrease':
        return getDirectionLabel(DirectionTerm.decrease);
      default:
        return direction;
    }
  }

  String getEntryLabelForIndex(int index) {
    return getEntryLabel(
      index == 0 ? EntryTerm.first : EntryTerm.second,
    );
  }

  String getStatusLabelForStatus(String status) {
    switch (status) {
      case 'posted':
        return getStatusLabel(StatusTerm.posted);
      case 'pending':
        return getStatusLabel(StatusTerm.pending);
      case 'void':
        return getStatusLabel(StatusTerm.voided);
      default:
        return status;
    }
  }

  String getPeriodStateLabel(String state) {
    switch (state) {
      case 'open':
        return getStatusLabel(StatusTerm.periodOpen);
      case 'closed':
        return getStatusLabel(StatusTerm.periodClosed);
      default:
        return state;
    }
  }
}
