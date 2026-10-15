import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'meta_funnel_view.dart';

/// Chat analytics: leads, conversion, sources, managers, reply speed.
class MetaAnalyticsView extends StatefulWidget {
  const MetaAnalyticsView({super.key});

  @override
  State<MetaAnalyticsView> createState() => _MetaAnalyticsViewState();
}

class _MetaAnalyticsViewState extends State<MetaAnalyticsView> {
  static const _presets = <(String, String)>[
    ('thisMonth', 'meta_analytics_this_month'),
    ('lastMonth', 'meta_analytics_last_month'),
    ('week', 'meta_analytics_week'),
    ('days30', 'meta_analytics_days30'),
    ('thisYear', 'meta_analytics_this_year'),
    ('lastYear', 'meta_analytics_last_year'),
    ('year', 'meta_analytics_year'),
  ];
  static const _channels = ['', 'instagram', 'whatsapp', 'facebook'];

  String _preset = 'thisMonth';
  String _channel = '';
  var _loading = true;
  String? _error;
  MetaAnalytics? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime since, DateTime until}) _range() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (_preset) {
      'thisYear' => (since: DateTime(now.year), until: DateTime(now.year + 1)),
      'lastYear' => (since: DateTime(now.year - 1), until: DateTime(now.year)),
      'year' => (
        since: DateTime(now.year - 1, now.month, now.day),
        until: tomorrow,
      ),
      'lastMonth' => (
        since: DateTime(now.year, now.month - 1),
        until: DateTime(now.year, now.month),
      ),
      'days30' => (
        since: DateTime(now.year, now.month, now.day - 30),
        until: tomorrow,
      ),
      'week' => (
        since: DateTime(now.year, now.month, now.day - 7),
        until: tomorrow,
      ),
      _ => (
        since: DateTime(now.year, now.month),
        until: DateTime(now.year, now.month + 1),
      ),
    };
  }

  Future<void> _load() async {
    final range = _range();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<MetaRepository>().getAnalytics(
        since: range.since,
        until: range.until,
        channel: _channel.isEmpty ? null : _channel,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      setState(() {
        _error = text.contains(ErrorKeys.forbidden)
            ? 'meta_analytics_managers_only'
            : _caughtKey(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final data = _data;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final preset in _presets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoiceChip(
                    label: language.translate(preset.$2),
                    selected: _preset == preset.$1,
                    onTap: () {
                      setState(() => _preset = preset.$1);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final channel in _channels)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoiceChip(
                    label: language.translate(
                      channel.isEmpty
                          ? 'meta_channel_all'
                          : 'meta_channel_$channel',
                    ),
                    selected: _channel == channel,
                    onTap: () {
                      setState(() => _channel = channel);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      language.translate(_error!),
                      textAlign: TextAlign.center,
                      style: textStyles.bodySans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
              : data == null
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _kpiGrid(context, language, data.totals),
                      const SizedBox(height: 12),
                      _section(
                        context,
                        language.translate('meta_analytics_reply'),
                        _reply(context, language, data.totals),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        context,
                        language.translate('meta_analytics_sources'),
                        data.sources.isEmpty
                            ? _muted(
                                context,
                                language.translate('meta_analytics_empty'),
                              )
                            : Column(
                                children: [
                                  for (final source in data.sources)
                                    _line(
                                      context,
                                      language.translate(
                                        'meta_channel_${source.channel}',
                                      ),
                                      '${source.leads} · ${_pct(source.leads == 0 ? 0 : source.won / source.leads)}',
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        context,
                        language.translate('meta_analytics_stages'),
                        data.stages.isEmpty
                            ? _muted(
                                context,
                                language.translate('meta_analytics_empty'),
                              )
                            : Column(
                                children: [
                                  for (final stage in data.stages)
                                    _line(
                                      context,
                                      stage.name,
                                      '${stage.count}',
                                      dot: metaStageColor(
                                        stage.color,
                                        colors.brand,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        context,
                        language.translate('meta_analytics_managers'),
                        data.managers.isEmpty
                            ? _muted(
                                context,
                                language.translate(
                                  'meta_analytics_no_managers',
                                ),
                              )
                            : Column(
                                children: [
                                  for (final manager in data.managers)
                                    _line(
                                      context,
                                      manager.name,
                                      '${manager.leads} · ${formatLocalizedNumber(context, manager.revenue, maximumFractionDigits: 0)}',
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        context,
                        language.translate('meta_analytics_tasks'),
                        Row(
                          children: [
                            _taskStat(
                              context,
                              language.translate('meta_analytics_tasks_open'),
                              data.tasks.open,
                              colors.brand,
                            ),
                            _taskStat(
                              context,
                              language.translate('meta_analytics_tasks_done'),
                              data.tasks.done,
                              colors.accentGreen,
                            ),
                            _taskStat(
                              context,
                              language.translate(
                                'meta_analytics_tasks_overdue',
                              ),
                              data.tasks.overdue,
                              colors.accentRed,
                            ),
                          ],
                        ),
                      ),
                      if (data.buckets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _section(
                          context,
                          language.translate(
                            data.granularity == 'day'
                                ? 'meta_analytics_daily'
                                : 'meta_analytics_monthly',
                          ),
                          Column(
                            children: [
                              for (final bucket in data.buckets)
                                _line(
                                  context,
                                  _bucketLabel(bucket.key),
                                  '${bucket.leads} · ${_pct(bucket.conversion)}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _kpiGrid(
    BuildContext context,
    LanguageCubit language,
    AnalyticsTotals totals,
  ) {
    final cards = [
      ('meta_analytics_leads', '${totals.leads}', totals.leadsChange),
      (
        'meta_analytics_conversion',
        _pct(totals.conversion),
        totals.conversionChange,
      ),
      ('meta_analytics_won', '${totals.won}', totals.wonChange),
      (
        'meta_analytics_revenue',
        formatLocalizedNumber(
          context,
          totals.revenue,
          maximumFractionDigits: 0,
        ),
        totals.revenueChange,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        for (final card in cards)
          _kpi(context, language, card.$1, card.$2, card.$3),
      ],
    );
  }

  Widget _kpi(
    BuildContext context,
    LanguageCubit language,
    String labelKey,
    String value,
    double? change,
  ) {
    final colors = context.colors;
    final deltaColor = change == null || change == 0
        ? colors.textSecondary
        : change > 0
        ? colors.accentGreen
        : colors.accentRed;
    final delta = change == null
        ? language.translate('meta_analytics_no_prev')
        : '${change > 0 ? '+' : ''}${(change * 100).round()}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language.translate(labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.h2Sans.copyWith(fontSize: 20),
            ),
            Text(
              delta,
              style: context.textStyles.smallSans.copyWith(color: deltaColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reply(
    BuildContext context,
    LanguageCubit language,
    AnalyticsTotals totals,
  ) {
    final seconds = totals.avgFirstReplySec;
    if (seconds == null) {
      return _muted(context, language.translate('meta_analytics_reply_none'));
    }
    final grade = totals.replyGrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _duration(language, seconds.round()),
          style: context.textStyles.h2Sans.copyWith(fontSize: 22),
        ),
        if (grade != null && grade.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            language.translate('meta_analytics_grade_$grade'),
            style: context.textStyles.captionSans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${language.translate('meta_analytics_replied_share')}: ${_pct(totals.repliedShare)}',
          style: context.textStyles.captionSans.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, {Color? dot}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.bodySans,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: context.textStyles.captionSans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskStat(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: context.textStyles.h2Sans.copyWith(
              fontSize: 20,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.textStyles.smallSans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muted(BuildContext context, String text) {
    return Text(
      text,
      style: context.textStyles.captionSans.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }

  String _pct(double value) {
    final percent = value * 100;
    final digits = percent == percent.roundToDouble() ? 0 : 1;
    return '${percent.toStringAsFixed(digits)}%';
  }

  String _duration(LanguageCubit language, int seconds) {
    if (seconds < 60) {
      return '$seconds ${language.translate('meta_analytics_seconds')}';
    }
    if (seconds < 3600) {
      return '${(seconds / 60).round()} ${language.translate('meta_analytics_minutes')}';
    }
    final hours = seconds / 3600;
    final text = hours >= 10
        ? hours.round().toString()
        : hours.toStringAsFixed(1);
    return '$text ${language.translate('meta_analytics_hours')}';
  }

  String _bucketLabel(String key) {
    final parts = key.split('-');
    if (parts.length == 2 && parts[1].length == 2) {
      return '${parts[1]}.${parts[0]}';
    }
    if (parts.length == 3) return '${parts[2]}.${parts[1]}';
    return key;
  }
}

String _caughtKey(Object error) {
  final text = error.toString();
  final key = text.startsWith('Exception: ') ? text.substring(11) : text;
  if (key.startsWith('error_') || key.startsWith('meta_')) return key;
  return ErrorKeys.loadFailed;
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.brand.withValues(alpha: 0.12) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? colors.brand : colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              label,
              style: context.textStyles.captionSans.copyWith(
                color: selected ? colors.brand : colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
