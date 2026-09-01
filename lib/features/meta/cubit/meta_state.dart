import 'package:equatable/equatable.dart';
import '../domain/meta_models.dart';

class MetaState extends Equatable {
  final MetaStatus? status;
  final List<MetaThread> threads;
  final String selectedChannel;
  final MetaThread? selectedThread;
  final List<MetaMessage> messages;
  final bool isLoading;
  final bool isLoadingMessages;
  final bool isSending;
  final String? error;

  const MetaState({
    this.status,
    this.threads = const [],
    this.selectedChannel = '',
    this.selectedThread,
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMessages = false,
    this.isSending = false,
    this.error,
  });

  static const initial = MetaState();

  MetaState copyWith({
    MetaStatus? status,
    List<MetaThread>? threads,
    String? selectedChannel,
    MetaThread? selectedThread,
    bool clearSelectedThread = false,
    List<MetaMessage>? messages,
    bool? isLoading,
    bool? isLoadingMessages,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return MetaState(
      status: status ?? this.status,
      threads: threads ?? this.threads,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      selectedThread: clearSelectedThread
          ? null
          : (selectedThread ?? this.selectedThread),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    threads,
    selectedChannel,
    selectedThread,
    messages,
    isLoading,
    isLoadingMessages,
    isSending,
    error,
  ];
}
