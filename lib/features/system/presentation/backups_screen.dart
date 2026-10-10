import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../cubit/backups_cubit.dart';
import '../domain/system_repository.dart';

class BackupsScreen extends StatelessWidget {
  const BackupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<BackupsCubit>();
      return const _BackupsView();
    } catch (_) {
      return BlocProvider<BackupsCubit>(
        create: (ctx) =>
            BackupsCubit(ctx.read<SystemRepository>())..loadBackups(),
        child: const _BackupsView(),
      );
    }
  }
}

class _BackupsView extends StatelessWidget {
  const _BackupsView();

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _create(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final fileName = await context.read<BackupsCubit>().createBackup();
    if (fileName != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            language.translate(
              'backups_created',
              params: {'file': fileName.isEmpty ? 'ok' : fileName},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return BlocConsumer<BackupsCubit, BackupsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language.resolveMessage(state.error!)),
              backgroundColor: colors.accentRed,
            ),
          );
        }
      },
      builder: (context, state) {
        final files = state.files;
        final creating = state.isCreating;
        final loading = state.isLoading && files.isEmpty;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              language.translate('more_backups'),
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
          floatingActionButton: LedgerFab(
            heroTag: null,
            onPressed: creating ? null : () => _create(context),
            icon: TablerIcons.plus,
            iconWidget: creating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onBrand,
                    ),
                  )
                : null,
            label: language.translate('backups_create'),
          ),
          body: loading
              ? const BackupsOverviewShimmer()
              : RefreshIndicator(
                  onRefresh: () => context.read<BackupsCubit>().loadBackups(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(
                        language.translate('backups_hint'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (files.isEmpty)
                        LedgerCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    TablerIcons.database_off,
                                    size: 40,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    language.translate('backups_empty'),
                                    style: textStyles.bodySans.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...files.map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LedgerCard(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: colors.brand.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    TablerIcons.database,
                                    color: colors.brand,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  file.name,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _sizeLabel(file.size),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
