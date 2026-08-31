import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../domain/system_repository.dart';

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  List<BackupFile> _files = const [];
  var _loading = true;
  var _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await context.read<SystemRepository>().listBackups();
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    final language = context.read<LanguageCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    try {
      final name = await context.read<SystemRepository>().createBackup();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            language.translate(
              'backups_created',
              params: {'file': name.isEmpty ? 'ok' : name},
            ),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translateMessage(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _creating ? null : _create,
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(TablerIcons.plus),
        label: Text(
          language.translate('backups_create'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(language.translateMessage(_error!)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text(language.translate('common_retry')),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _files.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            language.translate('backups_empty'),
                            style: textStyles.bodySans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                      itemCount: _files.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return LedgerCard(
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.database,
                                color: colors.brand,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: textStyles.bodySans.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                _sizeLabel(file.size),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
