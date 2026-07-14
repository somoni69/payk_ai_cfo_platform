import 'package:equatable/equatable.dart';
import '../domain/crm_models.dart';

abstract class CrmEvent extends Equatable {
  const CrmEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузка данных клиентов, сделок и статистики
class LoadCrmData extends CrmEvent {}

/// Запрос на создание клиента
class CreateClientRequested extends CrmEvent {
  final CrmClient client;

  const CreateClientRequested(this.client);

  @override
  List<Object?> get props => [client];
}

/// Запрос на создание сделки
class CreateDealRequested extends CrmEvent {
  final String clientId;
  final String title;
  final double amount;
  final String stage; // 'lead', 'contact', 'proposal', 'negotiation', 'won', 'lost'

  const CreateDealRequested({
    required this.clientId,
    required this.title,
    required this.amount,
    required this.stage,
  });

  @override
  List<Object?> get props => [clientId, title, amount, stage];
}
