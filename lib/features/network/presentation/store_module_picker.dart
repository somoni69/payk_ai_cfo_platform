import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';

/// Выбор модулей клиента в окне магазина.
class StoreModulePicker extends StatefulWidget {
  const StoreModulePicker({
    super.key,
    required this.initialIds,
    required this.onChanged,
  });

  final List<int> initialIds;
  final ValueChanged<List<int>> onChanged;

  @override
  State<StoreModulePicker> createState() => _StoreModulePickerState();
}

class _StoreModulePickerState extends State<StoreModulePicker> {
  var _loading = true;
  String? _error;
  List<ClientModule> _modules = const [];
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialIds};
    _load();
  }

  Future<void> _load() async {
    try {
      final modules = await context.read<NetworkRepository>().fetchModules();
      if (!mounted) return;
      setState(() {
        _modules = modules;
        _loading = false;
      });
      widget.onChanged(_selected.toList());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final textStyles = context.textStyles;
    final colors = context.colors;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text(
        language.resolveMessage(_error!),
        style: textStyles.captionSans.copyWith(color: colors.accentRed),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language.translate('modules_pick'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          language.translate('modules_pick_required'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        if (_modules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              language.translate('modules_none_yet'),
              style: textStyles.captionSans.copyWith(color: colors.accentRed),
            ),
          )
        else
          for (final module in _modules)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected.contains(module.id),
              title: Text(module.name),
              subtitle: Text(
                language.translate(
                  'modules_sections_count',
                  params: {'n': '${module.sections.length}'},
                ),
              ),
              onChanged: (value) {
                setState(() {
                  if (value ?? false) {
                    _selected.add(module.id);
                  } else {
                    _selected.remove(module.id);
                  }
                });
                widget.onChanged(_selected.toList());
              },
            ),
      ],
    );
  }
}
