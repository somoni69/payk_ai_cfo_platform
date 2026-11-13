import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/showcase_models.dart';
import '../domain/showcase_repository.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  var _loading = true;
  String? _error;
  ShowcaseList? _list;

  ShowcaseRepository get _repo => context.read<ShowcaseRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _list == null;
      _error = null;
    });
    try {
      final list = await _repo.list();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.resolveMessage(error.toString()))),
      );
    }
  }

  Future<void> _edit([ShowcaseCard? card]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ShowcaseEditor(card: card),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(ShowcaseCard card) async {
    final language = context.read<LanguageCubit>();
    final title = card.title(language.state.languageCode);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('showcase_delete_title')),
        content: Text(
          language.translate('showcase_delete_text', params: {'title': title}),
        ),
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
    if (ok == true) await _run(() => _repo.delete(card.id));
  }

  Future<void> _move(int index, int delta) async {
    final cards = _list?.cards ?? const [];
    final target = index + delta;
    if (target < 0 || target >= cards.length) return;
    final ids = [for (final card in cards) card.id];
    final current = ids[index];
    ids[index] = ids[target];
    ids[target] = current;
    await _run(() => _repo.reorder(ids));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final list = _list;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(TablerIcons.plus),
        label: Text(language.translate('showcase_add')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              language.translate('showcase_description'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
            if (list != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Stat(
                    label: language.translate('showcase_live'),
                    value: '${list.totals.live}',
                  ),
                  _Stat(
                    label: language.translate('showcase_viewers'),
                    value: '${list.totals.viewers}',
                  ),
                  _Stat(
                    label: language.translate('showcase_leads'),
                    value: '${list.totals.leads}',
                  ),
                  _Stat(
                    label: language.translate('showcase_leads_today'),
                    value: '${list.totals.leadsToday}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        _run(() => _repo.setAllActive(active: true)),
                    child: Text(language.translate('showcase_all_on')),
                  ),
                  TextButton(
                    onPressed: () => _confirmAllOff(),
                    child: Text(language.translate('showcase_all_off')),
                  ),
                ],
              ),
            ],
            if (_loading && list == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && list == null)
              _Error(message: language.resolveMessage(_error!), onRetry: _load)
            else if (list == null || list.cards.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(language.translate('showcase_empty')),
                ),
              )
            else
              for (var i = 0; i < list.cards.length; i++)
                _CardTile(
                  card: list.cards[i],
                  languageCode: language.state.languageCode,
                  canUp: i > 0,
                  canDown: i < list.cards.length - 1,
                  onToggle: (active) => _run(
                    () => _repo.setActive(list.cards[i].id, active: active),
                  ),
                  onEdit: () => _edit(list.cards[i]),
                  onDelete: () => _delete(list.cards[i]),
                  onUp: () => _move(i, -1),
                  onDown: () => _move(i, 1),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAllOff() async {
    final language = context.read<LanguageCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('showcase_all_off')),
        content: Text(language.translate('showcase_all_off_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('showcase_all_off')),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.setAllActive(active: false));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.read<LanguageCubit>().translate('common_retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.languageCode,
    required this.canUp,
    required this.canDown,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onUp,
    required this.onDown,
  });

  final ShowcaseCard card;
  final String languageCode;
  final bool canUp;
  final bool canDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final stateKey = switch (card.state) {
      'live' => 'showcase_live',
      'scheduled' => 'showcase_scheduled',
      'ended' => 'showcase_ended',
      _ => 'showcase_off',
    };
    final image = card.imageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiClient().mediaUrl(image),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 56, height: 56),
                  ),
                )
              else
                Icon(TablerIcons.speakerphone, color: colors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title(languageCode),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.translate(stateKey),
                      style: textStyles.captionSans.copyWith(
                        color: card.state == 'live'
                            ? colors.accentGreen
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: card.isActive,
                activeTrackColor: colors.brand,
                onChanged: onToggle,
              ),
            ],
          ),
          if (card.text(languageCode).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              card.text(languageCode),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${language.translate('showcase_views')}: ${card.views} · ${language.translate('showcase_leads')}: ${card.leads}',
            style: textStyles.captionSans,
          ),
          Row(
            children: [
              IconButton(
                onPressed: canUp ? onUp : null,
                icon: const Icon(TablerIcons.arrow_up),
              ),
              IconButton(
                onPressed: canDown ? onDown : null,
                icon: const Icon(TablerIcons.arrow_down),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(TablerIcons.pencil),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(TablerIcons.trash, color: colors.accentRed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShowcaseEditor extends StatefulWidget {
  const _ShowcaseEditor({this.card});

  final ShowcaseCard? card;

  @override
  State<_ShowcaseEditor> createState() => _ShowcaseEditorState();
}

class _ShowcaseEditorState extends State<_ShowcaseEditor> {
  late final TextEditingController _titleRu;
  late final TextEditingController _titleTj;
  late final TextEditingController _textRu;
  late final TextEditingController _textTj;
  late String _art;
  late bool _active;
  String? _imagePath;
  String? _imageUrl;
  String? _starts;
  String? _ends;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _titleRu = TextEditingController(text: card?.titleRu ?? '');
    _titleTj = TextEditingController(text: card?.titleTj ?? '');
    _textRu = TextEditingController(text: card?.textRu ?? '');
    _textTj = TextEditingController(text: card?.textTj ?? '');
    _art = card?.art ?? 'sparkles';
    _active = card?.isActive ?? true;
    _imagePath = card?.imagePath;
    _imageUrl = card?.imageUrl;
    _starts = card?.startsOn;
    _ends = card?.endsOn;
  }

  @override
  void dispose() {
    _titleRu.dispose();
    _titleTj.dispose();
    _textRu.dispose();
    _textTj.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final current = DateTime.tryParse((start ? _starts : _ends) ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _starts = text;
      } else {
        _ends = text;
      }
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (!mounted || file == null || bytes == null) return;
    final repo = context.read<ShowcaseRepository>();
    setState(() => _saving = true);
    try {
      final image = await repo.uploadImage(bytes: bytes, filename: file.name);
      if (!mounted) return;
      setState(() {
        _imagePath = image.path;
        _imageUrl = image.url;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    final language = context.read<LanguageCubit>();
    if (_titleRu.text.trim().isEmpty || _titleTj.text.trim().isEmpty) {
      setState(() => _error = language.translate('showcase_title_required'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = {
      'title_tj': _titleTj.text.trim(),
      'title_ru': _titleRu.text.trim(),
      'text_tj': _textTj.text.trim(),
      'text_ru': _textRu.text.trim(),
      'image_path': _imagePath,
      'art': _art,
      'starts_on': _starts,
      'ends_on': _ends,
      'is_active': _active,
    };
    try {
      final repo = context.read<ShowcaseRepository>();
      final card = widget.card;
      if (card == null) {
        await repo.create(input);
      } else {
        await repo.update(card.id, input);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            language.translate(
              widget.card == null ? 'showcase_add' : 'showcase_edit',
            ),
            style: context.textStyles.h2Sans,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleRu,
            decoration: InputDecoration(
              labelText: language.translate('showcase_title_ru'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleTj,
            decoration: InputDecoration(
              labelText: language.translate('showcase_title_tj'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textRu,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: language.translate('showcase_text_ru'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textTj,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: language.translate('showcase_text_tj'),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: showcaseArts.contains(_art) ? _art : 'sparkles',
            decoration: InputDecoration(
              labelText: language.translate('showcase_art'),
            ),
            items: [
              for (final art in showcaseArts)
                DropdownMenuItem(value: art, child: Text(art)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _art = value);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(language.translate('showcase_starts')),
            subtitle: Text(_starts ?? '—'),
            trailing: const Icon(TablerIcons.calendar),
            onTap: () => _pickDate(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(language.translate('showcase_ends')),
            subtitle: Text(_ends ?? '—'),
            trailing: const Icon(TablerIcons.calendar),
            onTap: () => _pickDate(false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(language.translate('showcase_active')),
            value: _active,
            activeTrackColor: colors.brand,
            onChanged: (value) => setState(() => _active = value),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(TablerIcons.photo),
                label: Text(language.translate('showcase_image')),
              ),
              if (_imagePath != null)
                TextButton(
                  onPressed: () => setState(() {
                    _imagePath = null;
                    _imageUrl = null;
                  }),
                  child: Text(language.translate('showcase_image_clear')),
                ),
            ],
          ),
          if (_imageUrl != null && _imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(
                ApiClient().mediaUrl(_imageUrl),
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              language.resolveMessage(_error!),
              style: TextStyle(color: colors.accentRed),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(language.translate('common_save')),
          ),
        ],
      ),
    );
  }
}
