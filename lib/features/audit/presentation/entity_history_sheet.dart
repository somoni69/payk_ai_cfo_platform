import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../domain/audit_models.dart';
import '../domain/audit_repository.dart';

Future<void> showEntityHistorySheet(
  BuildContext context, {
  required String entity,
  required String id,
}) async {
  final language = context.read<LanguageCubit>();
  var items = const <EntityHistoryItem>[];
  try {
    items = await context.read<AuditRepository>().getEntityHistory(entity, id);
  } catch (_) {}
  if (!context.mounted) return;
  await LedgerBottomSheet.show(
    context: context,
    title: language.translate('more_audit'),
    builder: (ctx, setState) {
      final colors = ctx.colors;
      final textStyles = ctx.textStyles;
      if (items.isEmpty) {
        return Text(language.translate('dashboard_breakdown_empty'));
      }
      return Column(
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.action, style: textStyles.bodySans),
              subtitle: Text(
                [
                  if (item.userName.isNotEmpty) item.userName,
                  formatLocalizedDateTime(ctx, item.createdAt),
                ].join(' · '),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
        ],
      );
    },
  );
}
