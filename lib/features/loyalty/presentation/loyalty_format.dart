import '../../../core/localization/language_cubit.dart';

String loyaltyStatusLabel(LanguageCubit language, int status) =>
    language.translate('loyalty_status_$status');

String loyaltyFormatLabel(LanguageCubit language, String code) => language
    .translate(code == 'CL' ? 'loyalty_format_cl' : 'loyalty_format_sm');

String loyaltyModeLabel(LanguageCubit language, String? mode) {
  return language.translate(switch (mode) {
    'earn_burn' => 'loyalty_mode_earn_burn',
    'burn' => 'loyalty_mode_burn',
    _ => 'loyalty_mode_earn',
  });
}

String loyaltyWholesaleLabel(LanguageCubit language, String? flag) {
  return language.translate(switch (flag) {
    'pending' => 'loyalty_wholesale_pending',
    'confirmed' => 'loyalty_wholesale_confirmed',
    'dismissed' => 'loyalty_wholesale_dismissed',
    _ => 'loyalty_wholesale_none',
  });
}
