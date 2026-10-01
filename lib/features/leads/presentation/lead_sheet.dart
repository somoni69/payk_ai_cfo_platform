import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/ledger_layout.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../domain/lead_models.dart';
import '../domain/leads_repository.dart';

Future<bool?> showLeadSheet(
  BuildContext context, {
  required int leadId,
  required DemoBank bank,
}) {
  final repo = context.read<LeadsRepository>();
  final language = context.read<LanguageCubit>();
  return showLedgerModalSheet<bool>(
    context: context,
    builder: (sheetContext) =>
        _LeadSheet(repo: repo, language: language, leadId: leadId, bank: bank),
  );
}

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({
    required this.repo,
    required this.language,
    required this.leadId,
    required this.bank,
  });

  final LeadsRepository repo;
  final LanguageCubit language;
  final int leadId;
  final DemoBank bank;

  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet> {
  final _comment = TextEditingController();
  LeadDetail? _lead;
  var _status = LeadStatus.incoming;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lead = await widget.repo.getLead(widget.leadId);
      if (!mounted) return;
      _comment.text = lead.comment ?? '';
      setState(() {
        _lead = lead;
        _status = lead.status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorKey(error);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final lead = await widget.repo.updateLead(
        widget.leadId,
        status: _status.apiValue,
        comment: _comment.text,
      );
      if (!mounted) return;
      setState(() {
        _lead = lead;
        _status = lead.status;
        _saving = false;
      });
      _snack(widget.language.translate('leads_toast_saved'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(widget.language.resolveMessage(_errorKey(error)));
    }
  }

  Future<void> _delete() async {
    final lead = _lead;
    if (lead == null) return;
    final colors = context.colors;
    final language = widget.language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: LedgerButtons.modalOverlay(ctx),
        child: AlertDialog(
          title: Text(language.translate('leads_card_delete')),
          content: Text(
            language.translate(
              'leads_card_delete_confirm',
              params: {'name': lead.name},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(language.translate('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                language.translate('common_delete'),
                style: TextStyle(color: colors.accentRed),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repo.deleteLead(lead.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _snack(widget.language.resolveMessage(_errorKey(error)));
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final lead = _lead;
    return LedgerBottomSheet(
      title: language.translate('leads_card_title'),
      maxHeight: ledgerModalHeightOf(context),
      footer: lead == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    child: Text(language.translate('leads_card_delete')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(language.translate('leads_card_save')),
                  ),
                ),
              ],
            ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : lead == null
          ? Text(
              _error == null
                  ? language.translate('leads_toast_error')
                  : language.resolveMessage(_error!),
            )
          : _LeadBody(
              lead: lead,
              bank: widget.bank,
              language: language,
              status: _status,
              comment: _comment,
              onStatus: (value) => setState(() => _status = value),
              onCall: () => _call(lead.phone),
            ),
    );
  }
}

class _LeadBody extends StatelessWidget {
  const _LeadBody({
    required this.lead,
    required this.bank,
    required this.language,
    required this.status,
    required this.comment,
    required this.onStatus,
    required this.onCall,
  });

  final LeadDetail lead;
  final DemoBank bank;
  final LanguageCubit language;
  final LeadStatus status;
  final TextEditingController comment;
  final ValueChanged<LeadStatus> onStatus;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final lang = language.state.languageCode;
    final price = formatLeadPrice(lead.price);
    final software = [
      for (final key in lead.software) bank.labelOf(bank.software, key, lang),
      if (lead.softwareOther != null) lead.softwareOther!,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lead.name,
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(lead.phone, style: textStyles.bodySans),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onCall,
            child: Text(language.translate('leads_card_call')),
          ),
        ),
        if (!lead.notified)
          Text(
            language.translate('leads_no_telegram'),
            style: textStyles.captionSans.copyWith(color: colors.accentAmber),
          ),
        if (lead.repeats > 0)
          Text(
            language.translate(
              'leads_card_repeats',
              params: {'n': '${lead.repeats}'},
            ),
            style: textStyles.captionSans,
          ),
        const SizedBox(height: 8),
        _Line(
          language.translate('leads_card_company'),
          lead.company.isEmpty ? '—' : lead.company,
        ),
        _Line(
          language.translate('leads_card_role'),
          bank.labelOf(bank.roles, lead.role, lang),
        ),
        _Line(
          language.translate('leads_card_spheres'),
          lead.spheres.isEmpty
              ? '—'
              : [
                  for (final key in lead.spheres)
                    bank.labelOf(bank.spheres, key, lang),
                ].join(', '),
        ),
        _Line(
          language.translate('leads_card_years'),
          formatLeadYears(
            lead.years,
            lang,
            language.translate('leads_card_less_year'),
          ),
        ),
        _Line(
          language.translate('leads_card_points'),
          bank.labelOf(bank.points, lead.points, lang),
        ),
        _Line(
          language.translate('leads_card_network'),
          bank.labelOf(bank.network, lead.wantsNetwork, lang),
        ),
        _Line(
          language.translate('leads_card_software'),
          software.isEmpty ? '—' : software,
        ),
        _Line(
          language.translate('leads_card_lang'),
          lead.lang == 'tg'
              ? language.translate('leads_lang_tg')
              : language.translate('leads_lang_ru'),
        ),
        if (lead.ref != null)
          _Line(language.translate('leads_card_ref'), lead.ref!),
        _Line(
          language.translate('leads_card_created'),
          formatLeadDate(lead.createdAt),
        ),
        if (lead.lastSeenAt != null)
          _Line(
            language.translate('leads_card_last_seen'),
            formatLeadDate(lead.lastSeenAt!),
          ),
        _Line(
          language.translate('leads_card_price'),
          price == null
              ? language.translate('leads_card_no_price')
              : '$price ${language.translate('leads_per_month')}',
        ),
        _Line(
          language.translate('leads_card_overall'),
          lead.overallLevel == null ? '—' : '${lead.overallLevel}/100',
          valueColor: _levelColor(colors, lead.overallLevel),
        ),
        _Line(language.translate('leads_card_modules'), '${lead.modulesDone}'),
        const SizedBox(height: 12),
        Text(
          language.translate('leads_card_work'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in LeadStatus.valuesInOrder)
              ChoiceChip(
                label: Text(language.translate(item.labelKey)),
                selected: status == item,
                onSelected: (_) => onStatus(item),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: comment,
          maxLength: 4000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: language.translate('leads_card_comment'),
            hintText: language.translate('leads_card_comment_ph'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          language.translate('leads_card_answers'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final module in bank.modules)
          _ModuleBlock(
            module: module,
            entry: lead.answers[module.key],
            language: language,
            lang: lang,
          ),
      ],
    );
  }
}

class _ModuleBlock extends StatelessWidget {
  const _ModuleBlock({
    required this.module,
    required this.entry,
    required this.language,
    required this.lang,
  });

  final DemoModule module;
  final LeadModuleAnswers? entry;
  final LanguageCubit language;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    module.title.of(lang),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  entry == null
                      ? language.translate('leads_card_not_passed')
                      : '${entry!.level ?? '—'}/100',
                  style: textStyles.captionSans.copyWith(
                    color: entry == null
                        ? colors.textSecondary
                        : _levelColor(colors, entry!.level),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (entry != null)
            for (var i = 0; i < module.questions.length; i++)
              if (i < entry!.answers.length)
                _AnswerLine(
                  question: module.questions[i],
                  answer: entry!.answers[i],
                  language: language,
                  lang: lang,
                ),
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.question,
    required this.answer,
    required this.language,
    required this.lang,
  });

  final DemoQuestion question;
  final LeadAnswer answer;
  final LanguageCubit language;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final option = answer.option;
    final chosen =
        option != null && option >= 0 && option < question.options.length
        ? question.options[option].of(lang)
        : option == null
        ? null
        : '#${option + 1}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text.of(lang),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          if (chosen != null)
            Text(
              chosen,
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${language.translate('leads_card_own')}: ',
                    style: textStyles.captionSans.copyWith(color: colors.brand),
                  ),
                  TextSpan(text: '«${answer.text ?? ''}»'),
                  if (question.scored)
                    TextSpan(
                      text:
                          ' (${answer.ai == null ? language.translate('leads_card_ai_none') : language.translate('leads_card_ai', params: {'n': '${answer.ai}'})})',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelColor(LedgerColors colors, int? level) {
  if (level == null) return colors.textSecondary;
  if (level >= 75) return colors.accentGreen;
  if (level >= 45) return colors.accentAmber;
  return colors.accentRed;
}

String _errorKey(Object error) {
  final raw = error.toString();
  const prefix = 'Exception: ';
  return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
}
