import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/observability/app_error_reporter.dart';
import '../../../core/lifecycle/foreground_ticker.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/notifications_repository.dart';

/// Header bell — opens the full inbox screen.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  bool _countFailing = false;
  ForegroundTicker? _poll;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _poll = ForegroundTicker(const Duration(seconds: 30), () {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      _refreshCount();
    });
  }

  @override
  void dispose() {
    _poll?.dispose();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final count = await context
          .read<NotificationsRepository>()
          .getUnreadCount();
      if (!mounted || count == _unread) return;
      setState(() => _unread = count);
      _countFailing = false;
    } catch (e, st) {
      // The badge keeps its last value; report once per failure streak so a
      // phone offline for an hour does not send a report every 30 seconds.
      if (_countFailing) return;
      _countFailing = true;
      AppErrorReporter.reportOptional(e, st, context: 'notification_badge');
    }
  }

  Future<void> _openInbox() async {
    await context.push('/inbox');
    if (!mounted) return;
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: context.translate('inbox_title'),
      onPressed: _openInbox,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(TablerIcons.bell, color: colors.brand, size: 20),
          if (_unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accentRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: TextStyle(
                    color: colors.surface,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
