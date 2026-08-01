import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../bloc/crm_bloc.dart';
import '../bloc/crm_event.dart';
import '../bloc/crm_state.dart';
import '../domain/crm_models.dart';
import 'crm_labels.dart';

Future<void> showCrmClientForm(
  BuildContext context, {
  CrmClient? existing,
}) {
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      );
    },
  );
}

Future<void> showCrmDealForm(
  BuildContext context, {
  required List<CrmClient> clients,
  CrmDeal? existing,
}) {
  final language = context.read<LanguageCubit>();
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null
        ? localizedDecimalFormat(context).format(existing.amount)
        : '',
  );
  String clientId = existing?.clientId ??
      (clients.isNotEmpty ? clients.first.id : '');
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing == null) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('crm-deal-client-$clientId'),
              initialValue: clientId.isEmpty ? null : clientId,
              items: clients
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.fullName, style: textStyles.bodySans),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setSheet(() {
                  clientId = v;
                  dirty = true;
                });
              },
              decoration: InputDecoration(
                labelText: lang.translate('crm_client_label'),
              ),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => dirty = true,
            decoration: InputDecoration(
              labelText: lang.translate('crm_deal_amount'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('crm-deal-stage-$stage'),
            initialValue: stage,
            items: stages
                .map(
                  (s) => DropdownMenuItem(
                    value: s.value,
                    child: Text(s.label, style: textStyles.bodySans),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setSheet(() {
                stage = v;
                dirty = true;
              });
            },
            decoration: InputDecoration(
              labelText: lang.translate('crm_funnel_stage'),
            ),
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
                ctx.read<CrmBloc>().add(
                      CreateDealRequested(
                        clientId: clientId,
                        title: title,
                        amount: amount,
                        stage: stage,
                        expectedClose: expected,
                      ),
                    );
              } else {
                ctx.read<CrmBloc>().add(
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
        ],
      );
    },
  );
}

Future<void> showCrmPurchaseSheet(BuildContext context, CrmClient client) {
  final language = context.read<LanguageCubit>();
  final amountCtrl = TextEditingController();
  var dirty = false;
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_register_purchase'),
    isDirty: () => dirty,
    builder: (ctx, _) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(client.fullName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            style: textStyles.bodyMono,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => dirty = true,
            decoration: InputDecoration(
              labelText: lang.translate('crm_purchase_amount'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amount = parseLocalizedNumber(ctx, amountCtrl.text);
              if (amount == null || amount <= 0) return;
              ctx.read<CrmBloc>().add(
                    RegisterPurchaseRequested(
                      clientId: client.id,
                      amount: amount,
                    ),
                  );
              Navigator.of(ctx).pop();
            },
            child: Text(lang.translate('crm_confirm')),
          ),
        ],
      );
    },
  );
}

Future<void> showCrmBonusSheet(BuildContext context, CrmClient client) {
  final language = context.read<LanguageCubit>();
  final pointsCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  var dirty = false;
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_add_bonus'),
    isDirty: () => dirty,
    builder: (ctx, _) {
      final textStyles = ctx.textStyles;
      final lang = ctx.read<LanguageCubit>();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(client.fullName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
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
              ctx.read<CrmBloc>().add(
                    AddLoyaltyPointsRequested(
                      clientId: client.id,
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
      );
    },
  );
}

Future<void> showCrmSmsSheet(BuildContext context, CrmClient client) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(client.fullName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
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
              ctx.read<CrmBloc>().add(
                    SendReactivationRequested(
                      clientId: client.id,
                      text: text,
                    ),
                  );
              Navigator.of(ctx).pop();
            },
            child: Text(lang.translate('crm_send_sms')),
          ),
        ],
      );
    },
  );
}

Future<void> showCrmClientDetail(BuildContext context, CrmClient client) {
  context.read<CrmBloc>().add(LoadClientDetailRequested(client.id));
  final language = context.read<LanguageCubit>();
  return LedgerBottomSheet.show(
    context: context,
    title: language.translate('crm_client_detail'),
    builder: (ctx, _) {
      final colors = ctx.colors;
      final textStyles = ctx.textStyles;
      final lang = ctx.watch<LanguageCubit>();
      final oCcy = localizedDecimalFormat(ctx);
      final canManage = true; // gated by parent FAB / callers

      return BlocBuilder<CrmBloc, CrmState>(
        builder: (context, state) {
          if (state is! CrmLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = state.detailClient ?? client;
          final loyalty = crmLoyaltyColors(colors, detail.loyaltyLevel);

          if (state.detailLoading && state.detailClient == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.fullName,
                      style: textStyles.h2Sans,
                    ),
                  ),
                  LedgerPill(
                    text: crmLoyaltyLabel(lang, detail.loyaltyLevel),
                    backgroundColor: loyalty.bg,
                    textColor: loyalty.fg,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (detail.phone != null)
                Text(detail.phone!, style: textStyles.captionSans),
              if (detail.email != null)
                Text(detail.email!, style: textStyles.captionSans),
              const SizedBox(height: 12),
              LedgerCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _kv(ctx, 'LTV', '${oCcy.format(detail.totalSpent)} TJS'),
                    _kv(ctx, 'CAC', '${oCcy.format(detail.acquisitionCost)} TJS'),
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
              if (canManage) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showCrmClientForm(context, existing: detail);
                      },
                      icon: const Icon(TablerIcons.edit, size: 18),
                      label: Text(lang.translate('crm_edit_client')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showCrmPurchaseSheet(context, detail),
                      icon: const Icon(TablerIcons.shopping_cart, size: 18),
                      label: Text(lang.translate('crm_register_purchase')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showCrmBonusSheet(context, detail),
                      icon: const Icon(TablerIcons.gift, size: 18),
                      label: Text(lang.translate('crm_add_bonus')),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            title: Text(lang.translate('crm_delete_client')),
                            content: Text(
                              lang.translate(
                                'crm_delete_confirm',
                                params: {'name': detail.fullName},
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: Text(lang.translate('crm_cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: Text(lang.translate('crm_confirm')),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          context
                              .read<CrmBloc>()
                              .add(DeleteClientRequested(detail.id));
                          Navigator.of(ctx).pop();
                        }
                      },
                      child: Text(
                        lang.translate('crm_delete_client'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                lang.translate('crm_client_deals'),
                style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
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
                    child: LedgerCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${oCcy.format(d.amount)} TJS',
                                  style: textStyles.smallMono,
                                ),
                              ],
                            ),
                          ),
                          LedgerPill(
                            text: crmStagePill(lang, d.stage),
                            backgroundColor: sc.bg,
                            textColor: sc.fg,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Text(
                lang.translate('crm_client_loyalty_history'),
                style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
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
            ],
          );
        },
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
        Text(value, style: textStyles.smallMono.copyWith(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
