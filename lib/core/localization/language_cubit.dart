import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';

/// Cubit для управления текущим языком локализации (RU / TJ) (SYS-08 / SYS-09).
class LanguageCubit extends Cubit<Locale> {
  static const supportedLanguageCodes = {'ru', 'tg'};
  static const _storageKey = 'interface_language';

  final FlutterSecureStorage? storage;
  int _selectionRevision = 0;
  Future<void> _persistenceQueue = Future<void>.value();

  LanguageCubit({this.storage, String? initialLanguageCode})
    : super(Locale(_initialLanguage(initialLanguageCode))) {
    ApiClient().cacheInterfaceLanguage(state.languageCode);
    if (initialLanguageCode == null ||
        !supportedLanguageCodes.contains(initialLanguageCode)) {
      _restoreLanguage();
    }
  }

  static String _initialLanguage(String? languageCode) {
    return supportedLanguageCodes.contains(languageCode) ? languageCode! : 'ru';
  }

  Future<void> setLanguage(String langCode) async {
    if (isClosed || !supportedLanguageCodes.contains(langCode)) {
      return;
    }

    _selectionRevision++;
    if (state.languageCode != langCode) {
      emit(Locale(langCode));
    }
    ApiClient().cacheInterfaceLanguage(langCode);

    final storage = this.storage;
    if (storage == null) return;

    final persistence = _persistenceQueue.then((_) async {
      try {
        await storage.write(key: _storageKey, value: langCode);
      } catch (_) {
        // The interface still switches if secure storage is unavailable.
      }
    });
    _persistenceQueue = persistence;
    await persistence;
  }

  Future<void> _restoreLanguage() async {
    final selectionRevision = _selectionRevision;
    String? savedLanguage;
    try {
      savedLanguage = await storage?.read(key: _storageKey);
    } catch (_) {
      return;
    }
    if (isClosed || _selectionRevision != selectionRevision) return;

    if (savedLanguage != null &&
        supportedLanguageCodes.contains(savedLanguage) &&
        state.languageCode != savedLanguage) {
      ApiClient().cacheInterfaceLanguage(savedLanguage);
      emit(Locale(savedLanguage));
    }
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'ru': {
      'app_title': 'PAYK CFO',
      'dashboard': 'Финансовая панель',
      'cash': 'Касса и операции',
      'tasks': 'Задачи и планирование',
      'info': 'Инфо и предупреждения',
      'more': 'Еще',
      'revenue': 'Выручка (июнь)',
      'expenses': 'Расходы (июнь)',
      'net_profit': 'Чистая прибыль',
      'break_even': 'Точка безубыт.',
      'forecast': 'Прогноз кассы',
      'cash_balance': 'Остаток в кассах',
      'search_placeholder': 'Поиск по получателю или категории...',
      'all': 'Все',
      'income': 'Приход',
      'expense': 'Расход',
      'open_shift': 'Открыть смену',
      'close_shift': 'Закрыть смену',
      'logout': 'Выйти из системы',
      'new_operation': 'Новая операция',
      'add': 'Добавить',
      'cancel': 'Отмена',
      'amount': 'Сумма операции',
      'recipient': 'Наименование / Контрагент',
      'category': 'Категория / Статья',
      'payment_method': 'СПОСОБ ОПЛАТЫ',
      'save_to_ledger': 'Записать',
      'biometrics': 'Вход по биометрии (Face ID / Touch ID)',
      'language': 'Язык интерфейса (RU/TJ)',
      'active_shift': 'Кассовая смена открыта',
      'closed_shift': 'Кассовая смена закрыта',
      'no_operations': 'Операции не найдены',
      'no_tasks': 'В этой колонке нет задач',
      'no_alerts': 'Нарушений и нерассмотренных AI-советов нет',
      'profile': 'Алишер Рахимов',
      'role': 'Роль',
      'warehouse': 'Складской учет',
      'warehouse_title': 'Складской учет',
      'warehouse_tab_products': 'Товары',
      'warehouse_tab_movements': 'Движения',
      'warehouse_stats_count': 'Кол-во товаров',
      'warehouse_stats_value': 'Остаток на складе',
      'warehouse_empty_products': 'Товары на складе отсутствуют',
      'warehouse_empty_movements': 'История движений пуста',
      'price': 'Цена',
      'hr_menu': 'Сотрудники и кадры',
      'hr_title': 'Кадры и KPI',
      'hr_select_month': 'Выберите месяц',
      'hr_period_month_year': '{month} {year}',
      'hr_month_jan_short': 'Янв',
      'hr_month_feb_short': 'Фев',
      'hr_month_mar_short': 'Мар',
      'hr_month_apr_short': 'Апр',
      'hr_month_may_short': 'Май',
      'hr_month_jun_short': 'Июн',
      'hr_month_jul_short': 'Июл',
      'hr_month_aug_short': 'Авг',
      'hr_month_sep_short': 'Сен',
      'hr_month_oct_short': 'Окт',
      'hr_month_nov_short': 'Ноя',
      'hr_month_dec_short': 'Дек',
      'hr_month_january': 'Январь',
      'hr_month_february': 'Февраль',
      'hr_month_march': 'Март',
      'hr_month_april': 'Апрель',
      'hr_month_may': 'Май',
      'hr_month_june': 'Июнь',
      'hr_month_july': 'Июль',
      'hr_month_august': 'Август',
      'hr_month_september': 'Сентябрь',
      'hr_month_october': 'Октябрь',
      'hr_month_november': 'Ноябрь',
      'hr_month_december': 'Декабрь',
      'hr_status_active': 'Работает',
      'hr_status_vacation': 'В отпуске',
      'hr_status_fired': 'Уволен',
      'hr_default_employee': 'Сотрудник',
      'hr_default_main_office': 'Основной офис',
      'hr_employee_details': '{position} • {department}',
      'hr_amount_tjs': '{amount} TJS',
      'hr_kpi_empty': 'Нарушений KPI за этот период нет.',
      'hr_percentage': '{value}%',
      'hr_kpi_metric_value': 'Показатель: {metric}',
      'hr_kpi_plan_fact': 'План: {plan} | Факт: {fact}',
      'hr_ai_analysis': 'AI-анализ: {comment}',
      'hr_salary_empty': 'Начислений заработной платы за этот период нет.',
      'hr_salary_base': 'Оклад: {amount}',
      'hr_salary_bonus': 'Бонус: +{amount}',
      'hr_salary_deductions': 'Удержания: -{amount}',
      'hr_kpi_formula': 'Формула KPI: {formula}',
      'hr_hire_title': 'Прием на работу',
      'hr_employee_full_name': 'ФИО сотрудника',
      'hr_position': 'Должность',
      'hr_salary_tjs': 'Оклад (TJS)',
      'hr_phone': 'Телефон',
      'hr_email': 'E-mail',
      'hr_salary_adjustment_title': 'Корректировка ЗП: {employee}',
      'hr_base_salary': 'Базовый оклад',
      'hr_deductions_penalties': 'Удержания / Штрафы',
      'hr_bonus_formula': 'Формула бонуса (KPI)',
      'hr_bonus_formula_hint': 'например: fact_value * 0.1',
      'hr_recalculate': 'Пересчитать',
      'hr_tab_staff': 'Сотрудники',
      'hr_tab_kpi': 'Контроль KPI',
      'hr_tab_salary': 'Ведомость ЗП',
      'status_active': 'Работает',
      'status_vacation': 'В отпуске',
      'status_fired': 'Уволен',
      'kpi_metric': 'Показатель',
      'kpi_plan': 'План',
      'kpi_fact': 'Факт',
      'crm_menu': 'Сделки и Лиды',
      'crm_title': 'Лиды и сделки (CRM)',
      'crm_tab_clients': 'Клиенты',
      'crm_tab_deals': 'Сделки',
      'crm_tab_stats': 'Статистика',
      'crm_no_clients': 'Список клиентов пуст',
      'crm_no_deals': 'Активных сделок нет',
      'crm_client': 'Контрагент',
      'crm_churn_risk': 'РИСК ОТТОКА',
      'crm_stat_total_clients': 'Всего контрагентов',
      'crm_stat_active_clients': 'Активных клиентов',
      'crm_stat_total_ltv': 'Совокупный LTV',
      'crm_stat_total_cac': 'Совокупный CAC',
      'strat_menu': 'Аналитика What-if и AI-Маркетинг',
      'strat_title': 'Стратегия и AI-Маркетинг',
      'strat_tab_whatif': 'What-if Анализ',
      'strat_tab_marketing': 'ИИ-Маркетолог',
      'strat_whatif_desc':
          'Задайте финансовый вопрос ИИ о влиянии внешних/внутренних изменений на баланс компании.',
      'strat_whatif_hint': 'Что если продажи упадут на 10%?',
      'strat_marketing_desc':
          'Генерация идей продвижения и постов для соцсетей с помощью нейросети PAYK AI.',
      'strat_marketing_hint': 'Идеи рекламы бетона в Душанбе...',
      'common_retry': 'Повторить попытку',
      'common_loading': 'Загрузка...',
      'common_error': 'Ошибка',
      'common_cancel': 'Отмена',
      'common_add': 'Добавить',
      'common_create': 'Создать',
      'common_save': 'Сохранить',
      'common_copy': 'Копировать',
      'common_send': 'Отправить',
      'common_delete': 'Удалить',
      'common_edit': 'Изменить',
      'common_open': 'Открыть',
      'common_close': 'Закрыть',
      'common_search': 'Поиск',
      'common_no_data': 'Нет данных',
      'common_not_found': 'Ничего не найдено',
      'common_unknown': 'Неизвестно',
      'common_optional': 'Необязательно',
      'common_today': 'Сегодня',
      'common_total': 'Итого',
      'common_plan': 'План',
      'common_fact': 'Факт',
      'common_deviation': 'Отклонение',
      'common_yes': 'Да',
      'common_no': 'Нет',
      'common_select': 'Выберите',
      'common_back': 'Назад',
      'common_previous': 'Предыдущий',
      'common_next': 'Следующий',
      'discard_title': 'Изменения не сохранены',
      'discard_message':
          'Если закрыть окно сейчас,\nвведённые данные будут потеряны.',
      'discard_continue': 'Продолжить редактирование',
      'discard_close': 'Закрыть без сохранения',
      'nav_dashboard': 'Панель',
      'nav_cash': 'Касса',
      'nav_tasks': 'Задачи',
      'nav_warehouse': 'Склад',
      'nav_more': 'Еще',
      'login_subtitle': 'AI CFO Platform',
      'login_title': 'ВХОД В СИСТЕМУ',
      'login_username_label': 'Имя пользователя или Email',
      'login_password_label': 'Пароль',
      'login_username_required': 'Введите логин',
      'login_password_required': 'Введите пароль',
      'login_submit': 'Войти',
      'login_biometric': 'Войти с Face ID / Touch ID',
      'more_access_settings': 'НАСТРОЙКИ ДОСТУПА',
      'more_additional_modules': 'ДОПОЛНИТЕЛЬНЫЕ МОДУЛИ',
      'more_notifications': 'Уведомления и предупреждения',
      'more_strategy': 'Аналитика What-if и сценарии',
      'more_marketing': 'AI-маркетинг и соцсети',
      'more_legal': 'База законов РТ и шаблоны',
      'more_integrations': 'Внешние интеграции',
      'more_users': 'Пользователи и роли',
      'more_backups': 'Резервные копии базы',
      'more_user': 'Пользователь',
      'more_role_value': 'Роль: {role}',
      'language_dialog_title': 'Язык интерфейса',
      'language_russian': 'Русский',
      'language_tajik': 'Тоҷикӣ',
      'more_biometric_unavailable':
          'Биометрическая аутентификация недоступна на этом устройстве',
      'more_biometric_reason':
          'Подтвердите личность для включения входа по Face ID / Touch ID',
      'more_biometric_enabled': 'Вход по биометрии успешно включен',
      'more_biometric_cancelled': 'Аутентификация отменена или не пройдена',
      'more_biometric_error':
          'Не удалось настроить биометрию. Повторите попытку.',
      'more_biometric_disabled': 'Вход по биометрии отключен',
      'role_director': 'Директор',
      'role_manager': 'Менеджер',
      'role_accountant': 'Бухгалтер',
      'role_cashier': 'Кассир',
      'role_hr': 'HR-специалист',
      'role_viewer': 'Наблюдатель',
      'payment_cash': 'Наличные',
      'payment_card': 'Карта',
      'payment_alif': 'Алиф',
      'payment_dushanbe_city': 'Душанбе Сити',
      'payment_ocms': 'ОСМС',
      'cash_title': 'Касса и операции',
      'tasks_title': 'Задачи и планирование',
      'tasks_filter_all_projects': 'Все проекты',
      'tasks_tab_new': 'Новые',
      'tasks_tab_in_progress': 'В работе',
      'tasks_tab_review': 'Проверить',
      'tasks_tab_done': 'Готово',
      'tasks_tab_calendar': 'Календарь',
      'tasks_tab_gantt': 'Гант',
      'tasks_tab_analytics': 'Аналитика',
      'tasks_completed_message': 'Задача завершена',
      'tasks_undo': 'Отменить',
      'tasks_retry': 'Повторить попытку',
      'tasks_search_hint': 'Поиск по задачам...',
      'tasks_overdue': 'Просрочено',
      'tasks_list_header_new': 'Новые задачи',
      'tasks_list_header_in_progress': 'Задачи в работе',
      'tasks_list_header_review': 'Задачи на проверке',
      'tasks_list_header_done': 'Готовые задачи',
      'tasks_count_one': '{count} задача',
      'tasks_count_few': '{count} задачи',
      'tasks_count_many': '{count} задач',
      'tasks_priority_urgent_count_one': '{count} критическая',
      'tasks_priority_urgent_count_few': '{count} критические',
      'tasks_priority_urgent_count_many': '{count} критических',
      'tasks_priority_high_count': '{count} высокого приоритета',
      'tasks_status_todo': 'Новая',
      'tasks_status_in_progress': 'В работе',
      'tasks_status_review': 'На проверке',
      'tasks_status_done': 'Готово',
      'tasks_priority_low': 'Низкий',
      'tasks_priority_medium': 'Средний',
      'tasks_priority_high': 'Высокий',
      'tasks_priority_urgent': 'Критический',
      'tasks_add_title': 'Новая задача',
      'tasks_edit_title': 'Редактировать задачу',
      'tasks_field_title': 'Название задачи',
      'tasks_field_description': 'Описание',
      'tasks_field_stage_status': 'Этап и статус',
      'tasks_field_project': 'Проект',
      'tasks_select_project_optional': 'Выберите проект (опц.)',
      'tasks_no_project': 'Без проекта',
      'tasks_field_priority': 'Приоритет',
      'tasks_field_assignee': 'Исполнитель',
      'tasks_no_assignee': 'Без исполнителя',
      'tasks_field_start_date': 'Дата начала',
      'tasks_not_set': 'Не задана',
      'tasks_field_due_date': 'Срок сдачи',
      'tasks_create': 'Создать',
      'tasks_save_changes': 'Сохранить изменения',
      'tasks_calendar_today': 'Сегодня',
      'tasks_calendar_month_year': '{month} {year}',
      'tasks_calendar_due_on': 'Срок на {date}:',
      'tasks_calendar_select_day': 'Выберите день для просмотра задач',
      'tasks_calendar_empty_day': 'Нет запланированных задач на этот день',
      'tasks_project_value': 'Проект: {project}',
      'tasks_date_day_month': '{day} {month}',
      'tasks_date_day_month_year': '{day} {month} {year}',
      'tasks_due_value': 'Срок: {date}',
      'tasks_gantt_empty': 'Нет задач для отображения на диаграмме',
      'tasks_gantt_timeline_title': 'ВРЕМЕННАЯ ШКАЛА ЗАДАЧ',
      'tasks_gantt_task_column': 'Задача',
      'tasks_gantt_legend_review': 'Проверка',
      'tasks_unassigned': 'Не назначена',
      'tasks_analysis_overload_title': 'ПЕРЕГРУЗКА СОТРУДНИКОВ',
      'tasks_analysis_no_overload': 'Перегруженных сотрудников не обнаружено',
      'tasks_analysis_active_count': 'Активных: {count}',
      'tasks_analysis_overdue_count': 'Просрочено: {count}',
      'tasks_analysis_critical_path_title': 'КРИТИЧЕСКИЙ ПУТЬ ЗАДАЧ',
      'tasks_analysis_no_critical_path':
          'Блокирующих критический путь задач не найдено',
      'tasks_analysis_blocks_count': 'Блокирует задач: {count}',
      'tasks_month_january': 'Январь',
      'tasks_month_february': 'Февраль',
      'tasks_month_march': 'Март',
      'tasks_month_april': 'Апрель',
      'tasks_month_may': 'Май',
      'tasks_month_june': 'Июнь',
      'tasks_month_july': 'Июль',
      'tasks_month_august': 'Август',
      'tasks_month_september': 'Сентябрь',
      'tasks_month_october': 'Октябрь',
      'tasks_month_november': 'Ноябрь',
      'tasks_month_december': 'Декабрь',
      'tasks_month_date_january': 'января',
      'tasks_month_date_february': 'февраля',
      'tasks_month_date_march': 'марта',
      'tasks_month_date_april': 'апреля',
      'tasks_month_date_may': 'мая',
      'tasks_month_date_june': 'июня',
      'tasks_month_date_july': 'июля',
      'tasks_month_date_august': 'августа',
      'tasks_month_date_september': 'сентября',
      'tasks_month_date_october': 'октября',
      'tasks_month_date_november': 'ноября',
      'tasks_month_date_december': 'декабря',
      'tasks_month_short_january': 'янв.',
      'tasks_month_short_february': 'фев.',
      'tasks_month_short_march': 'мар.',
      'tasks_month_short_april': 'апр.',
      'tasks_month_short_may': 'май',
      'tasks_month_short_june': 'июн.',
      'tasks_month_short_july': 'июл.',
      'tasks_month_short_august': 'авг.',
      'tasks_month_short_september': 'сен.',
      'tasks_month_short_october': 'окт.',
      'tasks_month_short_november': 'ноя.',
      'tasks_month_short_december': 'дек.',
      'tasks_weekday_monday': 'Пн',
      'tasks_weekday_tuesday': 'Вт',
      'tasks_weekday_wednesday': 'Ср',
      'tasks_weekday_thursday': 'Чт',
      'tasks_weekday_friday': 'Пт',
      'tasks_weekday_saturday': 'Сб',
      'tasks_weekday_sunday': 'Вс',
      'cash_add_operation': 'Добавить операцию',
      'cash_tab_operations': 'Операции',
      'cash_tab_registers': 'Кассовые аппараты',
      'cash_search_hint': 'Поиск по получателю или категории...',
      'cash_filter_all': 'Все',
      'cash_income': 'Приход',
      'cash_expense': 'Расход',
      'cash_operations_not_found': 'Операции не найдены',
      'cash_transaction_details': '{category} • {paymentMethod}',
      'cash_amount_tjs': '{amount} TJS',
      'cash_signed_amount_tjs': '{sign}{amount} TJS',
      'cash_cashier_system': 'Система',
      'cash_shift_open': 'Кассовая смена открыта',
      'cash_shift_closed': 'Кассовая смена закрыта',
      'cash_shift_open_details': 'Начало: {time} • Баланс: {balance} TJS',
      'cash_shift_operations_blocked':
          'Проведение операций временно заблокировано',
      'cash_open_shift_title': 'Открыть кассовую смену',
      'cash_starting_balance_label': 'Начальный баланс кассы (TJS)',
      'cash_open_shift_action': 'Открыть смену',
      'cash_close_shift_title': 'Закрыть кассовую смену',
      'cash_close_shift_instruction':
          'Перед закрытием пересчитайте фактический баланс в физическом ящике кассы.',
      'cash_actual_balance_label': 'Фактический остаток в кассе (TJS)',
      'cash_actual_balance_hint': 'Укажите пересчитанную сумму',
      'cash_close_shift_action': 'Закрыть смену',
      'cash_register_summary_empty': 'Сводка кассовых аппаратов пуста',
      'cash_shift_open_badge': 'СМЕНА ОТКРЫТА',
      'cash_shift_closed_badge': 'СМЕНА ЗАКРЫТА',
      'cash_summary_income': 'Приход:',
      'cash_summary_expense': 'Расход:',
      'cash_summary_net_flow': 'Чистый поток:',
      'cash_new_operation': 'Новая операция',
      'cash_register': 'Касса',
      'cash_amount_required': 'Укажите сумму',
      'cash_operation_amount': 'Сумма операции',
      'cash_payment_method': 'Способ оплаты',
      'cash_category': 'Категория',
      'cash_select_category': 'Выберите категорию',
      'cash_counterparty_required': 'Введите наименование',
      'cash_counterparty': 'Контрагент',
      'cash_counterparty_hint': 'Название контрагента',
      'cash_description': 'Описание',
      'cash_description_hint': 'Комментарий к операции',
      'cash_select_category_required': 'Пожалуйста, выберите категорию',
      'cash_record': 'Записать',
      'cash_category_sales': 'Продажи',
      'cash_category_services': 'Услуги',
      'cash_category_advance': 'Аванс',
      'cash_category_refund': 'Возврат',
      'cash_category_other_income': 'Прочий доход',
      'cash_category_rent': 'Аренда',
      'cash_category_salary': 'Зарплата',
      'cash_category_goods': 'Товары',
      'cash_category_utilities': 'Коммунальные',
      'cash_category_marketing': 'Реклама',
      'cash_category_transport': 'Транспорт',
      'cash_category_taxes': 'Налоги',
      'cash_category_other_expense': 'Прочий расход',
      'cash_payment_cash': 'Наличные',
      'cash_payment_card': 'Карта',
      'cash_payment_alif': 'Алиф',
      'cash_payment_dushanbe_city': 'Душанбе Сити',
      'cash_payment_ocms': 'ОСМС',
      'warehouse_add_product_title': 'Добавить новый товар',
      'warehouse_unit_pieces_short': 'шт',
      'warehouse_product_name': 'Название товара',
      'warehouse_product_sku_label': 'SKU (Артикул)',
      'warehouse_unit_label': 'Ед. измерения',
      'warehouse_price_label': 'Цена (TJS)',
      'warehouse_initial_stock': 'Начальный остаток',
      'warehouse_product_sku': 'SKU: {sku}',
      'warehouse_product_price': 'Цена: {price} TJS',
      'warehouse_quantity_with_unit': '{quantity} {unit}',
      'warehouse_amount_tjs': '{amount} TJS',
      'warehouse_movement_income': 'Приход',
      'warehouse_movement_expense': 'Расход',
      'warehouse_movement_quantity': '{sign}{quantity} шт',
      'warehouse_movement_title': 'Движение товара',
      'warehouse_movement_purchase': 'Приход (закупка)',
      'warehouse_movement_sale': 'Расход (продажа)',
      'warehouse_product': 'Товар',
      'warehouse_select_product': 'Выберите товар',
      'warehouse_product_with_stock': '{name} (остаток: {stock})',
      'warehouse_quantity_label': 'Количество',
      'warehouse_quantity_hint': 'Например: 10',
      'warehouse_optional_amount_label': 'Сумма (необязательно)',
      'warehouse_amount_hint': 'кол-во × цена',
      'warehouse_note_label': 'Примечание',
      'warehouse_note_hint': 'Комментарий к движению',
      'warehouse_record': 'Записать',
      'crm_retry': 'Повторить попытку',
      'crm_ltv_orders': 'LTV: {amount} TJS (заказы: {count})',
      'crm_stage_lead': 'ЛИД',
      'crm_stage_proposal_status': 'ПРЕДЛОЖЕНИЕ',
      'crm_stage_won': 'УСПЕШНО',
      'crm_stage_lost': 'ПРОИГРАНО',
      'crm_stage_negotiation': 'ПЕРЕГОВОРЫ',
      'crm_client_value': 'Контрагент: {client}',
      'crm_churn_title': 'ОТТОК КЛИЕНТОВ (CHURN)',
      'crm_churn_at_risk': 'Клиентов под риском оттока',
      'crm_reactivated': 'Реактивировано клиентов',
      'crm_new_client': 'Новый контрагент',
      'crm_full_name_company': 'ФИО / Компания',
      'crm_phone': 'Телефон',
      'crm_email': 'Email',
      'crm_acquisition_cost': 'Стоимость привлечения (CAC)',
      'crm_note': 'Примечание',
      'crm_new_deal': 'Новая сделка',
      'crm_client_label': 'Клиент',
      'crm_select_client': 'Выберите клиента',
      'crm_no_client': 'Без клиента',
      'crm_deal_title': 'Название сделки',
      'crm_deal_amount': 'Сумма сделки (TJS)',
      'crm_funnel_stage': 'Этап воронки',
      'crm_stage_lead_label': 'Лид / Заявка',
      'crm_stage_proposal': 'Коммерческое предл.',
      'crm_stage_negotiation_label': 'Согласование / Договор',
      'crm_stage_won_label': 'Сделка выиграна',
      'crm_loyalty_gold': 'Золотой',
      'crm_loyalty_silver': 'Серебряный',
      'crm_loyalty_platinum': 'Платиновый',
      'crm_loyalty_bronze': 'Бронзовый',
      'dashboard_retry': 'Повторить попытку',
      'dashboard_title': 'Финансовая панель',
      'dashboard_tab_overview': 'Обзор',
      'dashboard_tab_pnl': 'P&L Отчет',
      'dashboard_tab_plan_fact': 'План-Факт',
      'dashboard_tab_break_even': 'Безубыточность',
      'dashboard_tab_abc': 'ABC Анализ',
      'dashboard_tab_accounts_rates': 'Счета и Валюты',
      'dashboard_tab_ai_insights': 'ИИ Инсайты',
      'dashboard_daily_recommendation_title': 'Рекомендация дня',
      'dashboard_daily_recommendation_content':
          'Свободный остаток вырос на 8% за неделю. Рекомендуется перевести 15 000 TJS на накопительный счет, чтобы снизить инфляционные риски.',
      'dashboard_key_metrics_title': 'ГЛАВНЫЕ ПОКАЗАТЕЛИ',
      'dashboard_cash_flow_30_days_title': 'ДВИЖЕНИЕ ДЕНЕГ ЗА 30 ДНЕЙ',
      'dashboard_metric_cash_balance': 'Остаток в кассах',
      'dashboard_metric_revenue_june': 'Выручка (июнь)',
      'dashboard_metric_expenses_june': 'Расходы (июнь)',
      'dashboard_metric_net_profit': 'Чистая прибыль',
      'dashboard_metric_break_even': 'Точка безубыт.',
      'dashboard_metric_normal': 'норма',
      'dashboard_metric_cash_forecast': 'Прогноз кассы',
      'dashboard_total': 'Итого',
      'dashboard_pnl_income_by_category': 'ДОХОДЫ ПО КАТЕГОРИЯМ',
      'dashboard_pnl_expenses_by_category': 'РАСХОДЫ ПО КАТЕГОРИЯМ',
      'dashboard_pnl_net_profit': 'ЧИСТАЯ ПРИБЫЛЬ',
      'dashboard_budget_completion': 'ОБЩЕЕ ВЫПОЛНЕНИЕ БЮДЖЕТА',
      'dashboard_category_comparison': 'СРАВНЕНИЕ ПО КАТЕГОРИЯМ',
      'dashboard_plan': 'План',
      'dashboard_fact': 'Факт',
      'dashboard_deviation': 'Отклонение',
      'dashboard_margin_of_safety': 'ЗАПАС ФИНАНСОВОЙ ПРОЧНОСТИ',
      'dashboard_business_stable': 'Бизнес устойчив',
      'dashboard_danger_zone': 'Опасная зона',
      'dashboard_break_even_metrics': 'ПОКАЗАТЕЛИ БЕЗУБЫТОЧНОСТИ',
      'dashboard_current_revenue': 'Текущая выручка',
      'dashboard_break_even_point': 'Точка безубыточности',
      'dashboard_fixed_costs': 'Постоянные затраты',
      'dashboard_variable_costs': 'Переменные затраты',
      'dashboard_contribution_margin_ratio': 'Коэфф. маржинального дохода',
      'dashboard_abc_by_categories': 'По категориям',
      'dashboard_abc_by_clients': 'По клиентам',
      'dashboard_abc_category_analysis':
          'АНАЛИЗ ТОВАРНЫХ КАТЕГОРИЙ (ABC-анализ)',
      'dashboard_abc_client_analysis': 'АНАЛИЗ КОНТРАГЕНТОВ (ABC-анализ)',
      'dashboard_no_analysis_data': 'Нет данных для анализа',
      'dashboard_turnover_share':
          'Доля в обороте: {share}% (Накоп: {cumulative}%)',
      'dashboard_bank_accounts': 'БАНКОВСКИЕ СЧЕТА',
      'dashboard_settlement_account': 'Расчетный счет',
      'dashboard_total_balance_tjs': 'ОБЩИЙ ОСТАТОК (В TJS ЭКВИВАЛЕНТЕ)',
      'dashboard_nbt_rates': 'КУРСЫ НАЦИОНАЛЬНОГО БАНКА (NBT)',
      'dashboard_cash_gap_risk': 'РИСК КАССОВОГО РАЗРЫВА',
      'dashboard_days_to_cash_gap': 'Дней до кассового разрыва: {days}',
      'dashboard_ai_recommendations_analysis': 'ИИ РЕКОМЕНДАЦИИ И АНАЛИЗ',
      'dashboard_cash_flow': 'Движение денег',
      'dashboard_cash_flow_subtitle':
          'Приход и расход за 30 дней ({period} • в {currency})',
      'dashboard_income': 'Приход',
      'dashboard_expense': 'Расход',
      'dashboard_thousands_short': 'тыс.',
      'notifications_title': 'Инфо и предупреждения',
      'notifications_retry': 'Повторить попытку',
      'notifications_critical_audit': 'КРИТИЧЕСКИЙ АУДИТ (СРОЧНО)',
      'notifications_ai_recommendations': 'AI РЕКОМЕНДАЦИИ И ПРОГНОЗЫ (ВАЖНО)',
      'notifications_legal_calendar': 'НАЛОГОВЫЙ И ЮР. КАЛЕНДАРЬ (К СВЕДЕНИЮ)',
      'notifications_empty': 'Нарушений и нерассмотренных AI-советов нет',
      'notifications_mark_read': 'Отметить как прочитанное',
      'users_title': 'Управление доступом (SYS)',
      'users_search_hint': 'Поиск по логину или имени',
      'users_empty': 'Пользователей не найдено',
      'users_login_value': 'Логин: {value}',
      'users_email_value': 'Email: {value}',
      'users_phone_value': 'Телефон: {value}',
      'users_active': 'Активен',
      'users_blocked': 'Заблокирован',
      'users_delete_title': 'Удалить пользователя?',
      'users_delete_message':
          'Пользователь потеряет доступ к системе. Это действие необратимо.',
      'users_edit_title': 'Изменить пользователя',
      'users_new_title': 'Новый пользователь',
      'users_full_name': 'ФИО',
      'users_login': 'Логин',
      'users_email': 'Email',
      'users_phone': 'Телефон',
      'users_role': 'Роль',
      'users_new_password': 'Новый пароль (оставьте пустым)',
      'users_password': 'Пароль',
      'users_security_access': 'БЕЗОПАСНОСТЬ И ДОСТУП',
      'users_account_active': 'Учетная запись активна',
      'users_two_factor': 'Двухфакторная аутентификация (2FA)',
      'users_two_factor_hint': 'SMS-код при входе',
      'role_seller': 'Продавец',
      'integrations_title': 'Внешние интеграции (INT)',
      'integrations_connected_systems': 'ПОДКЛЮЧЕННЫЕ СИСТЕМЫ',
      'integrations_status_active': 'Активна',
      'integrations_status_inactive': 'Неактивна',
      'integrations_sync': 'Синхр.',
      'integrations_sync_logs': 'ЛОГИ СИНХРОНИЗАЦИИ',
      'integrations_empty_logs': 'Логи синхронизации пусты.',
      'integrations_success': 'Успешно',
      'integrations_error': 'Ошибка',
      'integrations_records_imported_one': 'Импортирована: {count} запись',
      'integrations_records_imported_few': 'Импортировано: {count} записи',
      'integrations_records_imported_many': 'Импортировано: {count} записей',
      'legal_title': 'Юридический блок РТ',
      'legal_clear_history': 'Очистить историю',
      'legal_loading_title': 'База законов и ИИ-Юрист',
      'legal_error_title': 'Ошибка',
      'legal_retry': 'Повторить попытку',
      'legal_tab_ai_lawyer': 'ИИ-Юрист',
      'legal_tab_laws': 'Законы РТ',
      'legal_tab_constructor': 'Конструктор',
      'legal_tab_deadlines': 'Сроки',
      'legal_prompt_simplified_tax': 'Ставка по упрощенке в РТ',
      'legal_prompt_employment_contract': 'Как оформить трудовой договор в РТ?',
      'legal_prompt_social_tax_deadlines':
          'Сроки уплаты соцналога за сотрудников',
      'legal_ai_thinking': 'ИИ-Юрист думает...',
      'legal_question_hint': 'Задайте вопрос юристу...',
      'legal_category_all': 'Все',
      'legal_category_taxes': 'Налоги',
      'legal_category_labor_law': 'Трудовое право',
      'legal_category_corporate_law': 'Корпоративное право',
      'legal_search_hint': 'Поиск по базе законов...',
      'legal_nothing_found': 'Ничего не найдено',
      'legal_default_law_category': 'Законодательство',
      'legal_read_official_site': 'Читать на официальном сайте',
      'legal_document_generated': 'ДОКУМЕНТ СГЕНЕРИРОВАН',
      'legal_date': 'Дата: {date}',
      'legal_contract_copied': 'Текст договора скопирован в буфер обмена',
      'legal_copy_text': 'Копировать текст',
      'legal_create_new': 'Создать новый',
      'legal_generating_document':
          'Генерация документа на основе реквизитов...',
      'legal_general_template': 'Общий шаблон',
      'legal_fill_details': 'Заполнить реквизиты',
      'legal_contract_details': 'Реквизиты для договора',
      'legal_not_specified': '[{label} не указан]',
      'legal_generate_contract': 'Сгенерировать договор',
      'legal_deadline_summary': 'Срок сдачи: {date} ({days} дн. осталось)',
      'marketing_title': 'AI-Маркетинг и Соцсети',
      'marketing_tab_ai_writer': 'ИИ-Копирайтер',
      'marketing_tab_campaigns': 'Кампании',
      'marketing_tab_posts': 'Посты',
      'marketing_writer_description':
          'Сгенерируйте продающие слоганы, идеи рекламных постов или готовый текстовый контент для соцсетей компании с помощью ИИ.',
      'marketing_mode_ad_ideas': 'Идеи рекламы',
      'marketing_mode_ready_post': 'Готовый пост',
      'marketing_post_prompt_hint':
          'Напиши рекламный пост о скидках на кирпичи...',
      'marketing_ideas_prompt_hint': 'Слоганы для цементного завода...',
      'marketing_ai_thinking': 'ИИ думает...',
      'marketing_create_content': 'Создать контент',
      'marketing_generated_ideas': 'СГЕНЕРИРОВАННЫЕ ИДЕИ',
      'marketing_publication_text': 'ТЕКСТ ПУБЛИКАЦИИ',
      'marketing_copied': 'Скопировано в буфер обмена',
      'marketing_post_saved_draft': 'Пост сохранен в черновики',
      'marketing_no_campaigns': 'Рекламные кампании не созданы',
      'marketing_channel_none': 'Не указан',
      'marketing_budget': 'Бюджет',
      'marketing_spent': 'Потрачено',
      'marketing_leads': 'Лиды',
      'marketing_sales': 'Продажи',
      'marketing_no_posts': 'Черновиков или постов не найдено',
      'marketing_status_draft': 'Черновик',
      'marketing_status_published': 'Опубликован',
      'marketing_created_at': 'Создан: {date}',
      'marketing_publish_telegram': 'В Telegram',
      'marketing_new_campaign': 'Новая рекламная кампания',
      'marketing_campaign_name': 'Название кампании',
      'marketing_channel': 'Канал',
      'marketing_budget_tjs': 'Бюджет (TJS)',
      'marketing_spent_tjs': 'Потрачено (TJS)',
      'marketing_leads_count': 'Количество Лидов',
      'marketing_sales_count': 'Количество Продаж',
      'marketing_revenue_tjs': 'Полученная выручка (TJS)',
      'marketing_create': 'Создать',
      'marketing_new_publication': 'Новая публикация',
      'marketing_publication_hint': 'Текст публикации...',
      'marketing_publication_channel': 'Канал публикации',
      'marketing_save_draft': 'Сохранить черновик',
      'strategy_title': 'Стратегия и AI-Маркетинг',
      'strategy_tab_whatif': 'What-if Анализ',
      'strategy_tab_marketing': 'ИИ-Маркетолог',
      'strategy_tab_matrices': 'Матрицы',
      'strategy_whatif_description':
          'Задайте финансовый вопрос ИИ о влиянии внешних/внутренних изменений на баланс компании.',
      'strategy_whatif_hint': 'Что если продажи упадут на 10%?',
      'strategy_whatif_template_revenue_drop':
          'Что будет, если выручка снизится на 15%?',
      'strategy_whatif_template_purchase_costs':
          'Что будет, если расходы на закупки увеличатся на 10%?',
      'strategy_whatif_template_new_employee':
          'Что будет при найме нового сотрудника с окладом 3000 TJS?',
      'strategy_marketing_description':
          'Генерация идей продвижения и постов для соцсетей с помощью нейросети PAYK AI.',
      'strategy_marketing_hint': 'Идеи рекламы бетона в Душанбе...',
      'strategy_marketing_template_concrete':
          'Идеи продвижения производства бетона в Худжанде',
      'strategy_marketing_template_self_checkout':
          'Креативные слоганы для кассы самообслуживания',
      'strategy_marketing_template_wholesale_builders':
          'Каналы привлечения оптовых строителей в Душанбе',
      'strategy_scenario_analysis': 'AI АНАЛИЗ СЦЕНАРИЯ',
      'strategy_marketing_ideas': 'ИИ ИДЕИ ПРОДВИЖЕНИЯ',
      'strategy_generate_ideas_action': 'Сгенерировать идеи',
      'strategy_analyzing_company': 'ИИ анализирует компанию...',
      'strategy_generate_analysis': 'Сгенерировать AI-анализ РТ',
      'strategy_no_analysis': 'Нет сгенерированного анализа для этой матрицы',
      'strategy_analysis_period': 'AI АНАЛИЗ ЗА ПЕРИОД: {period}',
      'strategy_no_data': 'Нет данных',
      'strategy_swot_strengths': 'Сильные стороны (Strengths)',
      'strategy_swot_weaknesses': 'Слабые стороны (Weaknesses)',
      'strategy_swot_opportunities': 'Возможности (Opportunities)',
      'strategy_swot_threats': 'Угрозы (Threats)',
      'strategy_pestel_political': 'Политические факторы',
      'strategy_pestel_economic': 'Экономические факторы',
      'strategy_pestel_social': 'Социальные факторы',
      'strategy_pestel_technological': 'Технологические факторы',
      'strategy_pestel_environmental': 'Экологические факторы',
      'strategy_pestel_legal': 'Правовые факторы',
      'strategy_factors_found_one': '{count} фактор найден',
      'strategy_factors_found_few': '{count} фактора найдено',
      'strategy_factors_found_many': '{count} факторов найдено',
      'strategy_data_unavailable': 'Данные отсутствуют',
      'strategy_bcg_star': 'Звезда',
      'strategy_bcg_cash_cow': 'Дойная корова',
      'strategy_bcg_question': 'Трудные дети',
      'strategy_bcg_dog': 'Собака',
      'strategy_bcg_no_categories': 'Нет товарных категорий в BCG анализе',
      'strategy_bcg_market_metrics':
          'Доля рынка: {share}% • Рост рынка: {growth}%',
    },
    'tg': {
      'app_title': 'PAYK CFO',
      'dashboard': 'Панели молиявӣ',
      'cash': 'Хазина ва амалиётҳо',
      'tasks': 'Вазифаҳо ва банақшагирӣ',
      'info': 'Маълумот ва огоҳиҳо',
      'more': 'Иловагӣ',
      'revenue': 'Даромад (июн)',
      'expenses': 'Хароҷот (июн)',
      'net_profit': 'Фоидаи соф',
      'break_even': 'Нуқтаи безарарӣ',
      'forecast': 'Пешгӯии хазина',
      'cash_balance': 'Боқимондаи хазина',
      'search_placeholder': 'Ҷустуҷӯ аз рӯи қабулкунанда ё категория...',
      'all': 'Ҳама',
      'income': 'Даромад',
      'expense': 'Хароҷот',
      'open_shift': 'Кушодани баст',
      'close_shift': 'Пӯшидани баст',
      'logout': 'Хуроҷ аз система',
      'new_operation': 'Амалиёти нав',
      'add': 'Илова кардан',
      'cancel': 'Бекор кардан',
      'amount': 'Маблағи амалиёт',
      'recipient': 'Номгӯй / Контрагент',
      'category': 'Категория / Модда',
      'payment_method': 'УСУЛИ ПАРДОХТ',
      'save_to_ledger': 'Сабт кардан',
      'biometrics': 'Вуруд бо биометрия (Face ID / Touch ID)',
      'language': 'Забони интерфейс (RU/TJ)',
      'active_shift': 'Басти хазина кушода аст',
      'closed_shift': 'Басти хазина пӯшида аст',
      'no_operations': 'Амалиётҳо ёфт нашуданд',
      'no_tasks': 'Дар ин сутун вазифаҳо нест',
      'no_alerts': 'Вайронкуниҳо ва маслиҳатҳои ИИ ёфт нашуданд',
      'profile': 'Алишер Раҳимов',
      'role': 'Нақш',
      'warehouse': 'Баҳисобгирии анбор',
      'warehouse_title': 'Баҳисобгирии анбор',
      'warehouse_tab_products': 'Молҳо',
      'warehouse_tab_movements': 'Ҳаракатҳо',
      'warehouse_stats_count': 'Миқдори молҳо',
      'warehouse_stats_value': 'Боқимондаи анбор',
      'warehouse_empty_products': 'Дар анбор молҳо нест',
      'warehouse_empty_movements': 'Таърихи ҳаракатҳо холӣ аст',
      'price': 'Нарх',
      'hr_menu': 'Кормандон ва кадрҳо',
      'hr_title': 'Кадрҳо ва KPI',
      'hr_select_month': 'Моҳро интихоб кунед',
      'hr_period_month_year': '{month} {year}',
      'hr_month_jan_short': 'Янв',
      'hr_month_feb_short': 'Фев',
      'hr_month_mar_short': 'Мар',
      'hr_month_apr_short': 'Апр',
      'hr_month_may_short': 'Май',
      'hr_month_jun_short': 'Июн',
      'hr_month_jul_short': 'Июл',
      'hr_month_aug_short': 'Авг',
      'hr_month_sep_short': 'Сен',
      'hr_month_oct_short': 'Окт',
      'hr_month_nov_short': 'Ноя',
      'hr_month_dec_short': 'Дек',
      'hr_month_january': 'Январ',
      'hr_month_february': 'Феврал',
      'hr_month_march': 'Март',
      'hr_month_april': 'Апрел',
      'hr_month_may': 'Май',
      'hr_month_june': 'Июн',
      'hr_month_july': 'Июл',
      'hr_month_august': 'Август',
      'hr_month_september': 'Сентябр',
      'hr_month_october': 'Октябр',
      'hr_month_november': 'Ноябр',
      'hr_month_december': 'Декабр',
      'hr_status_active': 'Кор мекунад',
      'hr_status_vacation': 'Дар рухсатӣ',
      'hr_status_fired': 'Аз кор озод шудааст',
      'hr_default_employee': 'Корманд',
      'hr_default_main_office': 'Идораи асосӣ',
      'hr_employee_details': '{position} • {department}',
      'hr_amount_tjs': '{amount} TJS',
      'hr_kpi_empty': 'Дар ин давра ягон вайронкунии KPI нест.',
      'hr_percentage': '{value}%',
      'hr_kpi_metric_value': 'Нишондиҳанда: {metric}',
      'hr_kpi_plan_fact': 'Нақша: {plan} | Иҷро: {fact}',
      'hr_ai_analysis': 'Таҳлили ИИ: {comment}',
      'hr_salary_empty': 'Барои ин давра маош ҳисоб карда нашудааст.',
      'hr_salary_base': 'Маоши асосӣ: {amount}',
      'hr_salary_bonus': 'Мукофотпулӣ: +{amount}',
      'hr_salary_deductions': 'Нигоҳдоштҳо: -{amount}',
      'hr_kpi_formula': 'Формулаи KPI: {formula}',
      'hr_hire_title': 'Қабул ба кор',
      'hr_employee_full_name': 'Ному насаби корманд',
      'hr_position': 'Вазифа',
      'hr_salary_tjs': 'Маош (TJS)',
      'hr_phone': 'Телефон',
      'hr_email': 'Почтаи электронӣ',
      'hr_salary_adjustment_title': 'Ислоҳи маош: {employee}',
      'hr_base_salary': 'Маоши асосӣ',
      'hr_deductions_penalties': 'Нигоҳдоштҳо / Ҷаримаҳо',
      'hr_bonus_formula': 'Формулаи мукофотпулӣ (KPI)',
      'hr_bonus_formula_hint': 'масалан: fact_value * 0.1',
      'hr_recalculate': 'Аз нав ҳисоб кардан',
      'hr_tab_staff': 'Кормандон',
      'hr_tab_kpi': 'Назорати KPI',
      'hr_tab_salary': 'Варақаи маош',
      'status_active': 'Кор мекунад',
      'status_vacation': 'Дар рухсатӣ',
      'status_fired': 'Озод шудааст',
      'kpi_metric': 'Нишондиҳанда',
      'kpi_plan': 'Нақша',
      'kpi_fact': 'Далел',
      'crm_menu': 'Амалиётҳо ва Лидҳо',
      'crm_title': 'Лидҳо ва амалиётҳо (CRM)',
      'crm_tab_clients': 'Мизоҷон',
      'crm_tab_deals': 'Муомилаҳо',
      'crm_tab_stats': 'Таҳлил',
      'crm_no_clients': 'Рӯйхати мизоҷон холӣ аст',
      'crm_no_deals': 'Амалиёти фаъол нест',
      'crm_client': 'Тарафи шартнома',
      'crm_churn_risk': 'ХАВФИ РАФТАН',
      'crm_stat_total_clients': 'Шумораи мизоҷон',
      'crm_stat_active_clients': 'Мизоҷони фаъол',
      'crm_stat_total_ltv': 'LTV-и умумӣ',
      'crm_stat_total_cac': 'CAC-и умумӣ',
      'strat_menu': 'Таҳлили What-if ва AI-Маркетинг',
      'strat_title': 'Стратегия ва AI-Маркетинг',
      'strat_tab_whatif': 'Таҳлили What-if',
      'strat_tab_marketing': 'Маркетологи ИИ',
      'strat_whatif_desc':
          'Аз ИИ саволи молиявӣ дар бораи таъсири тағиротҳои беруна/дохилӣ ба тавозуни ширкат пурсед.',
      'strat_whatif_hint': 'Чӣ мешавад, агар фурӯш 10% кам шавад?',
      'strat_marketing_desc':
          'Генерацияи идеяҳои пешбурд ва постҳо барои шабакаҳои иҷтимоӣ бо ёрии шабакаи нейронии PAYK AI.',
      'strat_marketing_hint': 'Идеяҳои таблиғи бетон дар Душанбе...',
      'common_retry': 'Аз нав кӯшиш кунед',
      'common_loading': 'Бор шуда истодааст...',
      'common_error': 'Хато',
      'common_cancel': 'Бекор кардан',
      'common_add': 'Илова кардан',
      'common_create': 'Сохтан',
      'common_save': 'Нигоҳ доштан',
      'common_copy': 'Нусхабардорӣ',
      'common_send': 'Фиристодан',
      'common_delete': 'Нест кардан',
      'common_edit': 'Тағйир додан',
      'common_open': 'Кушодан',
      'common_close': 'Пӯшидан',
      'common_search': 'Ҷустуҷӯ',
      'common_no_data': 'Маълумот нест',
      'common_not_found': 'Ҳеҷ чиз ёфт нашуд',
      'common_unknown': 'Номаълум',
      'common_optional': 'Ихтиёрӣ',
      'common_today': 'Имрӯз',
      'common_total': 'Ҳамагӣ',
      'common_plan': 'Нақша',
      'common_fact': 'Амалӣ',
      'common_deviation': 'Фарқият',
      'common_yes': 'Ҳа',
      'common_no': 'Не',
      'common_select': 'Интихоб кунед',
      'common_back': 'Қафо',
      'common_previous': 'Қаблӣ',
      'common_next': 'Баъдӣ',
      'discard_title': 'Тағйирот нигоҳ дошта нашудааст',
      'discard_message':
          'Агар ҳоло равзанаро пӯшед,\nмаълумоти воридшуда гум мешавад.',
      'discard_continue': 'Идома додани таҳрир',
      'discard_close': 'Бе нигоҳдорӣ пӯшидан',
      'nav_dashboard': 'Панел',
      'nav_cash': 'Хазина',
      'nav_tasks': 'Вазифаҳо',
      'nav_warehouse': 'Анбор',
      'nav_more': 'Иловагӣ',
      'login_subtitle': 'Платформаи молиявии AI',
      'login_title': 'ВОРИДШАВӢ БА СИСТЕМА',
      'login_username_label': 'Номи корбар ё почтаи электронӣ',
      'login_password_label': 'Рамз',
      'login_username_required': 'Номи корбарро ворид кунед',
      'login_password_required': 'Рамзро ворид кунед',
      'login_submit': 'Ворид шудан',
      'login_biometric': 'Ворид шудан бо Face ID / Touch ID',
      'more_access_settings': 'ТАНЗИМОТИ ДАСТРАСӢ',
      'more_additional_modules': 'МОДУЛҲОИ ИЛОВАГӢ',
      'more_notifications': 'Огоҳиномаҳо ва ҳушдорҳо',
      'more_strategy': 'Таҳлили What-if ва сенарияҳо',
      'more_marketing': 'AI-маркетинг ва шабакаҳои иҷтимоӣ',
      'more_legal': 'Пойгоҳи қонунҳои ҶТ ва қолабҳо',
      'more_integrations': 'Ҳамгироиҳои беруна',
      'more_users': 'Корбарон ва нақшҳо',
      'more_backups': 'Нусхаҳои эҳтиётии пойгоҳи додаҳо',
      'more_user': 'Корбар',
      'more_role_value': 'Нақш: {role}',
      'language_dialog_title': 'Забони интерфейс',
      'language_russian': 'Русӣ',
      'language_tajik': 'Тоҷикӣ',
      'more_biometric_unavailable':
          'Тасдиқи биометрӣ дар ин дастгоҳ дастнорас аст',
      'more_biometric_reason':
          'Барои фаъол кардани вуруд бо Face ID / Touch ID шахсияти худро тасдиқ кунед',
      'more_biometric_enabled': 'Вуруд бо биометрия бомуваффақият фаъол шуд',
      'more_biometric_cancelled': 'Тасдиқ бекор карда шуд ё анҷом наёфт',
      'more_biometric_error': 'Биометрия танзим нашуд. Боз кӯшиш кунед.',
      'more_biometric_disabled': 'Вуруд бо биометрия ғайрифаъол шуд',
      'role_director': 'Директор',
      'role_manager': 'Менеҷер',
      'role_accountant': 'Муҳосиб',
      'role_cashier': 'Хазинадор',
      'role_hr': 'Мутахассиси кадрҳо',
      'role_viewer': 'Нозир',
      'payment_cash': 'Нақдӣ',
      'payment_card': 'Корт',
      'payment_alif': 'Алиф',
      'payment_dushanbe_city': 'Душанбе Сити',
      'payment_ocms': 'ОСМС',
      'cash_title': 'Хазина ва амалиётҳо',
      'tasks_title': 'Вазифаҳо ва банақшагирӣ',
      'tasks_filter_all_projects': 'Ҳамаи лоиҳаҳо',
      'tasks_tab_new': 'Нав',
      'tasks_tab_in_progress': 'Дар кор',
      'tasks_tab_review': 'Санҷиш',
      'tasks_tab_done': 'Анҷомшуда',
      'tasks_tab_calendar': 'Тақвим',
      'tasks_tab_gantt': 'Гант',
      'tasks_tab_analytics': 'Таҳлил',
      'tasks_completed_message': 'Вазифа анҷом ёфт',
      'tasks_undo': 'Бекор кардан',
      'tasks_retry': 'Аз нав кӯшиш кардан',
      'tasks_search_hint': 'Ҷустуҷӯи вазифаҳо...',
      'tasks_overdue': 'Муҳлатгузашта',
      'tasks_list_header_new': 'Вазифаҳои нав',
      'tasks_list_header_in_progress': 'Вазифаҳои дар кор',
      'tasks_list_header_review': 'Вазифаҳои дар санҷиш',
      'tasks_list_header_done': 'Вазифаҳои анҷомшуда',
      'tasks_count_one': '{count} вазифа',
      'tasks_count_few': '{count} вазифа',
      'tasks_count_many': '{count} вазифа',
      'tasks_priority_urgent_count_one': '{count} фаврӣ',
      'tasks_priority_urgent_count_few': '{count} фаврӣ',
      'tasks_priority_urgent_count_many': '{count} фаврӣ',
      'tasks_priority_high_count': '{count} бо афзалияти баланд',
      'tasks_status_todo': 'Нав',
      'tasks_status_in_progress': 'Дар кор',
      'tasks_status_review': 'Дар санҷиш',
      'tasks_status_done': 'Анҷомшуда',
      'tasks_priority_low': 'Паст',
      'tasks_priority_medium': 'Миёна',
      'tasks_priority_high': 'Баланд',
      'tasks_priority_urgent': 'Фаврӣ',
      'tasks_add_title': 'Вазифаи нав',
      'tasks_edit_title': 'Таҳрири вазифа',
      'tasks_field_title': 'Номи вазифа',
      'tasks_field_description': 'Тавсиф',
      'tasks_field_stage_status': 'Марҳила ва ҳолат',
      'tasks_field_project': 'Лоиҳа',
      'tasks_select_project_optional': 'Лоиҳаро интихоб кунед (ихт.)',
      'tasks_no_project': 'Бе лоиҳа',
      'tasks_field_priority': 'Афзалият',
      'tasks_field_assignee': 'Иҷрокунанда',
      'tasks_no_assignee': 'Бе иҷрокунанда',
      'tasks_field_start_date': 'Санаи оғоз',
      'tasks_not_set': 'Муайян нашудааст',
      'tasks_field_due_date': 'Муҳлати супоридан',
      'tasks_create': 'Эҷод кардан',
      'tasks_save_changes': 'Нигоҳ доштани тағйирот',
      'tasks_calendar_today': 'Имрӯз',
      'tasks_calendar_month_year': '{month} {year}',
      'tasks_calendar_due_on': 'Муҳлати иҷро — {date}:',
      'tasks_calendar_select_day': 'Барои дидани вазифаҳо рӯзро интихоб кунед',
      'tasks_calendar_empty_day': 'Дар ин рӯз вазифаи банақшагирифта нест',
      'tasks_project_value': 'Лоиҳа: {project}',
      'tasks_date_day_month': '{day} {month}',
      'tasks_date_day_month_year': '{day} {month} соли {year}',
      'tasks_due_value': 'Муҳлат: {date}',
      'tasks_gantt_empty': 'Барои намоиш дар диаграмма вазифа нест',
      'tasks_gantt_timeline_title': 'ҶАДВАЛИ ВАҚТИИ ВАЗИФАҲО',
      'tasks_gantt_task_column': 'Вазифа',
      'tasks_gantt_legend_review': 'Санҷиш',
      'tasks_unassigned': 'Таъин нашудааст',
      'tasks_analysis_overload_title': 'САРБОРИИ ЗИЁДИ КОРМАНДОН',
      'tasks_analysis_no_overload': 'Корманди дорои сарбории зиёд ёфт нашуд',
      'tasks_analysis_active_count': 'Фаъол: {count}',
      'tasks_analysis_overdue_count': 'Муҳлатгузашта: {count}',
      'tasks_analysis_critical_path_title': 'РОҲИ БУҲРОНИИ ВАЗИФАҲО',
      'tasks_analysis_no_critical_path':
          'Вазифаи масдудкунандаи роҳи буҳронӣ ёфт нашуд',
      'tasks_analysis_blocks_count': 'Вазифаҳои масдудшуда: {count}',
      'tasks_month_january': 'Январ',
      'tasks_month_february': 'Феврал',
      'tasks_month_march': 'Март',
      'tasks_month_april': 'Апрел',
      'tasks_month_may': 'Май',
      'tasks_month_june': 'Июн',
      'tasks_month_july': 'Июл',
      'tasks_month_august': 'Август',
      'tasks_month_september': 'Сентябр',
      'tasks_month_october': 'Октябр',
      'tasks_month_november': 'Ноябр',
      'tasks_month_december': 'Декабр',
      'tasks_month_date_january': 'январи',
      'tasks_month_date_february': 'феврали',
      'tasks_month_date_march': 'марти',
      'tasks_month_date_april': 'апрели',
      'tasks_month_date_may': 'майи',
      'tasks_month_date_june': 'июни',
      'tasks_month_date_july': 'июли',
      'tasks_month_date_august': 'августи',
      'tasks_month_date_september': 'сентябри',
      'tasks_month_date_october': 'октябри',
      'tasks_month_date_november': 'ноябри',
      'tasks_month_date_december': 'декабри',
      'tasks_month_short_january': 'янв.',
      'tasks_month_short_february': 'фев.',
      'tasks_month_short_march': 'мар.',
      'tasks_month_short_april': 'апр.',
      'tasks_month_short_may': 'май',
      'tasks_month_short_june': 'июн.',
      'tasks_month_short_july': 'июл.',
      'tasks_month_short_august': 'авг.',
      'tasks_month_short_september': 'сен.',
      'tasks_month_short_october': 'окт.',
      'tasks_month_short_november': 'ноя.',
      'tasks_month_short_december': 'дек.',
      'tasks_weekday_monday': 'Дш',
      'tasks_weekday_tuesday': 'Сш',
      'tasks_weekday_wednesday': 'Чш',
      'tasks_weekday_thursday': 'Пш',
      'tasks_weekday_friday': 'Ҷм',
      'tasks_weekday_saturday': 'Шб',
      'tasks_weekday_sunday': 'Яш',
      'cash_add_operation': 'Илова кардани амалиёт',
      'cash_tab_operations': 'Амалиётҳо',
      'cash_tab_registers': 'Дастгоҳҳои хазинавӣ',
      'cash_search_hint': 'Ҷустуҷӯ аз рӯйи қабулкунанда ё гурӯҳ...',
      'cash_filter_all': 'Ҳама',
      'cash_income': 'Воридот',
      'cash_expense': 'Хароҷот',
      'cash_operations_not_found': 'Амалиётҳо ёфт нашуданд',
      'cash_transaction_details': '{category} • {paymentMethod}',
      'cash_amount_tjs': '{amount} TJS',
      'cash_signed_amount_tjs': '{sign}{amount} TJS',
      'cash_cashier_system': 'Низом',
      'cash_shift_open': 'Басти хазина кушода аст',
      'cash_shift_closed': 'Басти хазина пӯшида аст',
      'cash_shift_open_details': 'Оғоз: {time} • Бақия: {balance} TJS',
      'cash_shift_operations_blocked':
          'Гузаронидани амалиётҳо муваққатан манъ аст',
      'cash_open_shift_title': 'Кушодани басти хазина',
      'cash_starting_balance_label': 'Бақияи ибтидоии хазина (TJS)',
      'cash_open_shift_action': 'Кушодани баст',
      'cash_close_shift_title': 'Пӯшидани басти хазина',
      'cash_close_shift_instruction':
          'Пеш аз пӯшидани баст, бақияи воқеии пули нақдро дар қуттии хазина аз нав ҳисоб кунед.',
      'cash_actual_balance_label': 'Бақияи воқеӣ дар хазина (TJS)',
      'cash_actual_balance_hint': 'Маблағи аз нав ҳисобшударо ворид кунед',
      'cash_close_shift_action': 'Пӯшидани баст',
      'cash_register_summary_empty': 'Хулосаи дастгоҳҳои хазинавӣ холӣ аст',
      'cash_shift_open_badge': 'БАСТ КУШОДА АСТ',
      'cash_shift_closed_badge': 'БАСТ ПӮШИДА АСТ',
      'cash_summary_income': 'Воридот:',
      'cash_summary_expense': 'Хароҷот:',
      'cash_summary_net_flow': 'Ҷараёни холис:',
      'cash_new_operation': 'Амалиёти нав',
      'cash_register': 'Хазина',
      'cash_amount_required': 'Маблағро ворид кунед',
      'cash_operation_amount': 'Маблағи амалиёт',
      'cash_payment_method': 'Тарзи пардохт',
      'cash_category': 'Гурӯҳ',
      'cash_select_category': 'Гурӯҳро интихоб кунед',
      'cash_counterparty_required': 'Номро ворид кунед',
      'cash_counterparty': 'Тарафи шартнома',
      'cash_counterparty_hint': 'Номи тарафи шартнома',
      'cash_description': 'Тавсиф',
      'cash_description_hint': 'Шарҳ ба амалиёт',
      'cash_select_category_required': 'Лутфан, гурӯҳро интихоб кунед',
      'cash_record': 'Сабт кардан',
      'cash_category_sales': 'Фурӯш',
      'cash_category_services': 'Хизматрасониҳо',
      'cash_category_advance': 'Пешпардохт',
      'cash_category_refund': 'Баргардонидан',
      'cash_category_other_income': 'Даромади дигар',
      'cash_category_rent': 'Иҷора',
      'cash_category_salary': 'Музди меҳнат',
      'cash_category_goods': 'Молҳо',
      'cash_category_utilities': 'Хизматрасониҳои коммуналӣ',
      'cash_category_marketing': 'Таблиғ',
      'cash_category_transport': 'Нақлиёт',
      'cash_category_taxes': 'Андозҳо',
      'cash_category_other_expense': 'Хароҷоти дигар',
      'cash_payment_cash': 'Нақдӣ',
      'cash_payment_card': 'Корт',
      'cash_payment_alif': 'Алиф',
      'cash_payment_dushanbe_city': 'Душанбе Сити',
      'cash_payment_ocms': 'ОСМС',
      'warehouse_add_product_title': 'Илова кардани моли нав',
      'warehouse_unit_pieces_short': 'дона',
      'warehouse_product_name': 'Номи мол',
      'warehouse_product_sku_label': 'SKU (рамзи мол)',
      'warehouse_unit_label': 'Воҳиди ченак',
      'warehouse_price_label': 'Нарх (TJS)',
      'warehouse_initial_stock': 'Бақияи ибтидоӣ',
      'warehouse_product_sku': 'SKU: {sku}',
      'warehouse_product_price': 'Нарх: {price} TJS',
      'warehouse_quantity_with_unit': '{quantity} {unit}',
      'warehouse_amount_tjs': '{amount} TJS',
      'warehouse_movement_income': 'Воридот',
      'warehouse_movement_expense': 'Баромад',
      'warehouse_movement_quantity': '{sign}{quantity} дона',
      'warehouse_movement_title': 'Ҳаракати мол',
      'warehouse_movement_purchase': 'Воридот (харид)',
      'warehouse_movement_sale': 'Баромад (фурӯш)',
      'warehouse_product': 'Мол',
      'warehouse_select_product': 'Молро интихоб кунед',
      'warehouse_product_with_stock': '{name} (бақия: {stock})',
      'warehouse_quantity_label': 'Миқдор',
      'warehouse_quantity_hint': 'Масалан: 10',
      'warehouse_optional_amount_label': 'Маблағ (ихтиёрӣ)',
      'warehouse_amount_hint': 'миқдор × нарх',
      'warehouse_note_label': 'Эзоҳ',
      'warehouse_note_hint': 'Шарҳ ба ҳаракат',
      'warehouse_record': 'Сабт кардан',
      'crm_retry': 'Аз нав кӯшиш кунед',
      'crm_ltv_orders': 'LTV: {amount} TJS (фармоишҳо: {count})',
      'crm_stage_lead': 'ЛИД',
      'crm_stage_proposal_status': 'ПЕШНИҲОД',
      'crm_stage_won': 'БОМУВАФФАҚИЯТ',
      'crm_stage_lost': 'БОХТ',
      'crm_stage_negotiation': 'МУЗОКИРОТ',
      'crm_client_value': 'Тарафи шартнома: {client}',
      'crm_churn_title': 'ХОРИҶШАВИИ МИЗОҶОН (CHURN)',
      'crm_churn_at_risk': 'Мизоҷони зери хавфи рафтан',
      'crm_reactivated': 'Мизоҷони бозфаъолшуда',
      'crm_new_client': 'Контрагенти нав',
      'crm_full_name_company': 'Ному насаб / Ширкат',
      'crm_phone': 'Телефон',
      'crm_email': 'Почтаи электронӣ',
      'crm_acquisition_cost': 'Арзиши ҷалб (CAC)',
      'crm_note': 'Эзоҳ',
      'crm_new_deal': 'Муомилаи нав',
      'crm_client_label': 'Мизоҷ',
      'crm_select_client': 'Мизоҷро интихоб кунед',
      'crm_no_client': 'Бе мизоҷ',
      'crm_deal_title': 'Номи муомила',
      'crm_deal_amount': 'Маблағи муомила (TJS)',
      'crm_funnel_stage': 'Марҳилаи фурӯш',
      'crm_stage_lead_label': 'Лид / Дархост',
      'crm_stage_proposal': 'Пешниҳоди тиҷоратӣ',
      'crm_stage_negotiation_label': 'Мувофиқа / Шартнома',
      'crm_stage_won_label': 'Муомила бомуваффақият анҷом ёфт',
      'crm_loyalty_gold': 'Тиллоӣ',
      'crm_loyalty_silver': 'Нуқрагӣ',
      'crm_loyalty_platinum': 'Платинагӣ',
      'crm_loyalty_bronze': 'Биринҷӣ',
      'dashboard_retry': 'Аз нав кӯшиш кунед',
      'dashboard_title': 'Панели молиявӣ',
      'dashboard_tab_overview': 'Шарҳи умумӣ',
      'dashboard_tab_pnl': 'Ҳисоботи P&L',
      'dashboard_tab_plan_fact': 'Нақша — Иҷро',
      'dashboard_tab_break_even': 'Безарарӣ',
      'dashboard_tab_abc': 'Таҳлили ABC',
      'dashboard_tab_accounts_rates': 'Ҳисобҳо ва асъорҳо',
      'dashboard_tab_ai_insights': 'Хулосаҳои ИИ',
      'dashboard_daily_recommendation_title': 'Тавсияи рӯз',
      'dashboard_daily_recommendation_content':
          'Бақияи озод дар давоми як ҳафта 8% афзуд. Тавсия дода мешавад, ки 15 000 TJS ба суратҳисоби пасандозӣ гузаронида шавад, то хавфҳои таваррум коҳиш ёбанд.',
      'dashboard_key_metrics_title': 'НИШОНДИҲАНДАҲОИ АСОСӢ',
      'dashboard_cash_flow_30_days_title': 'ҲАРАКАТИ МАБЛАҒ ДАР 30 РӮЗ',
      'dashboard_metric_cash_balance': 'Бақия дар хазинаҳо',
      'dashboard_metric_revenue_june': 'Даромад аз фурӯш (июн)',
      'dashboard_metric_expenses_june': 'Хароҷот (июн)',
      'dashboard_metric_net_profit': 'Фоидаи соф',
      'dashboard_metric_break_even': 'Нуқтаи безарарӣ',
      'dashboard_metric_normal': 'меъёр',
      'dashboard_metric_cash_forecast': 'Пешгӯии хазина',
      'dashboard_total': 'Ҳамагӣ',
      'dashboard_pnl_income_by_category': 'ДАРОМАДҲО АЗ РӮИ КАТЕГОРИЯҲО',
      'dashboard_pnl_expenses_by_category': 'ХАРОҶОТ АЗ РӮИ КАТЕГОРИЯҲО',
      'dashboard_pnl_net_profit': 'ФОИДАИ СОФ',
      'dashboard_budget_completion': 'ИҶРОИ УМУМИИ БУҶЕТ',
      'dashboard_category_comparison': 'МУҚОИСА АЗ РӮИ КАТЕГОРИЯҲО',
      'dashboard_plan': 'Нақша',
      'dashboard_fact': 'Иҷро',
      'dashboard_deviation': 'Фарқият',
      'dashboard_margin_of_safety': 'ЗАХИРАИ УСТУВОРИИ МОЛИЯВӢ',
      'dashboard_business_stable': 'Тиҷорат устувор аст',
      'dashboard_danger_zone': 'Минтақаи хатарнок',
      'dashboard_break_even_metrics': 'НИШОНДИҲАНДАҲОИ БЕЗАРАРӢ',
      'dashboard_current_revenue': 'Даромади ҷорӣ аз фурӯш',
      'dashboard_break_even_point': 'Нуқтаи безарарӣ',
      'dashboard_fixed_costs': 'Хароҷоти доимӣ',
      'dashboard_variable_costs': 'Хароҷоти тағйирёбанда',
      'dashboard_contribution_margin_ratio': 'Коэффитсиенти даромади маржиналӣ',
      'dashboard_abc_by_categories': 'Аз рӯи категорияҳо',
      'dashboard_abc_by_clients': 'Аз рӯи мизоҷон',
      'dashboard_abc_category_analysis':
          'ТАҲЛИЛИ КАТЕГОРИЯҲОИ МОЛ (ТАҲЛИЛИ ABC)',
      'dashboard_abc_client_analysis': 'ТАҲЛИЛИ КОНТРАГЕНТҲО (ТАҲЛИЛИ ABC)',
      'dashboard_no_analysis_data': 'Барои таҳлил маълумот нест',
      'dashboard_turnover_share':
          'Ҳисса дар гардиш: {share}% (ҷамъшуда: {cumulative}%)',
      'dashboard_bank_accounts': 'СУРАТҲИСОБҲОИ БОНКӢ',
      'dashboard_settlement_account': 'Суратҳисоби ҷорӣ',
      'dashboard_total_balance_tjs': 'БАҚИЯИ УМУМӢ (БО МУОДИЛИ TJS)',
      'dashboard_nbt_rates': 'ҚУРБҲОИ БОНКИ МИЛЛӢ (NBT)',
      'dashboard_cash_gap_risk': 'ХАВФИ КАМБУДИ МАБЛАҒ ДАР ХАЗИНА',
      'dashboard_days_to_cash_gap': 'То камбуди маблағ дар хазина: {days} рӯз',
      'dashboard_ai_recommendations_analysis': 'ТАВСИЯҲО ВА ТАҲЛИЛИ ИИ',
      'dashboard_cash_flow': 'Ҳаракати маблағ',
      'dashboard_cash_flow_subtitle':
          'Воридот ва хароҷот дар 30 рӯз ({period} • бо {currency})',
      'dashboard_income': 'Воридот',
      'dashboard_expense': 'Хароҷот',
      'dashboard_thousands_short': 'ҳаз.',
      'notifications_title': 'Маълумот ва огоҳиҳо',
      'notifications_retry': 'Аз нав кӯшиш кунед',
      'notifications_critical_audit': 'АУДИТИ ҶИДДӢ (ФАВРӢ)',
      'notifications_ai_recommendations': 'ТАВСИЯҲО ВА ПЕШГӮИҲОИ ИИ (МУҲИМ)',
      'notifications_legal_calendar':
          'ТАҚВИМИ АНДОЗ ВА ҲУҚУҚӢ (БАРОИ МАЪЛУМОТ)',
      'notifications_empty': 'Ягон вайронкунӣ ё тавсияи баррасинашудаи ИИ нест',
      'notifications_mark_read': 'Ҳамчун хондашуда қайд кардан',
      'users_title': 'Идоракунии дастрасӣ (SYS)',
      'users_search_hint': 'Ҷустуҷӯ аз рӯи номи корбар ё ном',
      'users_empty': 'Корбарон ёфт нашуданд',
      'users_login_value': 'Номи корбар: {value}',
      'users_email_value': 'Почтаи электронӣ: {value}',
      'users_phone_value': 'Телефон: {value}',
      'users_active': 'Фаъол',
      'users_blocked': 'Масдуд',
      'users_delete_title': 'Корбар нест карда шавад?',
      'users_delete_message':
          'Корбар дастрасӣ ба системаро аз даст медиҳад. Ин амал баргардонида намешавад.',
      'users_edit_title': 'Тағйир додани корбар',
      'users_new_title': 'Корбари нав',
      'users_full_name': 'Ному насаб',
      'users_login': 'Номи корбар',
      'users_email': 'Почтаи электронӣ',
      'users_phone': 'Телефон',
      'users_role': 'Нақш',
      'users_new_password': 'Рамзи нав (холӣ гузоред)',
      'users_password': 'Рамз',
      'users_security_access': 'БЕХАТАРӢ ВА ДАСТРАСӢ',
      'users_account_active': 'Ҳисоби корбар фаъол аст',
      'users_two_factor': 'Тасдиқи дуомила (2FA)',
      'users_two_factor_hint': 'Рамзи SMS ҳангоми воридшавӣ',
      'role_seller': 'Фурӯшанда',
      'integrations_title': 'Ҳамгироиҳои беруна (INT)',
      'integrations_connected_systems': 'СИСТЕМАҲОИ ПАЙВАСТШУДА',
      'integrations_status_active': 'Фаъол',
      'integrations_status_inactive': 'Ғайрифаъол',
      'integrations_sync': 'Ҳамоҳангсозӣ',
      'integrations_sync_logs': 'САБТҲОИ ҲАМОҲАНГСОЗӢ',
      'integrations_empty_logs': 'Сабтҳои ҳамоҳангсозӣ холӣ ҳастанд.',
      'integrations_success': 'Бомуваффақият',
      'integrations_error': 'Хато',
      'integrations_records_imported_one': 'Ворид карда шуд: {count} сабт',
      'integrations_records_imported_few': 'Ворид карда шуд: {count} сабт',
      'integrations_records_imported_many': 'Ворид карда шуд: {count} сабт',
      'legal_title': 'Бахши ҳуқуқии ҶТ',
      'legal_clear_history': 'Пок кардани таърих',
      'legal_loading_title': 'Пойгоҳи қонунҳо ва ҳуқуқшиноси ИИ',
      'legal_error_title': 'Хато',
      'legal_retry': 'Аз нав кӯшиш кардан',
      'legal_tab_ai_lawyer': 'Ҳуқуқшиноси ИИ',
      'legal_tab_laws': 'Қонунҳои ҶТ',
      'legal_tab_constructor': 'Шартномасоз',
      'legal_tab_deadlines': 'Муҳлатҳо',
      'legal_prompt_simplified_tax':
          'Меъёри андоз дар низоми содакардашудаи ҶТ',
      'legal_prompt_employment_contract':
          'Шартномаи меҳнатиро дар ҶТ чӣ гуна бояд тартиб дод?',
      'legal_prompt_social_tax_deadlines':
          'Муҳлати пардохти андози иҷтимоӣ барои кормандон',
      'legal_ai_thinking': 'Ҳуқуқшиноси ИИ посух омода мекунад...',
      'legal_question_hint': 'Ба ҳуқуқшинос савол диҳед...',
      'legal_category_all': 'Ҳама',
      'legal_category_taxes': 'Андозҳо',
      'legal_category_labor_law': 'Ҳуқуқи меҳнатӣ',
      'legal_category_corporate_law': 'Ҳуқуқи корпоративӣ',
      'legal_search_hint': 'Ҷустуҷӯ дар пойгоҳи қонунҳо...',
      'legal_nothing_found': 'Ҳеҷ чиз ёфт нашуд',
      'legal_default_law_category': 'Қонунгузорӣ',
      'legal_read_official_site': 'Дар сомонаи расмӣ хондан',
      'legal_document_generated': 'ҲУҶҶАТ ЭҶОД ШУД',
      'legal_date': 'Сана: {date}',
      'legal_contract_copied':
          'Матни шартнома ба ҳофизаи муваққатӣ нусхабардорӣ шуд',
      'legal_copy_text': 'Нусхабардории матн',
      'legal_create_new': 'Эҷоди нав',
      'legal_generating_document':
          'Ҳуҷҷат аз рӯи реквизитҳо эҷод шуда истодааст...',
      'legal_general_template': 'Шаблони умумӣ',
      'legal_fill_details': 'Пур кардани реквизитҳо',
      'legal_contract_details': 'Реквизитҳои шартнома',
      'legal_not_specified': '[{label} нишон дода нашудааст]',
      'legal_generate_contract': 'Эҷоди шартнома',
      'legal_deadline_summary':
          'Муҳлати супоридан: {date} ({days} рӯз боқӣ мондааст)',
      'marketing_title': 'Маркетинги ИИ ва шабакаҳои иҷтимоӣ',
      'marketing_tab_ai_writer': 'Матннависи ИИ',
      'marketing_tab_campaigns': 'Маъракаҳо',
      'marketing_tab_posts': 'Интишорот',
      'marketing_writer_description':
          'Бо ёрии ИИ шиорҳои ҷолиби фурӯшӣ, ғояҳои интишороти таблиғотӣ ё матни омода барои шабакаҳои иҷтимоии ширкат эҷод кунед.',
      'marketing_mode_ad_ideas': 'Ғояҳои таблиғотӣ',
      'marketing_mode_ready_post': 'Интишори омода',
      'marketing_post_prompt_hint':
          'Дар бораи тахфифи хишт матни таблиғотӣ навис...',
      'marketing_ideas_prompt_hint': 'Шиорҳо барои корхонаи семент...',
      'marketing_ai_thinking': 'ИИ фикр карда истодааст...',
      'marketing_create_content': 'Эҷоди муҳтаво',
      'marketing_generated_ideas': 'ҒОЯҲОИ ЭҶОДШУДА',
      'marketing_publication_text': 'МАТНИ ИНТИШОР',
      'marketing_copied': 'Ба ҳофизаи муваққатӣ нусхабардорӣ шуд',
      'marketing_post_saved_draft': 'Интишор ҳамчун сиёҳнавис нигоҳ дошта шуд',
      'marketing_no_campaigns': 'Маъракаҳои таблиғотӣ эҷод нашудаанд',
      'marketing_channel_none': 'Нишон дода нашудааст',
      'marketing_budget': 'Буҷет',
      'marketing_spent': 'Сарфшуда',
      'marketing_leads': 'Лидҳо',
      'marketing_sales': 'Фурӯш',
      'marketing_no_posts': 'Сиёҳнавис ё интишоре ёфт нашуд',
      'marketing_status_draft': 'Сиёҳнавис',
      'marketing_status_published': 'Нашршуда',
      'marketing_created_at': 'Эҷод шуд: {date}',
      'marketing_publish_telegram': 'Дар Telegram',
      'marketing_new_campaign': 'Маъракаи нави таблиғотӣ',
      'marketing_campaign_name': 'Номи маърака',
      'marketing_channel': 'Шабака',
      'marketing_budget_tjs': 'Буҷет (TJS)',
      'marketing_spent_tjs': 'Сарфшуда (TJS)',
      'marketing_leads_count': 'Шумораи лидҳо',
      'marketing_sales_count': 'Шумораи фурӯшҳо',
      'marketing_revenue_tjs': 'Даромади бадастомада (TJS)',
      'marketing_create': 'Эҷод кардан',
      'marketing_new_publication': 'Интишори нав',
      'marketing_publication_hint': 'Матни интишор...',
      'marketing_publication_channel': 'Шабакаи интишор',
      'marketing_save_draft': 'Ҳамчун сиёҳнавис нигоҳ доштан',
      'strategy_title': 'Стратегия ва маркетинги ИИ',
      'strategy_tab_whatif': 'Таҳлили What-if',
      'strategy_tab_marketing': 'Маркетологи ИИ',
      'strategy_tab_matrices': 'Матритсаҳо',
      'strategy_whatif_description':
          'Ба ИИ саволи молиявӣ диҳед, то таъсири тағйироти берунӣ ё дохилиро ба тавозуни ширкат арзёбӣ кунад.',
      'strategy_whatif_hint': 'Чӣ мешавад, агар фурӯш 10% кам шавад?',
      'strategy_whatif_template_revenue_drop':
          'Агар даромад 15% коҳиш ёбад, чӣ мешавад?',
      'strategy_whatif_template_purchase_costs':
          'Агар хароҷоти харид 10% зиёд шавад, чӣ мешавад?',
      'strategy_whatif_template_new_employee':
          'Агар корманди нав бо маоши 3000 TJS ба кор қабул шавад, чӣ мешавад?',
      'strategy_marketing_description':
          'Эҷоди ғояҳои пешбурд ва матнҳои интишорӣ барои шабакаҳои иҷтимоӣ бо ёрии шабакаи нейронии PAYK AI.',
      'strategy_marketing_hint': 'Ғояҳои таблиғи бетон дар Душанбе...',
      'strategy_marketing_template_concrete':
          'Ғояҳои пешбурди истеҳсоли бетон дар Хуҷанд',
      'strategy_marketing_template_self_checkout':
          'Шиорҳои эҷодӣ барои хазинаи худхизматрасонӣ',
      'strategy_marketing_template_wholesale_builders':
          'Роҳҳои ҷалби сохтмончиёни харидори яклухт дар Душанбе',
      'strategy_scenario_analysis': 'ТАҲЛИЛИ СЕНАРИЯ БО ИИ',
      'strategy_marketing_ideas': 'ҒОЯҲОИ ПЕШБУРД АЗ ИИ',
      'strategy_generate_ideas_action': 'Эҷоди ғояҳо',
      'strategy_analyzing_company': 'ИИ ширкатро таҳлил мекунад...',
      'strategy_generate_analysis': 'Эҷоди таҳлили ИИ барои ҶТ',
      'strategy_no_analysis':
          'Барои ин матритса таҳлили эҷодшуда вуҷуд надорад',
      'strategy_analysis_period': 'ТАҲЛИЛИ ИИ БАРОИ ДАВРА: {period}',
      'strategy_no_data': 'Маълумот нест',
      'strategy_swot_strengths': 'Ҷиҳатҳои қавӣ (Strengths)',
      'strategy_swot_weaknesses': 'Ҷиҳатҳои заиф (Weaknesses)',
      'strategy_swot_opportunities': 'Имкониятҳо (Opportunities)',
      'strategy_swot_threats': 'Хатарҳо (Threats)',
      'strategy_pestel_political': 'Омилҳои сиёсӣ',
      'strategy_pestel_economic': 'Омилҳои иқтисодӣ',
      'strategy_pestel_social': 'Омилҳои иҷтимоӣ',
      'strategy_pestel_technological': 'Омилҳои технологӣ',
      'strategy_pestel_environmental': 'Омилҳои экологӣ',
      'strategy_pestel_legal': 'Омилҳои ҳуқуқӣ',
      'strategy_factors_found_one': '{count} омил ёфт шуд',
      'strategy_factors_found_few': '{count} омил ёфт шуд',
      'strategy_factors_found_many': '{count} омил ёфт шуд',
      'strategy_data_unavailable': 'Маълумот дастрас нест',
      'strategy_bcg_star': 'Ситора',
      'strategy_bcg_cash_cow': 'Гови ширдеҳ',
      'strategy_bcg_question': 'Кӯдакони душвор',
      'strategy_bcg_dog': 'Саг',
      'strategy_bcg_no_categories': 'Дар таҳлили BCG категорияҳои молӣ нестанд',
      'strategy_bcg_market_metrics':
          'Ҳиссаи бозор: {share}% • Рушди бозор: {growth}%',
    },
  };

  static const _tajikMessageTranslations = {
    'Касса': 'Хазина',
    'Сотрудник': 'Корманд',
    'шт': 'дона',
    'Товар': 'Мол',
    'Договор': 'Шартнома',
    'Ответ от ИИ пуст.': 'Ҷавоби ИИ холӣ аст.',
    'Нет сгенерированного текста': 'Матни эҷодшуда нест',
    'Кассовый разрыв не прогнозируется. Финансовая устойчивость высокая.':
        'Камбудии маблағ дар хазина пешбинӣ намешавад. Устувории молиявӣ баланд аст.',
    '• Расходы на маркетинг окупаются: выручка выросла на 15.8% при росте затрат всего на 4.6%.\n• Запас финансовой прочности составляет 55.18% — это отличный показатель для розничного бизнеса.\n• Рекомендуется рассмотреть расширение товарной матрицы категории B (Сиропы и стаканчики) для перехода в категорию A.':
        '• Хароҷоти маркетинг худро ҷуброн мекунад: даромад 15.8% афзуд, дар ҳоле ки хароҷот ҳамагӣ 4.6% зиёд шуд.\n• Захираи устувории молиявӣ 55.18% аст — ин барои тиҷорати чакана нишондиҳандаи олӣ мебошад.\n• Барои гузаштан ба гурӯҳи A васеъ кардани номгӯи молҳои гурӯҳи B (шарбатҳо ва истаконҳо) тавсия дода мешавад.',
    'Рекомендаций нет.': 'Тавсияҳо нестанд.',
    'Подозрение на дробление платежей (AUD-02)':
        'Шубҳа ба тақсим кардани пардохтҳо (AUD-02)',
    'Обнаружена серия из 4 транзакций по 2 000 TJS поставщику «Согдиана» за последние 2 часа. Возможно, платеж разделен для обхода лимита согласования.':
        'Дар 2 соати охир силсилаи 4 амалиёти 2 000 TJS ба таъминкунандаи «Согдиана» ошкор шуд. Эҳтимол пардохт барои давр задани ҳадди мувофиқа тақсим шудааст.',
    'Кассир Салихов С. провел ручной возврат в кассе А в 02:45 ночи на сумму 1 200 TJS. Рекомендуется проверить видеокамеры.':
        'Хазинадор Салихов С. соати 02:45 шабона дар хазинаи А ба маблағи 1 200 TJS баргардонии дастӣ анҷом дод. Санҷидани камераҳо тавсия дода мешавад.',
    'С вероятностью 85% ожидается дефицит средств в размере 14 000 TJS через 7 дней в связи с задержкой оплаты по договору №14.':
        'Бо эҳтимоли 85% пас аз 7 рӯз бинобар таъхири пардохти шартномаи №14 камбудии 14 000 TJS пешбинӣ мешавад.',
    'Угроза оттока клиентов': 'Хавфи аз даст додани мизоҷон',
    'AI-модель прогнозирует высокую вероятность ухода клиента «Азиз-Торг» в течение 30 дней. Объем их закупок снизился на 25%.':
        'Модели ИИ эҳтимоли зиёди рафтани мизоҷи «Азиз-Торг»-ро дар 30 рӯзи оянда пешбинӣ мекунад. Ҳаҷми хариди онҳо 25% коҳиш ёфтааст.',
    'Ежедневные AI-рекомендации': 'Тавсияҳои ҳаррӯзаи ИИ',
    'Рекомендация №1: Загрузка склада Худжанд превышает 90% — рассмотрите распродажу остатков.\nРекомендация №2: Переведите 15 000 TJS на депозит для минимизации инфляции.\nРекомендация №3: Проверьте просроченную задачу по сверке транзитных счетов.':
        'Тавсияи №1: Сарбории анбори Хуҷанд аз 90% зиёд аст — фурӯши бақияҳоро баррасӣ кунед.\nТавсияи №2: Барои коҳиш додани таъсири таваррум 15 000 TJS-ро ба пасандоз гузаронед.\nТавсияи №3: Вазифаи муҳлатгузаштаи муқоисаи ҳисобҳои транзитиро санҷед.',
    'Налоговый календарь РТ': 'Тақвими андози ҶТ',
    'Приближается срок уплаты налога по упрощенной системе. Срок: до 15 Июля. Расчетная сумма: 18 450 TJS.':
        'Муҳлати пардохти андоз аз рӯи низоми содакардашуда наздик мешавад. Муҳлат: то 15 июл. Маблағи ҳисобшуда: 18 450 TJS.',
    'Окончание лицензии 1С': 'Анҷоми муҳлати иҷозатномаи 1С',
    'Внимание: срок действия корпоративной лицензии 1С:Бухгалтерия истекает через 14 дней (15 июля). Требуется продление.':
        'Диққат: муҳлати иҷозатномаи корпоративии 1С:Муҳосибот пас аз 14 рӯз (15 июл) ба анҷом мерасад. Тамдид лозим аст.',
    'Поставщик кофе «Алмосӣ»': 'Таъминкунандаи қаҳва «Алмосӣ»',
    'Закупка сырья': 'Хариди ашёи хом',
    'Розничная выручка: Касса А': 'Даромади чакана: Хазинаи А',
    'Выручка': 'Даромад',
    'Аренда склада Душанбе': 'Иҷораи анбори Душанбе',
    'Регулярный расход': 'Хароҷоти мунтазам',
    'Система': 'Низом',
    'Главная касса': 'Хазинаи асосӣ',
    'Касса №2': 'Хазинаи №2',
    'Все сошлось': 'Ҳама чиз мувофиқ аст',
    'Излишек 50 TJS': '50 TJS зиёдатӣ',
    'Закрыто с мобильного устройства': 'Аз дастгоҳи мобилӣ пӯшида шуд',
    'Операция': 'Амалиёт',
    'Создано с мобильного устройства': 'Аз дастгоҳи мобилӣ сохта шуд',
    'Розничная выручка': 'Даромади чакана',
    'Оптовые поставки': 'Таъминоти яклухт',
    'Аренда помещений': 'Иҷораи биноҳо',
    'Зарплаты и KPI': 'Маош ва KPI',
    'Маркетинг и реклама': 'Маркетинг ва таблиғ',
    'Кофейное зерно арабика': 'Донаи қаҳваи арабика',
    'Сиропы и топпинги': 'Шарбатҳо ва топпингҳо',
    'Одноразовые стаканчики': 'Истаконҳои яккарата',
    'Сахар и брендирование': 'Шакар ва брендсозӣ',
    'Расчетный сомоневый (Алиф Банк)': 'Ҳисоби сомонӣ (Алиф Бонк)',
    'Валютный USD (Ориёнбанк)': 'Ҳисоби асъории USD (Ориёнбонк)',
    'Новый клиент': 'Мизоҷи нав',
    'Без имени': 'Беном',
    'Неизвестный': 'Номаълум',
    'Нет ответа от AI': 'Ҷавоб аз ИИ нест',
    'Неверный логин или пароль': 'Номи корбар ё рамз нодуруст аст',
    'Вход для этой учётной записи запрещён':
        'Воридшавӣ барои ин ҳисоби корбар манъ аст',
    'Проверьте логин и пароль': 'Номи корбар ва рамзро санҷед',
    'Слишком много попыток входа. Повторите позже.':
        'Кӯшишҳои воридшавӣ хеле зиёданд. Баъдтар боз кӯшиш кунед.',
    'Сервис авторизации временно недоступен':
        'Хидмати воридшавӣ муваққатан дастнорас аст',
    'Не удалось выполнить вход. Повторите попытку.':
        'Воридшавӣ анҷом наёфт. Боз кӯшиш кунед.',
    'Биометрия недоступна на этом устройстве':
        'Биометрия дар ин дастгоҳ дастнорас аст',
    'Нет сохраненной сессии. Пожалуйста, сначала войдите по паролю.':
        'Сессияи ҳифзшуда нест. Лутфан, аввал бо рамз ворид шавед.',
    'Аутентификация по биометрии не пройдена': 'Тасдиқи биометрӣ анҷом наёфт',
    'Ошибка: кассовая смена закрыта. Сначала откройте смену.':
        'Хато: басти хазина пӯшида аст. Аввал бастро кушоед.',
    'Нет активной открытой смены для закрытия.':
        'Барои бастан басти фаъоли кушода нест.',
    'Товар не найден.': 'Мол ёфт нашуд.',
    'Ошибка: недостаточно товара на складе для списания.':
        'Хато: барои хориҷ кардан дар анбор моли кофӣ нест.',
    'Движение по товару успешно зафиксировано.':
        'Ҳаракати мол бомуваффақият сабт шуд.',
    'Пользователь успешно создан': 'Корбар бомуваффақият сохта шуд',
    'Данные пользователя сохранены': 'Маълумоти корбар нигоҳ дошта шуд',
    'Пользователь удален': 'Корбар нест карда шуд',
    'Импортировано 12 контрагентов и 8 счетов.':
        '12 контрагент ва 8 ҳисоб ворид карда шуд.',
    'Ошибка подключения: Неверный API-токен партнера.':
        'Хатои пайвастшавӣ: API-токени шарик нодуруст аст.',
    'Невозможно запустить синхронизацию: интеграция неактивна.':
        'Ҳамоҳангсозиро оғоз кардан имкон надорад: ҳамгироӣ ғайрифаъол аст.',
    'Успешно синхронизировано. Получено 4 новые записи.':
        'Ҳамоҳангсозӣ бомуваффақият анҷом ёфт. 4 сабти нав гирифта шуд.',
    'Синхронизация завершена успешно.': 'Ҳамоҳангсозӣ бомуваффақият анҷом ёфт.',
    'Салом! Я готов помочь вам с юридическими вопросами законодательства Республики Таджикистан. Например: "Какая ставка налога на прибыль по упрощенной системе?"':
        'Салом! Ман омодаам ба саволҳои ҳуқуқии шумо оид ба қонунгузории Ҷумҳурии Тоҷикистон ҷавоб диҳам. Масалан: "Меъёри андоз аз фоида дар низоми содакардашуда чанд аст?"',
    'Проведение операции в ночное время (AUD-05)':
        'Амалиёт дар вақти шаб (AUD-05)',
    'Срыв сроков задачи (TASK-04)': 'Гузаштани муҳлати вазифа (TASK-04)',
    'Прогноз кассового разрыва': 'Пешгӯии камбуди маблағ дар хазина',
    'ИИ-модель прогнозирует высокую вероятность дефицита средств через 7 дней. Рекомендуется пересмотреть приоритет платежей.':
        'Модели ИИ эҳтимоли баланди камбуди маблағро пас аз 7 рӯз пешгӯӣ мекунад. Аз нав баррасӣ кардани афзалияти пардохтҳо тавсия дода мешавад.',
    'Сервер отвечает слишком долго. Повторите попытку.':
        'Сервер хеле дер ҷавоб медиҳад. Боз кӯшиш кунед.',
    'Нет соединения с сервером. Проверьте интернет.':
        'Пайвастшавӣ ба сервер нест. Интернетро санҷед.',
    'Операция отменена.': 'Амалиёт бекор карда шуд.',
    'Не удалось установить защищённое соединение.':
        'Пайвастшавии муҳофизатшуда барқарор нашуд.',
    'Сессия истекла. Войдите в приложение снова.':
        'Муҳлати сессия анҷом ёфт. Боз ба барнома ворид шавед.',
    'Недостаточно прав для этой операции.': 'Барои ин амал ҳуқуқи кофӣ нест.',
    'Данные уже изменились. Обновите экран и повторите.':
        'Маълумот аллакай тағйир ёфтааст. Экранро нав карда, боз кӯшиш кунед.',
    'Проверьте введённые данные.': 'Маълумоти воридшударо санҷед.',
    'Слишком много запросов. Повторите немного позже.':
        'Дархостҳо хеле зиёданд. Каме баъдтар боз кӯшиш кунед.',
    'Сервис временно недоступен. Повторите позже.':
        'Хидмат муваққатан дастнорас аст. Баъдтар боз кӯшиш кунед.',
    'Не удалось выполнить биометрический вход. Войдите по паролю.':
        'Воридшавии биометрӣ анҷом наёфт. Бо рамз ворид шавед.',
    'Не удалось загрузить данные кассы. Проверьте соединение.':
        'Маълумоти хазина бор карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось добавить транзакцию. Повторите попытку.':
        'Транзаксия илова карда нашуд. Боз кӯшиш кунед.',
    'Не удалось открыть смену. Повторите попытку.':
        'Баст кушода нашуд. Боз кӯшиш кунед.',
    'Не удалось закрыть смену. Повторите попытку.':
        'Баст пӯшида нашуд. Боз кӯшиш кунед.',
    'Не удалось обновить склад. Проверьте соединение.':
        'Анбор нав карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось добавить товар. Проверьте данные и соединение.':
        'Мол илова карда нашуд. Маълумот ва пайвастшавиро санҷед.',
    'Не удалось провести операцию. Повторите попытку.':
        'Амалиёт анҷом дода нашуд. Боз кӯшиш кунед.',
    'Не удалось загрузить финансовые данные. Проверьте соединение.':
        'Маълумоти молиявӣ бор карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось загрузить раздел. Повторите попытку.':
        'Қисм бор карда нашуд. Боз кӯшиш кунед.',
    'Не удалось загрузить ABC-анализ. Повторите попытку.':
        'Таҳлили ABC бор карда нашуд. Боз кӯшиш кунед.',
    'Не удалось загрузить список задач. Проверьте соединение.':
        'Рӯйхати вазифаҳо бор карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось загрузить аналитику задач. Повторите попытку.':
        'Таҳлили вазифаҳо бор карда нашуд. Боз кӯшиш кунед.',
    'Не удалось создать задачу. Проверьте данные и соединение.':
        'Вазифа сохта нашуд. Маълумот ва пайвастшавиро санҷед.',
    'Не удалось выполнить AI-сценарий. Проверьте соединение.':
        'Сенарияи ИИ иҷро карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось получить AI-идеи. Проверьте соединение.':
        'Ғояҳои ИИ гирифта нашуданд. Пайвастшавиро санҷед.',
    'Не удалось загрузить стратегический анализ. Повторите попытку.':
        'Таҳлили стратегӣ бор карда нашуд. Боз кӯшиш кунед.',
    'Не удалось сгенерировать анализ. Проверьте соединение.':
        'Таҳлил эҷод карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось обновить CRM. Проверьте соединение и повторите.':
        'CRM нав карда нашуд. Пайвастшавиро санҷида, боз кӯшиш кунед.',
    'Не удалось загрузить CRM. Проверьте соединение и повторите.':
        'CRM бор карда нашуд. Пайвастшавиро санҷида, боз кӯшиш кунед.',
    'Не удалось добавить клиента. Проверьте данные и соединение.':
        'Мизоҷ илова карда нашуд. Маълумот ва пайвастшавиро санҷед.',
    'Не удалось открыть сделку. Проверьте данные и соединение.':
        'Муомила кушода нашуд. Маълумот ва пайвастшавиро санҷед.',
    'Не удалось обновить интеграции. Проверьте соединение.':
        'Ҳамгироиҳо нав карда нашуданд. Пайвастшавиро санҷед.',
    'Не удалось завершить синхронизацию. Повторите попытку.':
        'Ҳамоҳангсозӣ анҷом дода нашуд. Боз кӯшиш кунед.',
    'Не удалось обновить маркетинг. Проверьте соединение.':
        'Маркетинг нав карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось создать рекламную кампанию. Проверьте данные.':
        'Маъракаи таблиғотӣ сохта нашуд. Маълумотро санҷед.',
    'Не удалось создать публикацию. Проверьте данные.':
        'Интишор сохта нашуд. Маълумотро санҷед.',
    'Не удалось опубликовать пост. Повторите попытку.':
        'Интишор нашр карда нашуд. Боз кӯшиш кунед.',
    'Не удалось получить AI-идеи. Повторите попытку.':
        'Ғояҳои ИИ гирифта нашуданд. Боз кӯшиш кунед.',
    'Не удалось сгенерировать текст. Повторите попытку.':
        'Матн эҷод карда нашуд. Боз кӯшиш кунед.',
    'Не удалось загрузить пользователей. Проверьте соединение.':
        'Корбарон бор карда нашуданд. Пайвастшавиро санҷед.',
    'Не удалось создать пользователя. Проверьте данные.':
        'Корбар сохта нашуд. Маълумотро санҷед.',
    'Не удалось обновить пользователя. Проверьте данные.':
        'Корбар нав карда нашуд. Маълумотро санҷед.',
    'Не удалось удалить пользователя. Повторите попытку.':
        'Корбар нест карда нашуд. Боз кӯшиш кунед.',
    'Не удалось обновить данные HR. Проверьте соединение.':
        'Маълумоти кадрҳо нав карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось загрузить данные HR. Проверьте соединение.':
        'Маълумоти кадрҳо бор карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось добавить сотрудника. Проверьте данные.':
        'Корманд илова карда нашуд. Маълумотро санҷед.',
    'Не удалось выполнить перерасчёт. Проверьте данные.':
        'Азнавҳисобкунӣ анҷом дода нашуд. Маълумотро санҷед.',
    'Не удалось загрузить юридические данные. Проверьте соединение.':
        'Маълумоти ҳуқуқӣ бор карда нашуд. Пайвастшавиро санҷед.',
    'Не удалось обновить статус. Повторите попытку.':
        'Ҳолат нав карда нашуд. Боз кӯшиш кунед.',
    'Не удалось получить ответ ИИ. Повторите попытку.':
        'Ҷавоби ИИ гирифта нашуд. Боз кӯшиш кунед.',
    'Не удалось сгенерировать договор. Повторите попытку.':
        'Шартнома эҷод карда нашуд. Боз кӯшиш кунед.',
    'Не удалось загрузить уведомления. Проверьте соединение.':
        'Огоҳиномаҳо бор карда нашуданд. Пайвастшавиро санҷед.',
    'Не удалось отметить уведомление прочитанным. Повторите попытку.':
        'Огоҳинома ҳамчун хондашуда қайд нашуд. Боз кӯшиш кунед.',
    'Курс выбранной валюты недоступен. Повторите попытку.':
        'Қурби асъори интихобшуда дастнорас аст. Боз кӯшиш кунед.',
  };

  static const _tajikMessageReplacements = {
    'Касса #': 'Хазина #',
    'Кассир #': 'Хазинадор #',
    'Exception: ': '',
    'Ошибка авторизации: ': 'Хатои воридшавӣ: ',
    'Ошибка биометрии: ': 'Хатои биометрия: ',
    'Не удалось загрузить историю операций: ':
        'Таърихи амалиёт бор карда нашуд: ',
    'Не удалось добавить транзакцию: ': 'Транзаксия илова карда нашуд: ',
    'Не удалось проверить статус смены: ': 'Ҳолати баст санҷида нашуд: ',
    'Не удалось открыть смену: ': 'Баст кушода нашуд: ',
    'Не удалось закрыть смену: ': 'Баст пӯшида нашуд: ',
    'Не удалось загрузить сводку касс: ': 'Хулосаи хазинаҳо бор карда нашуд: ',
    'Не удалось загрузить историю смен: ': 'Таърихи бастҳо бор карда нашуд: ',
    'Не удалось загрузить список касс: ': 'Рӯйхати хазинаҳо бор карда нашуд: ',
    'Не удалось загрузить данные кассы: ': 'Маълумоти хазина бор карда нашуд: ',
    'Ошибка добавления транзакции: ': 'Хатои илова кардани транзаксия: ',
    'Смена успешно закрыта. ': 'Баст бомуваффақият пӯшида шуд. ',
    'Остаток сошелся (Разница: 0 TJS)': 'Бақия мувофиқ аст (Фарқият: 0 TJS)',
    'Внимание! Расхождение: ': 'Диққат! Фарқият: ',
    'Ожидалось в кассе: ': 'Дар хазина интизор буд: ',
    'Не удалось загрузить товары: ': 'Молҳо бор карда нашуданд: ',
    'Не удалось загрузить историю движений: ':
        'Таърихи ҳаракатҳо бор карда нашуд: ',
    'Не удалось получить сводку склада: ': 'Хулосаи анбор гирифта нашуд: ',
    'Не удалось создать товар: ': 'Мол сохта нашуд: ',
    'Не удалось зафиксировать движение: ': 'Ҳаракат сабт карда нашуд: ',
    'Ошибка загрузки данных склада: ': 'Хатои боркунии маълумоти анбор: ',
    'Не удалось добавить товар: ': 'Мол илова карда нашуд: ',
    'Не удалось провести операцию: ': 'Амалиёт анҷом дода нашуд: ',
    'Не удалось загрузить сотрудников: ': 'Кормандон бор карда нашуданд: ',
    'Не удалось загрузить предупреждения по KPI: ':
        'Огоҳиҳои KPI бор карда нашуданд: ',
    'Не удалось загрузить расчетную ведомость: ':
        'Варақаи ҳисобӣ бор карда нашуд: ',
    'Не удалось пересчитать зарплату: ': 'Маош аз нав ҳисоб карда нашуд: ',
    'Не удалось зарегистрировать сотрудника: ':
        'Корманд ба қайд гирифта нашуд: ',
    'Ошибка загрузки данных HR: ': 'Хатои боркунии маълумоти кадрҳо: ',
    'Не удалось добавить сотрудника: ': 'Корманд илова карда нашуд: ',
    'Не удалось выполнить перерасчет: ': 'Азнавҳисобкунӣ анҷом дода нашуд: ',
    'Не удалось загрузить рекламные кампании: ':
        'Маъракаҳои таблиғотӣ бор карда нашуданд: ',
    'Не удалось создать рекламную кампанию: ':
        'Маъракаи таблиғотӣ сохта нашуд: ',
    'Не удалось загрузить публикации: ': 'Интишорот бор карда нашуд: ',
    'Не удалось создать публикацию: ': 'Интишор сохта нашуд: ',
    'Не удалось опубликовать пост: ': 'Интишор нашр карда нашуд: ',
    'Не удалось сгенерировать идеи: ': 'Ғояҳо эҷод карда нашуданд: ',
    'Не удалось сгенерировать текст публикации: ':
        'Матни интишор эҷод карда нашуд: ',
    'Ошибка загрузки данных маркетинга: ':
        'Хатои боркунии маълумоти маркетинг: ',
    'Ошибка AI: ': 'Хатои ИИ: ',
    'Не удалось загрузить шаблоны договоров: ':
        'Қолабҳои шартнома бор карда нашуданд: ',
    'Не удалось сгенерировать договор: ': 'Шартнома эҷод карда нашуд: ',
    'Не удалось загрузить законы: ': 'Қонунҳо бор карда нашуданд: ',
    'Не удалось загрузить календарь сроков: ':
        'Тақвими муҳлатҳо бор карда нашуд: ',
    'Не удалось обновить статус срока: ': 'Ҳолати муҳлат нав карда нашуд: ',
    'Не удалось получить ответ ИИ: ': 'Ҷавоби ИИ гирифта нашуд: ',
    'Не удалось загрузить юридические данные: ':
        'Маълумоти ҳуқуқӣ бор карда нашуд: ',
    'Не удалось обновить статус: ': 'Ҳолат нав карда нашуд: ',
    'Произошла ошибка при получении ответа: ':
        'Ҳангоми гирифтани ҷавоб хато рух дод: ',
    'Не удалось загрузить финансовые данные: ':
        'Маълумоти молиявӣ бор карда нашуд: ',
    'Не удалось загрузить финансовые показатели: ':
        'Нишондиҳандаҳои молиявӣ бор карда нашуданд: ',
    'Не удалось загрузить историю движения денег: ':
        'Таърихи ҳаракати маблағ бор карда нашуд: ',
    'Не удалось загрузить P&L отчет: ': 'Ҳисоботи P&L бор карда нашуд: ',
    'Не удалось загрузить анализ безубыточности: ':
        'Таҳлили безарарӣ бор карда нашуд: ',
    'Не удалось загрузить ABC-анализ: ': 'Таҳлили ABC бор карда нашуд: ',
    'Не удалось загрузить список счетов: ': 'Рӯйхати ҳисобҳо бор карда нашуд: ',
    'Не удалось загрузить курсы валют: ': 'Қурби асъорҳо бор карда нашуд: ',
    'Не удалось загрузить ИИ инсайты: ': 'Хулосаҳои ИИ бор карда нашуданд: ',
    'Не удалось загрузить план-факт отчет: ':
        'Ҳисоботи нақша ва иҷро бор карда нашуд: ',
    'Ошибка загрузки CRM: ': 'Хатои боркунии CRM: ',
    'Не удалось загрузить клиентов: ': 'Мизоҷон бор карда нашуданд: ',
    'Не удалось загрузить сделки: ': 'Муомилаҳо бор карда нашуданд: ',
    'Не удалось получить статистику CRM: ': 'Омори CRM гирифта нашуд: ',
    'Не удалось добавить клиента: ': 'Мизоҷ илова карда нашуд: ',
    'Не удалось создать сделку: ': 'Муомила сохта нашуд: ',
    'Не удалось открыть сделку: ': 'Муомила кушода нашуд: ',
    'Не удалось загрузить пользователей: ': 'Корбарон бор карда нашуданд: ',
    'Не удалось создать пользователя: ': 'Корбар сохта нашуд: ',
    'Не удалось обновить пользователя: ': 'Корбар нав карда нашуд: ',
    'Не удалось удалить пользователя: ': 'Корбар нест карда нашуд: ',
    'Не удалось загрузить аудит: ': 'Аудит бор карда нашуд: ',
    'Не удалось обновить статус уведомления: ':
        'Ҳолати огоҳинома нав карда нашуд: ',
    'Не удалось загрузить уведомления: ': 'Огоҳиномаҳо бор карда нашуданд: ',
    'Ошибка отметки уведомления как прочитанного: ':
        'Хатои ҳамчун хондашуда қайд кардани огоҳинома: ',
    'Не удалось выполнить What-if симуляцию: ':
        'Симулятсияи What-if иҷро карда нашуд: ',
    'Не удалось загрузить стратегические матрицы: ':
        'Матритсаҳои стратегӣ бор карда нашуданд: ',
    'Не удалось сгенерировать стратегический анализ: ':
        'Таҳлили стратегӣ эҷод карда нашуд: ',
    'Ошибка загрузки анализа: ': 'Хатои боркунии таҳлил: ',
    'Ошибка AI генерации: ': 'Хатои эҷоди ИИ: ',
    'Не удалось загрузить список задач: ': 'Рӯйхати вазифаҳо бор карда нашуд: ',
    'Не удалось загрузить задачи: ': 'Вазифаҳо бор карда нашуданд: ',
    'Не удалось обновить статус задачи: ': 'Ҳолати вазифа нав карда нашуд: ',
    'Не удалось создать задачу: ': 'Вазифа сохта нашуд: ',
    'Не удалось обновить задачу: ': 'Вазифа нав карда нашуд: ',
    'Не удалось загрузить проекты: ': 'Лоиҳаҳо бор карда нашуданд: ',
    'Не удалось загрузить перегрузку сотрудников: ':
        'Маълумоти сарбории кормандон бор карда нашуд: ',
    'Не удалось загрузить критический путь: ': 'Роҳи муҳим бор карда нашуд: ',
    'Не удалось загрузить статус интеграций: ':
        'Ҳолати ҳамгироиҳо бор карда нашуд: ',
    'Не удалось загрузить логи синхронизации: ':
        'Сабтҳои ҳамоҳангсозӣ бор карда нашуданд: ',
    'Ошибка синхронизации: ': 'Хатои ҳамоҳангсозӣ: ',
    'Ошибка загрузки интеграций: ': 'Хатои боркунии ҳамгироиҳо: ',
    'Синхронизация завершилась ошибкой: ': 'Ҳамоҳангсозӣ бо хато анҷом ёфт: ',
  };

  static const _messageCacheLimit = 512;
  final Map<String, String> _tajikMessageCache = {};

  static final RegExp _auditTitlePattern = RegExp(r'^Аудит системы: (.+)$');
  static final RegExp _auditDescriptionPattern = RegExp(
    r'^Пользователь (.+) совершил действие "(.+)" для сущности "(.*)"\. IP-адрес устройства: (.+)\.$',
  );
  static final RegExp _nightOperationPattern = RegExp(
    r'^Кассир #(.+) провел операцию на сумму (.+) TJS в ночное время \((.+)\)\. Рекомендуется проверить видеокамеры\.$',
  );
  static final RegExp _overdueTaskPattern = RegExp(
    r'^Задача "(.+)" просрочена\. Дедлайн: (.+)\. Срочно завершите ее или перенесите сроки\.$',
  );
  static final RegExp _productCreatedPattern = RegExp(
    r'^Товар "(.+)" успешно добавлен\.$',
  );
  static final RegExp _clientCreatedPattern = RegExp(
    r'^Клиент "(.+)" успешно зарегистрирован\.$',
  );
  static final RegExp _dealCreatedPattern = RegExp(
    r'^Сделка "(.+)" успешно открыта\.$',
  );
  static final RegExp _employeeCreatedPattern = RegExp(
    r'^Сотрудник "(.+)" успешно принят на работу\.$',
  );
  static final RegExp _payrollUpdatedPattern = RegExp(
    r'^Расчет по сотруднику "(.+)" успешно обновлен\.$',
  );
  static final RegExp _tajikReplacementPattern = RegExp(
    (_tajikMessageReplacements.keys.toList()
          ..sort((left, right) => right.length.compareTo(left.length)))
        .map(RegExp.escape)
        .join('|'),
  );

  String translateMessage(String message) {
    if (state.languageCode != 'tg') {
      return message;
    }
    final cachedTranslation = _tajikMessageCache[message];
    if (cachedTranslation != null) {
      return cachedTranslation;
    }
    return _rememberTajikMessage(message, _translateMessageUncached(message));
  }

  String _translateMessageUncached(String message) {
    final exactTranslation = _tajikMessageTranslations[message];
    if (exactTranslation != null) {
      return exactTranslation;
    }

    final auditTitle = _auditTitlePattern.firstMatch(message);
    if (auditTitle != null) {
      return 'Аудити система: ${auditTitle[1]}';
    }

    final auditDescription = _auditDescriptionPattern.firstMatch(message);
    if (auditDescription != null) {
      return 'Корбар ${auditDescription[1]} амали "${auditDescription[2]}"-ро '
          'барои объекти "${auditDescription[3]}" анҷом дод. '
          'IP-суроғаи дастгоҳ: ${auditDescription[4]}.';
    }

    final nightOperation = _nightOperationPattern.firstMatch(message);
    if (nightOperation != null) {
      return 'Хазинадор #${nightOperation[1]} шабона (${nightOperation[3]}) '
          'ба маблағи ${nightOperation[2]} TJS амалиёт анҷом дод. '
          'Санҷидани камераҳо тавсия дода мешавад.';
    }

    final overdueTask = _overdueTaskPattern.firstMatch(message);
    if (overdueTask != null) {
      return 'Муҳлати вазифаи "${overdueTask[1]}" гузаштааст. '
          'Муҳлат: ${overdueTask[2]}. Онро фавран анҷом диҳед ё муҳлатро тағйир диҳед.';
    }

    final productCreated = _productCreatedPattern.firstMatch(message);
    if (productCreated != null) {
      return 'Моли "${productCreated[1]}" бомуваффақият илова шуд.';
    }

    final clientCreated = _clientCreatedPattern.firstMatch(message);
    if (clientCreated != null) {
      return 'Мизоҷи "${clientCreated[1]}" бомуваффақият ба қайд гирифта шуд.';
    }

    final dealCreated = _dealCreatedPattern.firstMatch(message);
    if (dealCreated != null) {
      return 'Муомилаи "${dealCreated[1]}" бомуваффақият кушода шуд.';
    }

    final employeeCreated = _employeeCreatedPattern.firstMatch(message);
    if (employeeCreated != null) {
      return 'Корманди "${employeeCreated[1]}" бомуваффақият ба кор қабул шуд.';
    }

    final payrollUpdated = _payrollUpdatedPattern.firstMatch(message);
    if (payrollUpdated != null) {
      return 'Ҳисоби корманди "${payrollUpdated[1]}" бомуваффақият нав шуд.';
    }

    final translated = message.replaceAllMapped(
      _tajikReplacementPattern,
      (match) => _tajikMessageReplacements[match.group(0)]!,
    );
    return translated;
  }

  String _rememberTajikMessage(String source, String translated) {
    if (_tajikMessageCache.length >= _messageCacheLimit &&
        !_tajikMessageCache.containsKey(source)) {
      _tajikMessageCache.remove(_tajikMessageCache.keys.first);
    }
    _tajikMessageCache[source] = translated;
    return translated;
  }

  String translate(String key, {Map<String, Object?> params = const {}}) {
    var value =
        _localizedValues[state.languageCode]?[key] ??
        _localizedValues['ru']?[key] ??
        key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  /// Selects a Russian-style one/few/many form and injects [count].
  ///
  /// Tajik catalog entries intentionally use the same noun form for all
  /// categories, while retaining symmetric keys with the Russian catalog.
  String translatePlural(
    String key,
    int count, {
    Map<String, Object?> params = const {},
  }) {
    final absoluteCount = count.abs();
    final mod10 = absoluteCount % 10;
    final mod100 = absoluteCount % 100;
    final category = mod10 == 1 && mod100 != 11
        ? 'one'
        : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
        ? 'few'
        : 'many';
    return translate(
      '${key}_$category',
      params: <String, Object?>{...params, 'count': count},
    );
  }

  static Set<String> get russianKeys =>
      Set.unmodifiable(_localizedValues['ru']!.keys);

  static Set<String> get tajikKeys =>
      Set.unmodifiable(_localizedValues['tg']!.keys);
}

/// Расширение для быстрого перевода в виджетах через `context.translate('key')`.
extension TranslationExtension on BuildContext {
  String translate(String key, {Map<String, Object?> params = const {}}) =>
      ReadContext(this).read<LanguageCubit>().translate(key, params: params);
}
