import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../playroom/domain/playroom_time.dart';
import '../domain/meta_models.dart';
import 'meta_attachments.dart';

/// Messages closer than this from the same side share one visual group.
const _groupGap = Duration(minutes: 5);

DateTime _wallDay(DateTime value) {
  final wall = dushanbeWall(value);
  return DateTime.utc(wall.year, wall.month, wall.day);
}

/// `HH:mm` on the store clock (Asia/Dushanbe), whatever the phone zone is.
String metaBubbleTime(DateTime value) => storeTime(value);

/// «Сегодня», «Вчера» or «10 октября» on the store calendar.
String metaDayLabel(DateTime value, DateTime now, LanguageCubit language) {
  final day = _wallDay(value);
  final today = _wallDay(now);
  final diff = today.difference(day).inDays;
  if (diff == 0) return language.translate('meta_day_today');
  if (diff == 1) return language.translate('meta_day_yesterday');
  final month = language.translate('meta_month_gen_${day.month}');
  final label = language.translate(
    'meta_day_month',
    params: {'day': '${day.day}', 'month': month},
  );
  return day.year == today.year ? label : '$label ${day.year}';
}

/// One row of the chat list: a day chip or a message with its group edges.
sealed class MetaChatEntry {
  const MetaChatEntry();
}

final class MetaDayEntry extends MetaChatEntry {
  const MetaDayEntry(this.at);
  final DateTime at;
}

final class MetaMessageEntry extends MetaChatEntry {
  const MetaMessageEntry(
    this.message, {
    required this.firstInGroup,
    required this.lastInGroup,
  });
  final MetaMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
}

bool _sameGroup(MetaMessage a, MetaMessage b) =>
    a.outgoing == b.outgoing &&
    _wallDay(a.createdAt) == _wallDay(b.createdAt) &&
    b.createdAt.difference(a.createdAt).abs() <= _groupGap;

/// Chronological entries (oldest first) with day chips between days.
List<MetaChatEntry> buildMetaChatEntries(List<MetaMessage> messages) {
  final entries = <MetaChatEntry>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final prev = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    if (prev == null || _wallDay(prev.createdAt) != _wallDay(m.createdAt)) {
      entries.add(MetaDayEntry(m.createdAt));
    }
    entries.add(
      MetaMessageEntry(
        m,
        firstInGroup: prev == null || !_sameGroup(prev, m),
        lastInGroup: next == null || !_sameGroup(m, next),
      ),
    );
  }
  return entries;
}

/// Chat history, newest at the bottom, with a «to latest» button.
class MetaMessageList extends StatefulWidget {
  const MetaMessageList({
    super.key,
    required this.messages,
    required this.peerReadAt,
    this.now,
  });

  final List<MetaMessage> messages;
  final DateTime? peerReadAt;

  /// Test clock for day labels.
  final DateTime Function()? now;

  @override
  State<MetaMessageList> createState() => _MetaMessageListState();
}

class _MetaMessageListState extends State<MetaMessageList> {
  final _scroll = ScrollController();
  var _showDown = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 320;
    if (show != _showDown) setState(() => _showDown = show);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final now = (widget.now ?? DateTime.now)();
    // Reversed list: the newest entry sits at offset 0, so a new message and
    // the keyboard opening keep the bottom in view without extra scrolling.
    final entries = buildMetaChatEntries(widget.messages).reversed.toList();
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: entries.length,
          itemBuilder: (context, index) => switch (entries[index]) {
            MetaDayEntry(:final at) => MetaDayChip(
              label: metaDayLabel(at, now, language),
            ),
            final MetaMessageEntry e => MetaBubble(
              key: ValueKey('meta-msg-${e.message.id}'),
              message: e.message,
              firstInGroup: e.firstInGroup,
              lastInGroup: e.lastInGroup,
              read: e.message.isReadBy(widget.peerReadAt),
            ),
          },
        ),
        if (_showDown)
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: colors.surface,
              shape: CircleBorder(side: BorderSide(color: colors.border)),
              child: IconButton(
                tooltip: language.translate('meta_scroll_latest'),
                onPressed: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                icon: Icon(TablerIcons.chevron_down, color: colors.brand),
              ),
            ),
          ),
      ],
    );
  }
}

class MetaDayChip extends StatelessWidget {
  const MetaDayChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: context.textStyles.smallSans.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// ✓ sent, ✓✓ read (brand colour). No word: the label is for screen readers.
class MetaReadTicks extends StatelessWidget {
  const MetaReadTicks({super.key, required this.read, this.color});

  final bool read;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.read<LanguageCubit>();
    return Semantics(
      label: language.translate(read ? 'meta_read' : 'meta_sent'),
      child: ExcludeSemantics(
        child: Icon(
          read ? TablerIcons.checks : TablerIcons.check,
          size: 15,
          color: read ? colors.brand : (color ?? colors.textTooltip),
        ),
      ),
    );
  }
}

class MetaBubble extends StatelessWidget {
  const MetaBubble({
    super.key,
    required this.message,
    required this.firstInGroup,
    required this.lastInGroup,
    required this.read,
  });

  final MetaMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final out = message.outgoing;
    // Solid fill: brand tint blended onto the surface, no transparency.
    final fill = out
        ? Color.alphaBlend(colors.brand.withValues(alpha: 0.10), colors.surface)
        : colors.surface;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !out && lastInGroup ? tail : r,
      bottomRight: out && lastInGroup ? tail : r,
    );
    final text = metaTextWithoutLabels(message.text, message.attachments);
    final timeStyle = textStyles.smallSans.copyWith(
      fontSize: 11.5,
      color: colors.textTooltip,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(metaBubbleTime(message.createdAt), style: timeStyle),
        if (out) ...[const SizedBox(width: 3), MetaReadTicks(read: read)],
      ],
    );
    // Room for the time at the end of the last text line (Telegram-style).
    final metaWidth = out ? 56.0 : 38.0;

    Widget body;
    if (message.attachments.isEmpty) {
      body = Stack(
        children: [
          Text.rich(
            TextSpan(
              text: text,
              children: [
                WidgetSpan(child: SizedBox(width: metaWidth, height: 12)),
              ],
            ),
            style: textStyles.captionSans.copyWith(color: colors.textPrimary),
          ),
          Positioned(right: 0, bottom: 0, child: meta),
        ],
      );
    } else {
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MetaAttachments(
            items: message.attachments,
            outgoing: out,
            text: message.text,
          ),
          if (text.isNotEmpty)
            Text(
              text,
              style: textStyles.captionSans.copyWith(color: colors.textPrimary),
            ),
          Align(alignment: Alignment.centerRight, child: meta),
        ],
      );
      // Compact cards hug their content; media keeps the full bubble width
      // because images and video have no intrinsic width before loading.
      const compact = {'location', 'link', 'file', 'audio'};
      body = message.attachments.every((a) => compact.contains(a.kind))
          ? IntrinsicWidth(child: column)
          : column;
    }

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: firstInGroup ? 8 : 2),
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: out ? null : Border.all(color: colors.border),
        ),
        child: body,
      ),
    );
  }
}

/// Rounded field that grows to five lines, «+» menu and a send button that
/// is active only when there is text.
class MetaComposer extends StatefulWidget {
  const MetaComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.canSendAddress,
    required this.onSend,
    required this.onAttach,
    required this.onSendAddress,
    required this.onSuggest,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool sending;
  final bool canSendAddress;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onSendAddress;
  final VoidCallback onSuggest;
  final ValueChanged<String> onChanged;

  @override
  State<MetaComposer> createState() => _MetaComposerState();
}

class _MetaComposerState extends State<MetaComposer> {
  late bool _hasText = widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(MetaComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _onText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _openMenu() {
    final language = context.read<LanguageCubit>();
    final onAttach = widget.onAttach;
    final onAddress = widget.onSendAddress;
    final canAddress = widget.canSendAddress;
    LedgerBottomSheet.show<void>(
      context: context,
      title: language.translate('meta_attach_menu'),
      builder: (sheetContext, _) {
        final colors = sheetContext.colors;
        Widget item(IconData icon, String key, VoidCallback action) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: colors.brand),
          title: Text(
            language.translate(key),
            style: sheetContext.textStyles.bodySans,
          ),
          onTap: () {
            Navigator.of(sheetContext).pop();
            action();
          },
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(TablerIcons.paperclip, 'meta_attach_send', onAttach),
            if (canAddress)
              item(TablerIcons.map_pin, 'meta_our_address', onAddress),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final sending = widget.sending;
    final canSend = _hasText && !sending;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        6,
        6,
        8,
        6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: language.translate('meta_attach_menu'),
            onPressed: sending ? null : _openMenu,
            icon: Icon(TablerIcons.plus, color: colors.brand),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: !sending,
              onChanged: widget.onChanged,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: textStyles.captionSans.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: language.translate('meta_reply_hint'),
                isDense: true,
                filled: true,
                fillColor: colors.surfaceNested,
                contentPadding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.brand),
                ),
                suffixIcon: IconButton(
                  tooltip: language.translate('meta_suggest'),
                  onPressed: sending ? null : widget.onSuggest,
                  icon: Icon(
                    TablerIcons.sparkles,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: canSend ? colors.brand : colors.surfaceNested,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: language.translate('meta_send'),
                onPressed: canSend ? widget.onSend : null,
                icon: sending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.brand,
                        ),
                      )
                    : Icon(
                        TablerIcons.send,
                        size: 20,
                        color: canSend ? colors.onBrand : colors.textTooltip,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header title: peer name and a muted line with the channel or «нет связи».
class MetaChatTitle extends StatelessWidget {
  const MetaChatTitle({
    super.key,
    required this.name,
    required this.channel,
    required this.offline,
    required this.channelMark,
  });

  final String name;
  final String channel;
  final bool offline;
  final Widget channelMark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final LedgerColors c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyles.bodySans.copyWith(
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: FittedBox(child: channelMark),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                offline
                    ? language.translate('meta_status_offline_short')
                    : language.translate('meta_channel_$channel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.smallSans.copyWith(
                  fontSize: 12,
                  color: offline ? c.accentAmber : c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
