import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/assistant/data/api_assistant_repository.dart';
import '../../features/assistant/domain/assistant_repository.dart';
import '../../features/audit/data/api_audit_repository.dart';
import '../../features/audit/domain/audit_repository.dart';
import '../../features/meta/data/api_meta_repository.dart';
import '../../features/meta/domain/meta_repository.dart';
import '../../features/network/data/api_network_repository.dart';
import '../../features/network/domain/network_repository.dart';
import '../../features/permissions/data/api_permissions_repository.dart';
import '../../features/permissions/domain/permissions_repository.dart';
import '../../features/branches/data/api_branches_repository.dart';
import '../../features/branches/domain/branches_repository.dart';
import '../../features/cash/data/api_cash_repository.dart';
import '../../features/cash/domain/cash_repository.dart';
import '../../features/checklists/data/api_checklists_repository.dart';
import '../../features/checklists/domain/checklists_repository.dart';
import '../../features/crm/data/api_crm_repository.dart';
import '../../features/crm/domain/crm_repository.dart';
import '../../features/dashboard/data/api_finance_repository.dart';
import '../../features/dashboard/domain/finance_repository.dart';
import '../../features/fin_ops/data/api_fin_ops_repository.dart';
import '../../features/fin_ops/domain/fin_ops_repository.dart';
import '../../features/hr/data/api_hr_repository.dart';
import '../../features/hr/domain/hr_repository.dart';
import '../../features/integrations/data/api_integrations_repository.dart';
import '../../features/integrations/domain/integrations_repository.dart';
import '../../features/legal/data/api_legal_repository.dart';
import '../../features/legal/domain/legal_repository.dart';
import '../../features/marketing/data/api_marketing_repository.dart';
import '../../features/marketing/domain/marketing_repository.dart';
import '../../features/notifications/data/api_notifications_repository.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../../features/reports/data/api_reports_repository.dart';
import '../../features/reports/domain/reports_repository.dart';
import '../../features/strategy/data/api_strategy_repository.dart';
import '../../features/strategy/domain/strategy_repository.dart';
import '../../features/tasks/data/api_tasks_repository.dart';
import '../../features/tasks/domain/tasks_repository.dart';
import '../../features/users/data/api_users_repository.dart';
import '../../features/users/domain/users_repository.dart';
import '../../features/warehouse/data/api_warehouse_repository.dart';
import '../../features/warehouse/domain/warehouse_repository.dart';

/// Composition root for feature repositories.
///
/// Keeps [MyApp] lean and makes test overrides a single-list swap.
abstract final class AppRepositories {
  static List<RepositoryProvider<dynamic>> providers() => [
    RepositoryProvider<FinanceRepository>(
      create: (_) => ApiFinanceRepository(),
    ),
    RepositoryProvider<CashRepository>(create: (_) => ApiCashRepository()),
    RepositoryProvider<TasksRepository>(create: (_) => ApiTasksRepository()),
    RepositoryProvider<NotificationsRepository>(
      create: (_) => ApiNotificationsRepository(),
    ),
    RepositoryProvider<WarehouseRepository>(
      create: (_) => ApiWarehouseRepository(),
    ),
    RepositoryProvider<HrRepository>(create: (_) => ApiHrRepository()),
    RepositoryProvider<CrmRepository>(create: (_) => ApiCrmRepository()),
    RepositoryProvider<StrategyRepository>(
      create: (_) => ApiStrategyRepository(),
    ),
    RepositoryProvider<LegalRepository>(create: (_) => ApiLegalRepository()),
    RepositoryProvider<MarketingRepository>(
      create: (_) => ApiMarketingRepository(),
    ),
    RepositoryProvider<IntegrationsRepository>(
      create: (_) => ApiIntegrationsRepository(),
    ),
    RepositoryProvider<UsersRepository>(create: (_) => ApiUsersRepository()),
    RepositoryProvider<BranchesRepository>(
      create: (_) => ApiBranchesRepository(),
    ),
    RepositoryProvider<ChecklistsRepository>(
      create: (_) => ApiChecklistsRepository(),
    ),
    RepositoryProvider<FinOpsRepository>(create: (_) => ApiFinOpsRepository()),
    RepositoryProvider<ReportsRepository>(
      create: (_) => ApiReportsRepository(),
    ),
    RepositoryProvider<AuditRepository>(create: (_) => ApiAuditRepository()),
    RepositoryProvider<AssistantRepository>(
      create: (_) => ApiAssistantRepository(),
    ),
    RepositoryProvider<MetaRepository>(create: (_) => ApiMetaRepository()),
    RepositoryProvider<NetworkRepository>(
      create: (_) => ApiNetworkRepository(),
    ),
    RepositoryProvider<PermissionsRepository>(
      create: (_) => ApiPermissionsRepository(),
    ),
  ];

  /// Wraps [child] with the production repository graph.
  static Widget multiProvider({required Widget child}) {
    return MultiRepositoryProvider(providers: providers(), child: child);
  }
}
