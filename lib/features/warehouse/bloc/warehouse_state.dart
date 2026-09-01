import 'package:equatable/equatable.dart';
import '../../../core/models/ui_feedback.dart';
import '../domain/warehouse_models.dart';

abstract class WarehouseState extends Equatable {
  const WarehouseState();

  @override
  List<Object?> get props => [];
}

class WarehouseLoading extends WarehouseState {}

class WarehouseLoaded extends WarehouseState {
  final List<WarehouseProduct> products;
  final List<WarehouseMovement> movements;
  final List<WarehouseBatch> batches;
  final bool batchesExpiringOnly;
  final WarehouseSummaryData summary;
  final WarehouseStockAnalysis? stockAnalysis;
  final bool isAnalysisLoading;
  final String? analysisError;
  final bool isPdfDownloading;
  final List<int>? pdfBytes;
  final UiFeedback? feedback;
  final String? errorMessage;
  final String? successMessage;

  const WarehouseLoaded({
    required this.products,
    required this.movements,
    this.batches = const [],
    this.batchesExpiringOnly = false,
    required this.summary,
    this.stockAnalysis,
    this.isAnalysisLoading = false,
    this.analysisError,
    this.isPdfDownloading = false,
    this.pdfBytes,
    this.feedback,
    this.errorMessage,
    this.successMessage,
  });

  WarehouseLoaded copyWith({
    List<WarehouseProduct>? products,
    List<WarehouseMovement>? movements,
    List<WarehouseBatch>? batches,
    bool? batchesExpiringOnly,
    WarehouseSummaryData? summary,
    WarehouseStockAnalysis? stockAnalysis,
    bool? isAnalysisLoading,
    String? analysisError,
    bool? isPdfDownloading,
    List<int>? pdfBytes,
    UiFeedback? feedback,
    bool clearFeedback = false,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearAnalysis = false,
    bool clearAnalysisError = false,
    bool clearPdf = false,
  }) {
    return WarehouseLoaded(
      products: products ?? this.products,
      movements: movements ?? this.movements,
      batches: batches ?? this.batches,
      batchesExpiringOnly: batchesExpiringOnly ?? this.batchesExpiringOnly,
      summary: summary ?? this.summary,
      stockAnalysis: clearAnalysis
          ? null
          : (stockAnalysis ?? this.stockAnalysis),
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      analysisError: clearAnalysisError
          ? null
          : (analysisError ?? this.analysisError),
      isPdfDownloading: isPdfDownloading ?? this.isPdfDownloading,
      pdfBytes: clearPdf ? null : (pdfBytes ?? this.pdfBytes),
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    products,
    movements,
    batches,
    batchesExpiringOnly,
    summary,
    stockAnalysis,
    isAnalysisLoading,
    analysisError,
    isPdfDownloading,
    pdfBytes,
    feedback,
    errorMessage,
    successMessage,
  ];
}

class WarehouseError extends WarehouseState {
  final String message;

  const WarehouseError(this.message);

  @override
  List<Object?> get props => [message];
}
