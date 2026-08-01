import 'dart:async';

import 'package:equatable/equatable.dart';
import '../domain/crm_models.dart';

abstract class CrmEvent extends Equatable {
  const CrmEvent();

  @override
  List<Object?> get props => [];
}

class LoadCrmData extends CrmEvent {
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadCrmData({this.forceRefresh = false, this.completion});

  @override
  List<Object?> get props => [forceRefresh];
}

class ClientFiltersChanged extends CrmEvent {
  final String? query;
  final String? level;
  final int? page;

  const ClientFiltersChanged({this.query, this.level, this.page});

  @override
  List<Object?> get props => [query, level, page];
}

class CreateClientRequested extends CrmEvent {
  final CrmClient client;

  const CreateClientRequested(this.client);

  @override
  List<Object?> get props => [client];
}

class UpdateClientRequested extends CrmEvent {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final DateTime? birthDate;
  final double acquisitionCost;
  final String? note;

  const UpdateClientRequested({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.birthDate,
    required this.acquisitionCost,
    this.note,
  });

  @override
  List<Object?> get props =>
      [id, fullName, phone, email, birthDate, acquisitionCost, note];
}

class DeleteClientRequested extends CrmEvent {
  final String id;

  const DeleteClientRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class RegisterPurchaseRequested extends CrmEvent {
  final String clientId;
  final double amount;

  const RegisterPurchaseRequested({
    required this.clientId,
    required this.amount,
  });

  @override
  List<Object?> get props => [clientId, amount];
}

class CreateDealRequested extends CrmEvent {
  final String clientId;
  final String title;
  final double amount;
  final String stage;
  final DateTime? expectedClose;

  const CreateDealRequested({
    required this.clientId,
    required this.title,
    required this.amount,
    required this.stage,
    this.expectedClose,
  });

  @override
  List<Object?> get props => [clientId, title, amount, stage, expectedClose];
}

class UpdateDealRequested extends CrmEvent {
  final String id;
  final String title;
  final double amount;
  final String stage;
  final DateTime? expectedClose;

  const UpdateDealRequested({
    required this.id,
    required this.title,
    required this.amount,
    required this.stage,
    this.expectedClose,
  });

  @override
  List<Object?> get props => [id, title, amount, stage, expectedClose];
}

class DeleteDealRequested extends CrmEvent {
  final String id;

  const DeleteDealRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class AddLoyaltyPointsRequested extends CrmEvent {
  final String clientId;
  final double points;
  final String? reason;

  const AddLoyaltyPointsRequested({
    required this.clientId,
    required this.points,
    this.reason,
  });

  @override
  List<Object?> get props => [clientId, points, reason];
}

class SendReactivationRequested extends CrmEvent {
  final String clientId;
  final String text;

  const SendReactivationRequested({
    required this.clientId,
    required this.text,
  });

  @override
  List<Object?> get props => [clientId, text];
}

class AnalyzeChurnRequested extends CrmEvent {
  final String clientId;

  const AnalyzeChurnRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

class LoadClientDetailRequested extends CrmEvent {
  final String clientId;

  const LoadClientDetailRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

class ClearClientDetail extends CrmEvent {
  const ClearClientDetail();
}

class ClearCrmFeedback extends CrmEvent {
  const ClearCrmFeedback();
}
