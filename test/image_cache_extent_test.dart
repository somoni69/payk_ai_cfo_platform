import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/presentation/widgets/image_cache_extent.dart';

void main() {
  test('decode width follows the device pixel ratio', () {
    expect(imageCacheWidth(3, 88), 264);
    expect(imageCacheWidth(2.75, 44), 121);
    expect(imageCacheWidth(1, 0), 1);
  });
}
