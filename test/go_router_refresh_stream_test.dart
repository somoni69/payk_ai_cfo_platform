import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/routing/go_router_refresh_stream.dart';

void main() {
  test('stops listening to the source stream when disposed', () async {
    var sourceCancelCount = 0;
    final controller = StreamController<int>(
      onCancel: () {
        sourceCancelCount++;
      },
    );
    final refresh = GoRouterRefreshStream(controller.stream);
    var notificationCount = 0;
    refresh.addListener(() {
      notificationCount++;
    });

    controller.add(1);
    await Future<void>.delayed(Duration.zero);

    expect(notificationCount, 1);

    refresh.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(sourceCancelCount, 1);

    controller.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(notificationCount, 1);
    await controller.close();
  });
}
