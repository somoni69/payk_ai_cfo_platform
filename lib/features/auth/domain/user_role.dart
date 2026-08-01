/// Роли пользователей в системе PAYK (SYS-02 – SYS-07).
///
/// Domain-level enum: no dependency on BLoC or presentation layers.
enum UserRole {
  /// Директор: видит все, управляет всем (SYS-02).
  director,

  /// Менеджер: видит всё, кроме системных настроек (SYS-03).
  manager,

  /// Бухгалтер: доступ к кассе и финансам (SYS-04).
  accountant,

  /// Кассир: операции своей смены (SYS-05).
  cashier,

  /// HR: кадры и задачи (SYS-06).
  hr,

  /// Только просмотр (SYS-07).
  viewer;

  /// Localization key for [LanguageCubit.translate], e.g. `role_director`.
  String get labelKey => switch (this) {
    UserRole.director => 'role_director',
    UserRole.manager => 'role_manager',
    UserRole.accountant => 'role_accountant',
    UserRole.cashier => 'role_cashier',
    UserRole.hr => 'role_hr',
    UserRole.viewer => 'role_viewer',
  };

  /// Russian fallback label (for logs / non-UI contexts only).
  String get labelRu => switch (this) {
    UserRole.director => 'Директор',
    UserRole.manager => 'Менеджер',
    UserRole.accountant => 'Бухгалтер',
    UserRole.cashier => 'Кассир',
    UserRole.hr => 'HR-специалист',
    UserRole.viewer => 'Наблюдатель',
  };

  /// Deprecated: prefer [labelKey] + translate in UI.
  String get label => labelRu;
}
