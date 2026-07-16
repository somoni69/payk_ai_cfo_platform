import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/integrations/bloc/integrations_bloc.dart';
import '../../features/integrations/bloc/integrations_event.dart';
import '../../features/integrations/bloc/integrations_state.dart';
import '../../features/integrations/domain/integrations_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IntegrationsBloc>(
      create: (context) => IntegrationsBloc(context.read<IntegrationsRepository>())..add(LoadIntegrationsData()),
      child: const IntegrationsView(),
    );
  }
}

class IntegrationsView extends StatelessWidget {
  const IntegrationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Внешние интеграции (INT)',
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      body: BlocListener<IntegrationsBloc, IntegrationsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: colors.accentRed,
              ),
            );
          }
          if (state.syncMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.syncMessage!),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        child: BlocBuilder<IntegrationsBloc, IntegrationsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<IntegrationsBloc>().add(LoadIntegrationsData());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('ПОДКЛЮЧЕННЫЕ СИСТЕМЫ', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...state.integrations.map((integration) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: LedgerCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  integration.name,
                                  style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: integration.available ? colors.accentGreen : colors.textSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      integration.available ? 'Активна' : 'Неактивна',
                                      style: textStyles.captionSans.copyWith(color: colors.textSecondary),
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
                                        context.read<IntegrationsBloc>().add(TriggerSyncRequested(integration.system));
                                      },
                                icon: const Icon(TablerIcons.refresh, size: 16),
                                label: const Text('Синхр.', style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Text('ЛОГИ СИНХРОНИЗАЦИИ', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (state.logs.isEmpty)
                    const Center(child: Text('Логи синхронизации пусты.'))
                  else
                    ...state.logs.map((log) {
                      final isSuccess = log.success;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: LedgerCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log.system.toUpperCase(),
                                    style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  LedgerPill(
                                    text: isSuccess ? 'Успешно' : 'Ошибка',
                                    backgroundColor: isSuccess ? colors.accentGreen.withValues(alpha: 0.1) : colors.accentRed.withValues(alpha: 0.1),
                                    textColor: isSuccess ? colors.accentGreen : colors.accentRed,
                                  ),
                                ],
                              ),
                              if (log.message != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  log.message!,
                                  style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Импортировано: ${log.records} записей',
                                    style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                  ),
                                  Text(
                                    '${log.createdAt.day}.${log.createdAt.month} ${log.createdAt.hour}:${log.createdAt.minute}',
                                    style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
