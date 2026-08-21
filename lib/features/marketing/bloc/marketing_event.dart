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
