import 'package:equatable/equatable.dart';

/// Type-safe UI feedback model replacing fragile pipe-delimited string parsing.
sealed class UiFeedback extends Equatable {
  const UiFeedback();

  String get translationKey => switch (this) {
    LocalizedFeedback(:final translationKey) => translationKey,
    ShiftClosedFeedback() => 'cash_shift_closed_diff',
    WarehouseActionFeedback(:final translationKey) => translationKey,
  };
}

/// Generic localized feedback message with key, parameters, and severity.
final class LocalizedFeedback extends UiFeedback {
  @override
  final String translationKey;
  final Map<String, String> params;
  final bool isError;

  const LocalizedFeedback(
    this.translationKey, {
    this.params = const {},
    this.isError = false,
  });

  @override
  List<Object?> get props => [translationKey, params, isError];
}

/// Feedback emitted when a cash shift is closed with financial reconciliation diff.
final class ShiftClosedFeedback extends UiFeedback {
  final double diff;
  final double expectedBalance;

  const ShiftClosedFeedback({
    required this.diff,
    required this.expectedBalance,
  });

  String get diffFormatted =>
      '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)}';

  String get expectedFormatted => expectedBalance.toStringAsFixed(2);

  @override
  List<Object?> get props => [diff, expectedBalance];
}

/// Feedback emitted when warehouse batch operations (e.g. barcodes generated or expiry checks) complete.
final class WarehouseActionFeedback extends UiFeedback {
  final String action;
  final int count;

  const WarehouseActionFeedback({required this.action, required this.count});

  @override
  String get translationKey => switch (action) {
    'expiry_check' => 'warehouse_expiry_check_created',
    'barcodes_generated' => 'warehouse_barcodes_generated',
    _ => action,
  };

  @override
  List<Object?> get props => [action, count];
}
