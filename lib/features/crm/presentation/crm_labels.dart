import 'package:flutter/material.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/crm_models.dart';

String crmLoyaltyLabel(LanguageCubit language, String level) {
  final key = switch (level) {
    'gold' => 'crm_loyalty_gold',
    'silver' => 'crm_loyalty_silver',
    'platinum' => 'crm_loyalty_platinum',
    'bronze' => 'crm_loyalty_bronze',
    _ => null,
  };
  return key != null ? language.translate(key) : level.toUpperCase();
}

String crmStageLabel(LanguageCubit language, String stage) {
  return switch (stage) {
    'lead' => language.translate('crm_stage_lead_label'),
    'contact' => language.translate('crm_stage_contact'),
    'proposal' => language.translate('crm_stage_proposal'),
    'negotiation' => language.translate('crm_stage_negotiation_label'),
    'won' => language.translate('crm_stage_won_label'),
    'lost' => language.translate('crm_stage_lost_label'),
    _ => stage.toUpperCase(),
  };
}

String crmStagePill(LanguageCubit language, String stage) {
  return switch (stage) {
    'lead' => language.translate('crm_stage_lead'),
    'contact' => language.translate('crm_stage_contact_pill'),
    'proposal' => language.translate('crm_stage_proposal_status'),
    'negotiation' => language.translate('crm_stage_negotiation'),
    'won' => language.translate('crm_stage_won'),
    'lost' => language.translate('crm_stage_lost'),
    _ => stage.toUpperCase(),
  };
}

({Color bg, Color fg}) crmLoyaltyColors(LedgerColors colors, String level) {
  return switch (level) {
    'gold' => (
      bg: colors.accentAmber.withValues(alpha: 0.1),
      fg: colors.accentAmber,
    ),
    'silver' => (bg: colors.brand.withValues(alpha: 0.08), fg: colors.brand),
    'platinum' => (
      bg: colors.accentGreen.withValues(alpha: 0.1),
      fg: colors.accentGreen,
    ),
    _ => (bg: colors.border, fg: colors.textPrimary),
  };
}

({Color bg, Color fg}) crmStageColors(LedgerColors colors, String stage) {
  return switch (stage) {
    'won' => (
      bg: colors.accentGreen.withValues(alpha: 0.1),
      fg: colors.accentGreen,
    ),
    'lost' => (
      bg: colors.accentRed.withValues(alpha: 0.1),
      fg: colors.accentRed,
    ),
    'negotiation' => (
      bg: colors.accentAmber.withValues(alpha: 0.1),
      fg: colors.accentAmber,
    ),
    'proposal' => (bg: colors.brand.withValues(alpha: 0.08), fg: colors.brand),
    _ => (bg: colors.border, fg: colors.textPrimary),
  };
}

List<({String value, String label})> crmStageOptions(LanguageCubit language) {
  return kDealStages
      .map((s) => (value: s, label: crmStageLabel(language, s)))
      .toList();
}

List<({String value, String label})> crmLoyaltyOptions(LanguageCubit language) {
  return [
    (value: '', label: language.translate('crm_filter_all_levels')),
    ...kLoyaltyLevels.map(
      (l) => (value: l, label: crmLoyaltyLabel(language, l)),
    ),
  ];
}
