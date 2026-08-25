import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/integrations/bloc/integrations_bloc.dart';
import '../../../features/integrations/bloc/integrations_event.dart';
import '../../../features/integrations/bloc/integrations_state.dart';
import '../../../features/integrations/domain/integrations_repository.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<IntegrationsBloc>(
      create: (context) =>
          IntegrationsBloc(context.read<IntegrationsRepository>())
            ..add(LoadIntegrationsData()),
      child: const IntegrationsView(),
    );
  }
}

class IntegrationsView extends StatefulWidget {
  const IntegrationsView({super.key});

  @override
  State<IntegrationsView> createState() => _IntegrationsViewState();
}

class _IntegrationsViewState extends State<IntegrationsView> {
  static const _logPageSize = 50;

  final ScrollController _scrollController = ScrollController();
  int _visibleLogs = _logPageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_revealMoreLogs);
  }

  void _revealMoreLogs() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    final total = context.read<IntegrationsBloc>().state.logs.length;
    if (_visibleLogs >= total) return;
    final next = _visibleLogs + _logPageSize;
    setState(() => _visibleLogs = next < total ? next : total);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_revealMoreLogs)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          localeCubit.translate('integrations_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: BlocListener<IntegrationsBloc, IntegrationsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localeCubit.translateMessage(state.errorMessage!),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state.syncMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localeCubit.translateMessage(state.syncMessage!)),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
          buildWhen: (previous, current) =>
              previous.integrations != current.integrations ||
              previous.logs != current.logs ||
              previous.isLoading != current.isLoading ||
              previous.isSyncing != current.isSyncing,
          builder: (context, state) {
            if (state.isLoading &&
                state.integrations.isEmpty &&
                state.logs.isEmpty) {
              return const IntegrationsOverviewShimmer();
            }

            final visibleLogCount = _visibleLogs < state.logs.length
                ? _visibleLogs
                : state.logs.length;
            final logsHeaderIndex = state.integrations.length + 2;
            final logItemCount = state.logs.isEmpty ? 1 : visibleLogCount;

            return RefreshIndicator(
              onRefresh: context.read<IntegrationsBloc>().reload,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.integrations.length + logItemCount + 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        localeCubit.translate('integrations_connected_systems'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }

                  if (index <= state.integrations.length) {
                    final integration = state.integrations[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  integration.name,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: integration.available
                                            ? colors.accentGreen
                                            : colors.textSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      localeCubit.translate(
                                        integration.available
                                            ? 'integrations_status_active'
                                            : 'integrations_status_inactive',
                                      ),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (integration.canSync)
                              ElevatedButton.icon(
                                onPressed: state.isSyncing
                                    ? null
                                    : () {
                                        context.read<IntegrationsBloc>().add(
                                          TriggerSyncRequested(
                                            integration.system,
                                          ),
                                        );
                                      },
                                icon: const Icon(TablerIcons.refresh, size: 15),
                                label: Text(
                                  localeCubit.translate('integrations_sync'),
                                  style: textStyles.smallSans.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.brand,
                                  foregroundColor: colors.surface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Раздел "Диагностика и инструменты"
                  final toolsIndex = state.integrations.length + 1;
                  if (index == toolsIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localeCubit.translate('integrations_tools_title'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showSmsTestModal(context),
                                icon: const Icon(
                                  TablerIcons.message_2,
                                  size: 16,
                                ),
                                label: Text(
                                  localeCubit.translate(
                                    'integrations_sms_test_btn',
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.brand,
                                  side: BorderSide(color: colors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showAiTestModal(context),
                                icon: const Icon(
                                  TablerIcons.sparkles,
                                  size: 16,
                                ),
                                label: Text(
                                  localeCubit.translate(
                                    'integrations_ai_test_btn',
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.brand,
                                  side: BorderSide(color: colors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showTelegramLinkModal(context),
                                icon: const Icon(
                                  TablerIcons.brand_telegram,
                                  size: 16,
                                ),
                                label: Text(
                                  localeCubit.translate(
                                    'integrations_telegram_btn',
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.brand,
                                  side: BorderSide(color: colors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == logsHeaderIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        localeCubit.translate('integrations_sync_logs'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }

                  if (state.logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        localeCubit.translate('integrations_empty_logs'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  }

                  final logIndex = index - logsHeaderIndex - 1;
                  final log = state.logs[logIndex];
                  final isSuccess = log.success;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                log.system.toUpperCase(),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? colors.accentGreen.withValues(
                                          alpha: 0.12,
                                        )
                                      : colors.accentRed.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  localeCubit.translate(
                                    isSuccess
                                        ? 'integrations_success'
                                        : 'integrations_error',
                                  ),
                                  style: textStyles.captionSans.copyWith(
                                    color: isSuccess
                                        ? colors.accentGreen
                                        : colors.accentRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (log.message != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              localeCubit.translateMessage(log.message!),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                localeCubit.translatePlural(
                                  'integrations_records_imported',
                                  log.records,
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                formatLocalizedDateTime(
                                  context,
                                  log.createdAt,
                                  style: LocalizedDateTimeStyle.dayMonthTime,
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSmsTestModal(BuildContext context) {
    final bloc = context.read<IntegrationsBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final phoneController = TextEditingController(text: '992');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: bloc,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
              builder: (ctx, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.translate('integrations_sms_modal_title'),
                      style: textStyles.h2Sans.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: locale.translate(
                          'integrations_sms_phone_label',
                        ),
                        prefixIcon: const Icon(TablerIcons.phone, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (state.smsResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: state.smsResult!.ok
                              ? colors.accentGreen.withValues(alpha: 0.1)
                              : colors.accentRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: state.smsResult!.ok
                                ? colors.accentGreen.withValues(alpha: 0.3)
                                : colors.accentRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state.smsResult!.ok
                                  ? TablerIcons.check
                                  : TablerIcons.alert_circle,
                              color: state.smsResult!.ok
                                  ? colors.accentGreen
                                  : colors.accentRed,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.smsResult!.ok
                                    ? locale.translate(
                                        'integrations_sms_success',
                                      )
                                    : '${locale.translate('integrations_sms_failed')}: ${state.smsResult!.reason ?? ""}',
                                style: textStyles.captionSans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: state.smsResult!.ok
                                      ? colors.accentGreen
                                      : colors.accentRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.isTestingSms
                            ? null
                            : () {
                                final phone = phoneController.text.trim();
                                if (phone.isNotEmpty) {
                                  bloc.add(TestSmsRequested(phone));
                                }
                              },
                        icon: state.isTestingSms
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(TablerIcons.send, size: 16),
                        label: Text(
                          locale.translate('integrations_sms_send_btn'),
                          style: textStyles.bodySans.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAiTestModal(BuildContext context) {
    final bloc = context.read<IntegrationsBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    bloc.add(const TestAiRequested());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: bloc,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
              builder: (ctx, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.translate('integrations_ai_modal_title'),
                      style: textStyles.h2Sans.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.isTestingAi)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (state.aiResult != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: state.aiResult!.ok
                              ? colors.accentGreen.withValues(alpha: 0.1)
                              : colors.accentRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: state.aiResult!.ok
                                ? colors.accentGreen.withValues(alpha: 0.3)
                                : colors.accentRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  state.aiResult!.ok
                                      ? TablerIcons.circle_check
                                      : TablerIcons.alert_triangle,
                                  color: state.aiResult!.ok
                                      ? colors.accentGreen
                                      : colors.accentRed,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.aiResult!.ok
                                        ? locale.translate(
                                            'integrations_ai_status_ok',
                                          )
                                        : (state.aiResult!.error ?? "Ошибка"),
                                    style: textStyles.bodySans.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: state.aiResult!.ok
                                          ? colors.accentGreen
                                          : colors.accentRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (state.aiResult!.model != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${locale.translate('integrations_ai_model')}: ${state.aiResult!.model}',
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isTestingAi
                            ? null
                            : () => bloc.add(const TestAiRequested()),
                        icon: const Icon(TablerIcons.refresh, size: 16),
                        label: Text(
                          locale.translate('dashboard_retry'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.brand,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTelegramLinkModal(BuildContext context) {
    final bloc = context.read<IntegrationsBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    bloc.add(const LoadTelegramLinkRequested());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: bloc,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
              builder: (ctx, state) {
                final link = state.telegramLink;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          TablerIcons.brand_telegram,
                          color: colors.brand,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locale.translate('integrations_telegram_title'),
                            style: textStyles.h2Sans.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locale.translate('integrations_telegram_desc'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoadingTelegramLink)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (link != null) ...[
                      if (link.connected)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.circle_check,
                                color: colors.accentGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  locale.translate(
                                    'integrations_telegram_connected',
                                  ),
                                  style: textStyles.bodySans.copyWith(
                                    color: colors.accentGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  '/start ${link.token}',
                                  style: textStyles.bodyMono.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: '/start ${link.token}'),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        locale.translate(
                                          'integrations_telegram_copy_token',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(TablerIcons.copy, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
