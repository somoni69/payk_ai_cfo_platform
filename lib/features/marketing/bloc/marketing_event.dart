import 'package:equatable/equatable.dart';
import '../domain/marketing_models.dart';

abstract class MarketingEvent extends Equatable {
  const MarketingEvent();

  @override
  List<Object?> get props => [];
}

class LoadMarketingData extends MarketingEvent {
  final bool forceRefresh;

  const LoadMarketingData({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class CreateCampaignRequested extends MarketingEvent {
  final String name;
  final String channel;
  final double budget;
  final double spent;
  final int leads;
  final int conversions;
  final double revenue;

  const CreateCampaignRequested({
    required this.name,
    required this.channel,
    required this.budget,
    required this.spent,
    required this.leads,
    required this.conversions,
    required this.revenue,
  });

  @override
  List<Object?> get props => [
    name,
    channel,
    budget,
    spent,
    leads,
    conversions,
    revenue,
  ];
}

class CreatePostRequested extends MarketingEvent {
  final String text;
  final String channel;

  const CreatePostRequested({required this.text, required this.channel});

  @override
  List<Object?> get props => [text, channel];
}

class PublishPostRequested extends MarketingEvent {
  final String id;

  const PublishPostRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteCampaignRequested extends MarketingEvent {
  final String id;

  const DeleteCampaignRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class DeletePostRequested extends MarketingEvent {
  final String id;

  const DeletePostRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class GenerateIdeasRequested extends MarketingEvent {
  final String prompt;

  const GenerateIdeasRequested(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

class GenerateTextRequested extends MarketingEvent {
  final String prompt;

  const GenerateTextRequested(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

class UpdateBrandGuideRequested extends MarketingEvent {
  final BrandGuide brandGuide;

  const UpdateBrandGuideRequested(this.brandGuide);

  @override
  List<Object?> get props => [brandGuide];
}

// Marketing AI Studio Events
class LoadAiStudioDataRequested extends MarketingEvent {
  final String lang;
  final bool forceRefresh;

  const LoadAiStudioDataRequested({
    this.lang = 'ru',
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [lang, forceRefresh];
}

class GenerateAiStudioIdeasRequested extends MarketingEvent {
  final String lang;

  const GenerateAiStudioIdeasRequested({this.lang = 'ru'});

  @override
  List<Object?> get props => [lang];
}

class CreateAiStudioCampaignRequested extends MarketingEvent {
  final String name;
  final String? product;
  final int? goalQty;
  final int? goalDays;
  final String? briefText;
  final String? ideaSource;

  const CreateAiStudioCampaignRequested({
    required this.name,
    this.product,
    this.goalQty,
    this.goalDays,
    this.briefText,
    this.ideaSource,
  });

  @override
  List<Object?> get props => [
    name,
    product,
    goalQty,
    goalDays,
    briefText,
    ideaSource,
  ];
}

class GenerateAiStudioConceptsRequested extends MarketingEvent {
  final String campaignId;

  const GenerateAiStudioConceptsRequested(this.campaignId);

  @override
  List<Object?> get props => [campaignId];
}

class ReviseAiStudioConceptRequested extends MarketingEvent {
  final String campaignId;
  final List<String> baseIds;
  final String note;

  const ReviseAiStudioConceptRequested({
    required this.campaignId,
    required this.baseIds,
    required this.note,
  });

  @override
  List<Object?> get props => [campaignId, baseIds, note];
}

class ApproveAiStudioConceptRequested extends MarketingEvent {
  final String conceptId;

  const ApproveAiStudioConceptRequested(this.conceptId);

  @override
  List<Object?> get props => [conceptId];
}

class GenerateAiStudioScriptRequested extends MarketingEvent {
  final String conceptId;

  const GenerateAiStudioScriptRequested(this.conceptId);

  @override
  List<Object?> get props => [conceptId];
}

class GenerateAiStudioMediaRequested extends MarketingEvent {
  final String mediaId;
  final String kind;
  final bool confirm;

  const GenerateAiStudioMediaRequested({
    required this.mediaId,
    required this.kind,
    this.confirm = true,
  });

  @override
  List<Object?> get props => [mediaId, kind, confirm];
}

class RejectAiStudioMediaRequested extends MarketingEvent {
  final String mediaId;
  final String reason;

  const RejectAiStudioMediaRequested({
    required this.mediaId,
    required this.reason,
  });

  @override
  List<Object?> get props => [mediaId, reason];
}

class LoadAiStudioReportRequested extends MarketingEvent {
  const LoadAiStudioReportRequested();
}
