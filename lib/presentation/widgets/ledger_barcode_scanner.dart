import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';

/// Full-screen barcode/QR scanner. Pops the raw code, or null if cancelled.
class LedgerBarcodeScanner extends StatefulWidget {
  const LedgerBarcodeScanner({super.key});

  static Future<String?> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LedgerBarcodeScanner(),
      ),
    );
  }

  @override
  State<LedgerBarcodeScanner> createState() => _LedgerBarcodeScannerState();
}

class _LedgerBarcodeScannerState extends State<LedgerBarcodeScanner> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  var _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _handled = true;
    _controller.stop();
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.cameraBackdrop,
      appBar: AppBar(
        backgroundColor: colors.cameraBackdrop,
        foregroundColor: colors.onBrand,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('scan_barcode_title'),
          style: textStyles.bodySans.copyWith(
            color: colors.onBrand,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.camera_off,
                        size: 40,
                        color: colors.accentRed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        language.translate('scan_barcode_camera_denied'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.onBrand,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.brand, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              language.translate('scan_barcode_hint'),
              style: textStyles.captionSans.copyWith(
                color: colors.onBrand.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
