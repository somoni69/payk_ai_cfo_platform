import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../../core/routing/payk_back.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';

String moduleSectionLabelKey(String section) {
  if (section == 'meta') return 'more_meta';
  return 'perm_module_${section.replaceAll('-', '_')}';
}

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  var _loading = true;
  String? _error;
  ModuleCatalog _catalog = ModuleCatalog.fallback;
  List<ClientModule> _modules = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  NetworkRepository get _repo => context.read<NetworkRepository>();

  Future<void> _load() async {
    try {
      final catalog = await _repo.fetchModuleCatalog();
      final modules = await _repo.fetchModules();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _modules = modules;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error);
      });
    }
  }

  Future<void> _openEditor([ClientModule? existing]) async {
    final language = context.read<LanguageCubit>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ModuleEditor(
        catalog: _catalog,
        existing: existing,
        repo: _repo,
        language: language,
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(ClientModule module) async {
    final language = context.read<LanguageCubit>();
    if (module.stores.isNotEmpty) {
      final names = module.stores.map((store) => store.name).join(', ');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(language.translate('modules_in_use_title')),
          content: Text(
            language.translate(
              'modules_in_use_msg',
              params: {'name': module.name, 'stores': names},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(language.translate('modules_understood')),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language.translate(
            'modules_delete_title',
            params: {'name': module.name},
          ),
        ),
        content: Text(language.translate('modules_delete_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('common_delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteModule(module.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('modules_deleted'))),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.resolveMessage(userFacingError(error))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final auth = context.watch<AuthBloc>().state;
    final inStore = auth is AuthAuthenticated && auth.storeId != null;

    return PaykBackScope(
      nested: true,
      fallback: inStore ? '/more' : '/network',
      child: Scaffold(
        backgroundColor: colors.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : () => _openEditor(),
          icon: const Icon(TablerIcons.plus),
          label: Text(language.translate('modules_new')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.resolveMessage(_error!),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: Text(language.translate('common_retry')),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: _modules.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            language.translate('modules_empty'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            language.translate('modules_empty_hint'),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _modules.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Text(
                              language.translate('modules_description'),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            );
                          }
                          final module = _modules[index - 1];
                          final clients = module.stores.isEmpty
                              ? language.translate('modules_no_clients')
                              : module.stores
                                    .map((store) => store.name)
                                    .join(', ');
                          return Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openEditor(module),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            module.name,
                                            style: textStyles.bodySans.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (module.description != null &&
                                              module
                                                  .description!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              module.description!,
                                              style: textStyles.captionSans
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            language.translate(
                                              'modules_sections_count',
                                              params: {
                                                'n':
                                                    '${module.sections.length}',
                                              },
                                            ),
                                            style: textStyles.captionSans,
                                          ),
                                          Text(
                                            clients,
                                            style: textStyles.captionSans
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: language.translate(
                                        'common_delete',
                                      ),
                                      onPressed: () => _delete(module),
                                      icon: Icon(
                                        TablerIcons.trash,
                                        color: colors.accentRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _ModuleEditor extends StatefulWidget {
  const _ModuleEditor({
    required this.catalog,
    required this.existing,
    required this.repo,
    required this.language,
  });

  final ModuleCatalog catalog;
  final ClientModule? existing;
  final NetworkRepository repo;
  final LanguageCubit language;

  @override
  State<_ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends State<_ModuleEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Set<String> _selected;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _selected = {...?widget.existing?.sections};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String _label(String section) {
    return widget.language.translate(moduleSectionLabelKey(section));
  }

  void _toggle(String section, bool on) {
    final language = widget.language;
    setState(() {
      if (on) {
        _selected.add(section);
        final needed = widget.catalog.requires[section];
        if (needed != null && _selected.add(needed)) {
          _toast(
            language.translate(
              'modules_requires_on',
              params: {'a': _label(section), 'b': _label(needed)},
            ),
          );
        }
      } else {
        _selected.remove(section);
        final dropped = widget.catalog.requires.entries
            .where(
              (entry) => entry.value == section && _selected.remove(entry.key),
            )
            .map((entry) => entry.key)
            .toList();
        if (dropped.isNotEmpty) {
          _toast(
            language.translate(
              'modules_requires_off',
              params: {'a': _label(dropped.first), 'b': _label(section)},
            ),
          );
        }
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final language = widget.language;
    final name = _name.text.trim();
    if (name.length < 2) {
      _toast(language.translate('modules_err_name'));
      return;
    }
    if (_selected.isEmpty) {
      _toast(language.translate('modules_err_sections'));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveModule(
        id: widget.existing?.id,
        name: name,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        sections: [
          for (final section in widget.catalog.sections)
            if (_selected.contains(section)) section,
        ],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(language.resolveMessage(userFacingError(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = widget.language;
    final existing = widget.existing;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            language.translate(
              existing == null ? 'modules_new' : 'modules_edit',
            ),
            style: textStyles.h2Sans.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: language.translate('modules_name'),
                    hintText: language.translate('modules_name_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  decoration: InputDecoration(
                    labelText: language.translate('modules_description_field'),
                    hintText: language.translate('modules_description_hint'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('modules_sections'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  language.translate('modules_sections_hint'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (existing != null && existing.stores.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    language.translate(
                      'modules_used_by',
                      params: {
                        'stores': existing.stores
                            .map((store) => store.name)
                            .join(', '),
                      },
                    ),
                    style: textStyles.captionSans.copyWith(color: colors.brand),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => _selected.addAll(widget.catalog.sections),
                      ),
                      child: Text(language.translate('modules_select_all')),
                    ),
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: Text(language.translate('modules_clear_all')),
                    ),
                  ],
                ),
                Text(
                  language.translate(
                    'modules_selected_count',
                    params: {
                      'n': '${_selected.length}',
                      'total': '${widget.catalog.sections.length}',
                    },
                  ),
                  style: textStyles.captionSans,
                ),
                for (final section in widget.catalog.sections)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _selected.contains(section),
                    title: Text(_label(section)),
                    onChanged: (value) => _toggle(section, value ?? false),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(
              language.translate(
                existing == null ? 'common_create' : 'common_save',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
