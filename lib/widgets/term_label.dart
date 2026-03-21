import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/chobo_providers.dart';
import '../core/terminology_labels.dart';

class TermLabel extends ConsumerWidget {
  const TermLabel({
    super.key,
    required this.label,
    this.style,
    this.tooltipEnabled = true,
  });

  final String label;
  final TextStyle? style;
  final bool tooltipEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final tooltip = tooltipEnabled ? termService.getTooltip(label) : null;

    final text = Text(
      label,
      style: style,
    );

    if (tooltip == null) {
      return text;
    }

    return Tooltip(
      message: tooltip,
      child: text,
    );
  }
}

class TermTransactionLabel extends ConsumerWidget {
  const TermTransactionLabel({
    super.key,
    required this.transactionType,
    this.style,
    this.showTooltip = true,
  });

  final String transactionType;
  final TextStyle? style;
  final bool showTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final label = termService.getTransactionLabelForType(transactionType);
    final tooltip = showTooltip ? termService.getTooltip(label) : null;

    final text = Text(
      label,
      style: style,
    );

    if (tooltip == null) {
      return text;
    }

    return Tooltip(
      message: tooltip,
      child: text,
    );
  }
}

class TermDirectionLabel extends ConsumerWidget {
  const TermDirectionLabel({
    super.key,
    required this.direction,
    this.style,
    this.showTooltip = true,
  });

  final String direction;
  final TextStyle? style;
  final bool showTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final label = termService.getDirectionLabelForDirection(direction);
    final tooltip = showTooltip ? termService.getTooltip(label) : null;

    final text = Text(
      label,
      style: style,
    );

    if (tooltip == null) {
      return text;
    }

    return Tooltip(
      message: tooltip,
      child: text,
    );
  }
}

class TermEntryLabel extends ConsumerWidget {
  const TermEntryLabel({
    super.key,
    required this.index,
    this.style,
    this.showTooltip = true,
  });

  final int index;
  final TextStyle? style;
  final bool showTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final label = termService.getEntryLabelForIndex(index);
    final tooltip = showTooltip ? termService.getTooltip(label) : null;

    final text = Text(
      label,
      style: style,
    );

    if (tooltip == null) {
      return text;
    }

    return Tooltip(
      message: tooltip,
      child: text,
    );
  }
}

class TermStatusLabel extends ConsumerWidget {
  const TermStatusLabel({
    super.key,
    required this.status,
    this.style,
  });

  final String status;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final label = termService.getStatusLabelForStatus(status);

    return Text(
      label,
      style: style,
    );
  }
}

class TermAccountName extends ConsumerWidget {
  const TermAccountName({
    super.key,
    required this.englishName,
    this.style,
  });

  final String englishName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);
    final label = termService.getStandardAccountName(englishName);

    return Text(
      label,
      style: style,
    );
  }
}

class TermDropdown<T extends Enum> extends ConsumerWidget {
  const TermDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.itemBuilder,
    this.hint,
  });

  final T value;
  final ValueChanged<T?> onChanged;
  final Widget Function(T value, TerminologyService termService) itemBuilder;
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termService = ref.watch(terminologyServiceProvider);

    return DropdownButton<T>(
      value: value,
      hint: hint != null ? Text(hint!) : null,
      isExpanded: true,
      items: TransactionTerm.values.map((e) {
        return DropdownMenuItem<T>(
          value: e as T,
          child: itemBuilder(e as T, termService),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
