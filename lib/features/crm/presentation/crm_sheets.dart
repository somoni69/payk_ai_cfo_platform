import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../bloc/crm_bloc.dart';
import '../bloc/crm_event.dart';
import '../bloc/crm_state.dart';
import '../domain/crm_models.dart';
import 'crm_labels.dart';

Future<void> showCrmClientForm(BuildContext context, {CrmClient? existing}) {
  final crmBloc = context.read<CrmBloc>();
  final language = context.read<LanguageCubit>();
  final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final cacCtrl = TextEditingController(
    text: existing != null
        ? localizedDecimalFormat(context).format(existing.acquisitionCost)
        : '',
  );
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  DateTime? birthDate = existing?.birthDate;
  var dirty = false;

  return LedgerBottomSheet.show(
    context: context,
    title: language.translate(
      existing == null ? 'crm_new_client' : 'crm_edit_client',
    ),
    isDirty: () => dirty,
    builder: (ctx, setSheet) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return BlocProvider.value(
        value: crmBloc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              style: textStyles.bodySans,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_full_name_company'),
                prefixIcon: const Icon(TablerIcons.user, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: textStyles.bodySans,
              keyboardType: TextInputType.phone,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_phone'),
                prefixIcon: const Icon(TablerIcons.phone, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: textStyles.bodySans,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_email'),
                prefixIcon: const Icon(TablerIcons.mail, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cacCtrl,
              style: textStyles.bodyMono,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_acquisition_cost'),
                prefixIcon: const Icon(TablerIcons.coin, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: birthDate ?? DateTime.now(),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setSheet(() {
                    birthDate = picked;
                    dirty = true;
                  });
                }
              },
              icon: const Icon(TablerIcons.cake, size: 18),
              label: Text(
                birthDate == null
                    ? lang.translate('crm_birth_date')
                    : formatLocalizedDateTime(
                        ctx,
                        birthDate!,
                        style: LocalizedDateTimeStyle.date,
                      ),
                style: textStyles.bodySans,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: textStyles.bodySans,
              maxLines: 2,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_note'),
                prefixIcon: const Icon(TablerIcons.note, size: 20),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final cac = parseLocalizedNumber(ctx, cacCtrl.text) ?? 0;
                final client = CrmClient(
                  id: existing?.id ?? '',
                  fullName: name,
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  birthDate: birthDate,
                  loyaltyLevel: existing?.loyaltyLevel ?? 'bronze',
                  bonusPoints: existing?.bonusPoints ?? 0,
                  totalSpent: existing?.totalSpent ?? 0,
                  acquisitionCost: cac,
                  purchasesCount: existing?.purchasesCount ?? 0,
                  lastPurchaseAt: existing?.lastPurchaseAt,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  roi: existing?.roi,
                  churnRisk: existing?.churnRisk ?? false,
                );
                if (existing == null) {
                  ctx.read<CrmBloc>().add(CreateClientRequested(client));
                } else {
                  ctx.read<CrmBloc>().add(
                    UpdateClientRequested(
                      id: existing.id,
                      fullName: client.fullName,
                      phone: client.phone,
                      email: client.email,
                      birthDate: client.birthDate,
                      acquisitionCost: client.acquisitionCost,
                      note: client.note,
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: Text(lang.translate('crm_save')),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCrmDealForm(
  BuildContext context, {
  required List<CrmClient> clients,
  CrmDeal? existing,
}) {
  final crmBloc = context.read<CrmBloc>();
  final language = context.read<LanguageCubit>();
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null
        ? localizedDecimalFormat(context).format(existing.amount)
        : '',
  );
  String clientId =
      existing?.clientId ?? (clients.isNotEmpty ? clients.first.id : '');
  String stage = existing?.stage ?? 'lead';
  DateTime? expected = existing?.expectedClose;
  var dirty = false;

  return LedgerBottomSheet.show(
    context: context,
    title: language.translate(
      existing == null ? 'crm_new_deal' : 'crm_edit_deal',
    ),
    isDirty: () => dirty,
    builder: (ctx, setSheet) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      final stages = crmStageOptions(lang);
      return BlocProvider.value(
        value: crmBloc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (existing == null) ...[
              Text(
                lang.translate('crm_client_label'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<CrmClient>.selection(
                key: ValueKey('crm-deal-client-$clientId'),
                title: Text(
                  clients
                          .where((c) => c.id == clientId)
                          .map((c) => c.fullName)
                          .firstOrNull ??
                      lang.translate('crm_client_label'),
                  style: textStyles.bodySans.copyWith(
                    color: clientId.isEmpty
                        ? ctx.colors.textTooltip
                        : ctx.colors.textPrimary,
                  ),
                ),
                items: clients,
                selectedValue: clients
                    .where((c) => c.id == clientId)
                    .firstOrNull,
                itemLabelBuilder: (c) => c.fullName,
                onSelected: (c) {
                  setSheet(() {
                    clientId = c.id;
                    dirty = true;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: titleCtrl,
              style: textStyles.bodySans,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_deal_title'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              style: textStyles.bodyMono,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_deal_amount'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang.translate('crm_funnel_stage'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            ExpansibleWidget<({String value, String label})>.selection(
              key: ValueKey('crm-deal-stage-$stage'),
              title: Text(
                stages
                        .where((s) => s.value == stage)
                        .map((s) => s.label)
                        .firstOrNull ??
                    stage,
                style: textStyles.bodySans,
              ),
              items: stages,
              selectedValue:
                  stages.where((s) => s.value == stage).firstOrNull ??
                  stages.first,
              itemLabelBuilder: (s) => s.label,
              onSelected: (s) {
                setSheet(() {
                  stage = s.value;
                  dirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: expected ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (picked != null) {
                  setSheet(() {
                    expected = picked;
                    dirty = true;
                  });
                }
              },
              icon: const Icon(TablerIcons.calendar, size: 18),
              label: Text(
                expected == null
                    ? lang.translate('crm_expected_close')
                    : formatLocalizedDateTime(
                        ctx,
                        expected!,
                        style: LocalizedDateTimeStyle.date,
                      ),
                style: textStyles.bodySans,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                if (existing == null && clientId.isEmpty) return;
                final amount = parseLocalizedNumber(ctx, amountCtrl.text) ?? 0;
                if (existing == null) {
                  crmBloc.add(
                    CreateDealRequested(
                      clientId: clientId,
                      title: title,
                      amount: amount,
                      stage: stage,
                      expectedClose: expected,
                    ),
                  );
                } else {
                  crmBloc.add(
                    UpdateDealRequested(
                      id: existing.id,
                      title: title,
                      amount: amount,
                      stage: stage,
                      expectedClose: expected,
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: Text(lang.translate('crm_save')),
            ),
            if (existing != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    crmBloc.add(DeleteDealRequested(existing.id));
                    Navigator.of(ctx).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.colors.accentRed,
                    side: BorderSide(
                      color: ctx.colors.accentRed.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(TablerIcons.trash, size: 18),
                  label: Text(lang.translate('crm_delete_deal')),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> showCrmPurchaseSheet(BuildContext context, CrmClient client) {
  final crmBloc = context.read<CrmBloc>();
  final language = context.read<LanguageCubit>();
  final amountCtrl = TextEditingController();
  DateTime? occurredAt;
  var dirty = false;
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_register_purchase'),
    isDirty: () => dirty,
    builder: (ctx, setSheet) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return BlocProvider.value(
        value: crmBloc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              client.fullName,
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              style: textStyles.bodyMono,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_purchase_amount'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: occurredAt ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setSheet(() {
                    occurredAt = picked;
                    dirty = true;
                  });
                }
              },
              icon: const Icon(TablerIcons.calendar, size: 18),
              label: Text(
                occurredAt == null
                    ? lang.translate('crm_purchase_date_optional')
                    : formatLocalizedDateTime(
                        ctx,
                        occurredAt!,
                        style: LocalizedDateTimeStyle.date,
                      ),
                style: textStyles.bodySans,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final amount = parseLocalizedNumber(ctx, amountCtrl.text);
                if (amount == null || amount <= 0) return;
                crmBloc.add(
                  RegisterPurchaseRequested(
                    clientId: client.id,
                    amount: amount,
                    occurredAt: occurredAt,
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(lang.translate('crm_confirm')),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCrmBonusSheet(
  BuildContext context, {
  CrmClient? client,
  List<CrmClient> clients = const [],
}) {
  final crmBloc = context.read<CrmBloc>();
  final language = context.read<LanguageCubit>();
  final pointsCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  final pool = clients.isNotEmpty
      ? clients
      : (client != null ? [client] : const <CrmClient>[]);
  String clientId = client?.id ?? (pool.isNotEmpty ? pool.first.id : '');
  var dirty = false;
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_add_bonus'),
    isDirty: () => dirty,
    builder: (ctx, setSheet) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return BlocProvider.value(
        value: crmBloc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pool.length > 1) ...[
              Text(
                lang.translate('crm_client_label'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<CrmClient>.selection(
                key: ValueKey('crm-bonus-client-$clientId'),
                title: Text(
                  pool
                          .where((c) => c.id == clientId)
                          .map((c) => c.fullName)
                          .firstOrNull ??
                      lang.translate('crm_client_label'),
                  style: textStyles.bodySans,
                ),
                items: pool,
                selectedValue: pool.where((c) => c.id == clientId).firstOrNull,
                itemLabelBuilder: (c) => c.fullName,
                onSelected: (c) {
                  setSheet(() {
                    clientId = c.id;
                    dirty = true;
                  });
                },
              ),
            ] else if (pool.isNotEmpty)
              Text(
                pool.first.fullName,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              style: textStyles.bodyMono,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_bonus_amount'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: textStyles.bodySans,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_bonus_reason'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final points = parseLocalizedNumber(ctx, pointsCtrl.text);
                if (points == null || points == 0) return;
                if (clientId.isEmpty) return;
                crmBloc.add(
                  AddLoyaltyPointsRequested(
                    clientId: clientId,
                    points: points,
                    reason: reasonCtrl.text.trim().isEmpty
                        ? null
                        : reasonCtrl.text.trim(),
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(lang.translate('crm_save')),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCrmSmsSheet(BuildContext context, CrmClient client) {
  final crmBloc = context.read<CrmBloc>();
  final language = context.read<LanguageCubit>();
  final textCtrl = TextEditingController(
    text: language.translate('crm_sms_default'),
  );
  var dirty = false;
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_send_sms'),
    isDirty: () => dirty,
    builder: (ctx, _) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return BlocProvider.value(
        value: crmBloc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              client.fullName,
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            if (client.phone != null)
              Text(
                client.phone!,
                style: textStyles.captionSans.copyWith(
                  color: ctx.colors.textSecondary,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              style: textStyles.bodySans,
              maxLines: 4,
              onChanged: (_) => dirty = true,
              decoration: InputDecoration(
                labelText: lang.translate('crm_sms_text'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final text = textCtrl.text.trim();
                if (text.isEmpty) return;
                crmBloc.add(
                  SendReactivationRequested(clientId: client.id, text: text),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(lang.translate('crm_send_sms')),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showCrmClientDetail(BuildContext context, CrmClient client) {
  final crmBloc = context.read<CrmBloc>();
  crmBloc.add(LoadClientDetailRequested(client.id));
  final language = context.read<LanguageCubit>();

  var isEditing = false;
  var dirty = false;
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final cacCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime? birthDate;

  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_client_detail'),
    isDirty: () => isEditing && dirty,
    builder: (ctx, setSheet) {
      final colors = ctx.colors;
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      final oCcy = localizedDecimalFormat(ctx);
      final auth = ctx.read<AuthBloc>().state;
      final canWrite =
          auth is AuthAuthenticated && auth.role.canWrite(AppCapability.crm);
      final canDelete =
          auth is AuthAuthenticated && auth.role.canDelete(AppCapability.crm);

      return BlocProvider.value(
        value: crmBloc,
        child: BlocBuilder<CrmBloc, CrmState>(
          builder: (context, state) {
            if (state is! CrmLoaded ||
                (state.detailLoading && state.detailClient == null)) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LedgerNamedListShimmer(itemCount: 4),
              );
            }
            final detail = state.detailClient ?? client;
            final loyalty = crmLoyaltyColors(colors, detail.loyaltyLevel);

            if (isEditing) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: textStyles.bodySans,
                    onChanged: (_) => dirty = true,
                    decoration: InputDecoration(
                      labelText: lang.translate('crm_full_name_company'),
                      prefixIcon: const Icon(TablerIcons.user, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: textStyles.bodySans,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => dirty = true,
                    decoration: InputDecoration(
                      labelText: lang.translate('crm_phone'),
                      prefixIcon: const Icon(TablerIcons.phone, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    style: textStyles.bodySans,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => dirty = true,
                    decoration: InputDecoration(
                      labelText: lang.translate('crm_email'),
                      prefixIcon: const Icon(TablerIcons.mail, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cacCtrl,
                    style: textStyles.bodyMono,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => dirty = true,
                    decoration: InputDecoration(
                      labelText: lang.translate('crm_acquisition_cost'),
                      prefixIcon: const Icon(TablerIcons.coin, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: birthDate ?? DateTime.now(),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheet(() {
                          birthDate = picked;
                          dirty = true;
                        });
                      }
                    },
                    icon: const Icon(TablerIcons.cake, size: 18),
                    label: Text(
                      birthDate == null
                          ? lang.translate('crm_birth_date')
                          : formatLocalizedDateTime(
                              ctx,
                              birthDate!,
                              style: LocalizedDateTimeStyle.date,
                            ),
                      style: textStyles.bodySans,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    style: textStyles.bodySans,
                    maxLines: 2,
                    onChanged: (_) => dirty = true,
                    decoration: InputDecoration(
                      labelText: lang.translate('crm_note'),
                      prefixIcon: const Icon(TablerIcons.note, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final cac = parseLocalizedNumber(ctx, cacCtrl.text) ?? 0;
                      crmBloc.add(
                        UpdateClientRequested(
                          id: detail.id,
                          fullName: name,
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim().isEmpty
                              ? null
                              : emailCtrl.text.trim(),
                          birthDate: birthDate,
                          acquisitionCost: cac,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        ),
                      );
                      setSheet(() {
                        isEditing = false;
                        dirty = false;
                      });
                    },
                    child: Text(lang.translate('crm_save')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      setSheet(() {
                        isEditing = false;
                        dirty = false;
                      });
                    },
                    child: Text(lang.translate('crm_cancel')),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(detail.fullName, style: textStyles.h2Sans),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: loyalty.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        crmLoyaltyLabel(lang, detail.loyaltyLevel),
                        style: textStyles.captionSans.copyWith(
                          color: loyalty.fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (detail.phone != null)
                  Text(detail.phone!, style: textStyles.captionSans),
                if (detail.email != null)
                  Text(detail.email!, style: textStyles.captionSans),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      _kv(ctx, 'LTV', '${oCcy.format(detail.totalSpent)} TJS'),
                      _kv(
                        ctx,
                        'CAC',
                        '${oCcy.format(detail.acquisitionCost)} TJS',
                      ),
                      _kv(
                        ctx,
                        'ROI',
                        detail.roi == null ? '—' : oCcy.format(detail.roi!),
                      ),
                      _kv(
                        ctx,
                        lang.translate('crm_bonus_points'),
                        oCcy.format(detail.bonusPoints),
                      ),
                      _kv(
                        ctx,
                        lang.translate('crm_last_purchase'),
                        detail.lastPurchaseAt == null
                            ? '—'
                            : formatLocalizedDateTime(
                                ctx,
                                detail.lastPurchaseAt!,
                                style: LocalizedDateTimeStyle.date,
                              ),
                      ),
                      if (detail.birthDate != null)
                        _kv(
                          ctx,
                          lang.translate('crm_birth_date'),
                          formatLocalizedDateTime(
                            ctx,
                            detail.birthDate!,
                            style: LocalizedDateTimeStyle.date,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (canWrite) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setSheet(() {
                              nameCtrl.text = detail.fullName;
                              phoneCtrl.text = detail.phone ?? '';
                              emailCtrl.text = detail.email ?? '';
                              cacCtrl.text = oCcy.format(
                                detail.acquisitionCost,
                              );
                              birthDate = detail.birthDate;
                              noteCtrl.text = detail.note ?? '';
                              isEditing = true;
                              dirty = false;
                            });
                          },
                          icon: const Icon(TablerIcons.edit, size: 18),
                          label: Text(
                            lang.translate('crm_edit_client'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showCrmPurchaseSheet(context, detail),
                          icon: const Icon(TablerIcons.shopping_cart, size: 18),
                          label: Text(
                            lang.translate('crm_register_purchase'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showCrmBonusSheet(context, client: detail),
                      icon: const Icon(TablerIcons.gift, size: 18),
                      label: Text(lang.translate('crm_add_bonus')),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  lang.translate('crm_client_deals'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (state.detailDeals.isEmpty)
                  Text(
                    lang.translate('crm_no_history'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textTooltip,
                    ),
                  )
                else
                  ...state.detailDeals.map((d) {
                    final sc = crmStageColors(colors, d.stage);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.title,
                                    style: textStyles.bodySans.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${oCcy.format(d.amount)} TJS',
                                    style: textStyles.bodyMono.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.brand,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: sc.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                crmStagePill(lang, d.stage),
                                style: textStyles.captionSans.copyWith(
                                  color: sc.fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Text(
                  lang.translate('crm_client_loyalty_history'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (state.detailLoyalty.isEmpty)
                  Text(
                    lang.translate('crm_no_history'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textTooltip,
                    ),
                  )
                else
                  ...state.detailLoyalty.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.reason?.isNotEmpty == true
                                  ? t.reason!
                                  : formatLocalizedDateTime(
                                      ctx,
                                      t.createdAt,
                                      style: LocalizedDateTimeStyle.date,
                                    ),
                              style: textStyles.captionSans,
                            ),
                          ),
                          Text(
                            oCcy.format(t.points),
                            style: textStyles.smallMono.copyWith(
                              color: t.points >= 0
                                  ? colors.accentGreen
                                  : colors.accentRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canDelete) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        crmBloc.add(DeleteClientRequested(detail.id));
                        Navigator.of(ctx).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accentRed,
                        side: BorderSide(
                          color: colors.accentRed.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(TablerIcons.trash, size: 18),
                      label: Text(lang.translate('crm_delete_client')),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    if (context.mounted) {
      context.read<CrmBloc>().add(const ClearClientDetail());
    }
  });
}

Widget _kv(BuildContext context, String label, String value) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ),
        Text(
          value,
          style: textStyles.smallMono.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
