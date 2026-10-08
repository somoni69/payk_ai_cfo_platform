import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../bloc/network_bloc.dart';
import '../bloc/network_event.dart';
import '../bloc/network_state.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';

StoreChannel? _channelOf(
  List<StoreChannel> channels,
  String kind, {
  bool connectedOnly = false,
}) {
  for (final channel in channels) {
    if (channel.kind != kind) continue;
    if (connectedOnly && !channel.connected) continue;
    return channel;
  }
  return null;
}

Future<void> showStoreChannelsSheet(BuildContext context, NetworkStore store) {
  final language = context.read<LanguageCubit>();
  return LedgerBottomSheet.show<void>(
    context: context,
    title: language.translate('channels_title', params: {'store': store.name}),
    builder: (sheetContext, _) => _ChannelsBody(storeId: store.id),
  );
}

class _ChannelsBody extends StatefulWidget {
  const _ChannelsBody({required this.storeId});

  final int storeId;

  @override
  State<_ChannelsBody> createState() => _ChannelsBodyState();
}

class _ChannelsBodyState extends State<_ChannelsBody> {
  var _loading = true;
  String? _error;
  StoreChannels? _data;
  UmnicoState? _umnico;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<NetworkRepository>();
      final data = await repo.fetchStoreChannels(widget.storeId);
      UmnicoState? umnico;
      try {
        umnico = await repo.fetchUmnico();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = data;
        _umnico = umnico;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error);
      });
    }
  }

  Future<void> _refreshUmnico() async {
    try {
      final umnico = await context.read<NetworkRepository>().fetchUmnico();
      if (!mounted) return;
      setState(() => _umnico = umnico);
    } catch (_) {}
  }

  void _apply(StoreChannels next) {
    setState(() => _data = next);
    unawaited(_refreshUmnico());
    final bloc = context.read<NetworkBloc>();
    final period = bloc.state is NetworkLoaded
        ? (bloc.state as NetworkLoaded).period
        : NetworkPeriod.month;
    bloc.add(LoadNetworkData(period: period, forceRefresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(language.resolveMessage(_error ?? 'error_load_failed')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
            child: Text(language.translate('common_retry')),
          ),
        ],
      );
    }
    final data = _data!;
    final facebook = _channelOf(data.channels, 'facebook', connectedOnly: true);
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          language.translate('channels_intro'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        if (!data.hasChats) ...[
          const SizedBox(height: 12),
          _Notice(text: language.translate('channels_no_chats'), warn: false),
        ],
        if (!data.serverReady) ...[
          const SizedBox(height: 12),
          _Notice(
            text: language.translate('channels_server_not_ready'),
            warn: true,
          ),
        ],
        for (final channel in data.channels) ...[
          const SizedBox(height: 12),
          _ChannelCard(
            storeId: data.storeId,
            channel: channel,
            facebookPage: facebook?.name,
            umnico: _umnico,
            onChanged: _apply,
          ),
        ],
        const SizedBox(height: 16),
        _UmnicoBlock(
          state: _umnico,
          onChanged: (next) {
            setState(() => _umnico = next);
            unawaited(_load());
          },
        ),
        const SizedBox(height: 16),
        Text(
          language.translate('channels_webhook_title'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(data.webhookUrl, style: textStyles.captionSans),
            ),
            IconButton(
              tooltip: language.translate('channels_copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data.webhookUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(language.translate('channels_copied')),
                  ),
                );
              },
              icon: const Icon(TablerIcons.copy, size: 18),
            ),
          ],
        ),
        Text(
          language.translate('channels_webhook_hint'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.warn});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = warn ? colors.accentRed : colors.brand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: context.textStyles.captionSans.copyWith(color: tone),
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({
    required this.storeId,
    required this.channel,
    required this.facebookPage,
    required this.umnico,
    required this.onChanged,
  });

  final int storeId;
  final StoreChannel channel;
  final String? facebookPage;
  final UmnicoState? umnico;
  final ValueChanged<StoreChannels> onChanged;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  final _token = TextEditingController();
  final _phoneId = TextEditingController();
  final _businessId = TextEditingController();
  var _editing = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _phoneId.dispose();
    _businessId.dispose();
    super.dispose();
  }

  String _kindTitle(LanguageCubit language) {
    return language.translate('channels_kind_${widget.channel.kind}');
  }

  Future<void> _connect({required bool viaFacebook}) async {
    final language = context.read<LanguageCubit>();
    final kind = widget.channel.kind;
    if (kind == 'whatsapp' && _phoneId.text.trim().isEmpty) {
      setState(() => _error = language.translate('channels_err_phone'));
      return;
    }
    if (!viaFacebook && _token.text.trim().isEmpty) {
      setState(() => _error = language.translate('channels_err_token'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = context.read<NetworkRepository>();
      final next = switch (kind) {
        'facebook' => await repo.connectFacebookChannel(
          widget.storeId,
          _token.text,
        ),
        'instagram' => await repo.connectInstagramChannel(
          widget.storeId,
          token: viaFacebook ? null : _token.text,
        ),
        _ => await repo.connectWhatsAppChannel(
          widget.storeId,
          phoneId: _phoneId.text,
          token: _token.text,
          businessId: _businessId.text,
        ),
      };
      if (!mounted) return;
      final fresh = _channelOf(next.channels, kind);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.translate(
              fresh?.error != null
                  ? 'channels_connected_warn'
                  : 'channels_toast_connected',
            ),
          ),
        ),
      );
      _token.clear();
      setState(() {
        _busy = false;
        _editing = false;
      });
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = language.resolveMessage(userFacingError(error));
      });
    }
  }

  Future<void> _check() async {
    final language = context.read<LanguageCubit>();
    setState(() => _busy = true);
    try {
      final next = await context.read<NetworkRepository>().checkStoreChannel(
        widget.storeId,
        widget.channel.kind,
      );
      if (!mounted) return;
      final fresh = _channelOf(next.channels, widget.channel.kind);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.translate(
              fresh?.error != null
                  ? 'channels_checked_bad'
                  : 'channels_checked_ok',
            ),
          ),
        ),
      );
      setState(() => _busy = false);
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.resolveMessage(userFacingError(error))),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final language = context.read<LanguageCubit>();
    final title = _kindTitle(language);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language.translate(
            'channels_confirm_title',
            params: {'channel': title},
          ),
        ),
        content: Text(language.translate('channels_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('channels_disconnect')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final next = await context
          .read<NetworkRepository>()
          .disconnectStoreChannel(widget.storeId, widget.channel.kind);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('channels_disconnected'))),
      );
      setState(() {
        _busy = false;
        _editing = false;
      });
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.resolveMessage(userFacingError(error))),
        ),
      );
    }
  }

  Widget _umnicoButton(
    BuildContext context,
    LanguageCubit language,
    UmnicoIntegration item,
  ) {
    final taken = item.storeId != null && item.storeId != widget.storeId;
    final takenLabel = language.translate(
      'channels_umnico_taken',
      params: {'store': item.storeName ?? ''},
    );
    final title = language.translate(
      'channels_umnico_use',
      params: {'login': item.login.isEmpty ? item.id : item.login},
    );
    return OutlinedButton(
      onPressed: taken || _busy ? null : () => _useUmnico(language, item),
      child: Text(taken ? '$title — $takenLabel' : title),
    );
  }

  Future<void> _useUmnico(
    LanguageCubit language,
    UmnicoIntegration item,
  ) async {
    final channel = widget.channel;
    if (channel.connected && channel.via != 'umnico') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            language.translate(
              'channels_umnico_switch_title',
              params: {'channel': _kindTitle(language)},
            ),
          ),
          content: Text(language.translate('channels_umnico_switch_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(language.translate('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(language.translate('channels_umnico_via')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final next = await context
          .read<NetworkRepository>()
          .connectChannelViaUmnico(widget.storeId, channel.kind, item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.translate('channels_umnico_toast_switched')),
        ),
      );
      setState(() {
        _busy = false;
        _editing = false;
      });
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.resolveMessage(userFacingError(error))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final channel = widget.channel;
    final viaUmnico = channel.via == 'umnico';
    final showForm = (!channel.connected || _editing) && !viaUmnico;
    final umnicoOptions = widget.umnico?.connected == true
        ? widget.umnico!.integrations
              .where((item) => item.kind == channel.kind)
              .toList()
        : const <UmnicoIntegration>[];
    final tone = !channel.connected
        ? colors.textSecondary
        : (channel.error != null ? colors.accentRed : colors.accentGreen);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _kindTitle(language),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                language.translate(
                  channel.connected
                      ? 'channels_connected'
                      : 'channels_not_connected',
                ),
                style: textStyles.captionSans.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (channel.connected) ...[
            if (channel.name != null && channel.name!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(channel.name!, style: textStyles.bodySans),
            ],
            if (viaUmnico) ...[
              const SizedBox(height: 4),
              Text(
                language.translate('channels_umnico_via'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ] else if (channel.kind == 'instagram') ...[
              const SizedBox(height: 4),
              Text(
                channel.via == 'instagram'
                    ? language.translate('channels_via_token')
                    : language.translate(
                        'channels_via_page',
                        params: {'page': channel.pageName ?? ''},
                      ),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              channel.lastInboundAt == null
                  ? language.translate('channels_no_inbound')
                  : language.translate(
                      'channels_last_inbound',
                      params: {
                        'when': formatLocalizedDateTime(
                          context,
                          channel.lastInboundAt!,
                          style: LocalizedDateTimeStyle.dateTime,
                        ),
                      },
                    ),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (channel.tokenExpiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                language.translate(
                  'channels_token_expires',
                  params: {
                    'when': formatLocalizedDateTime(
                      context,
                      channel.tokenExpiresAt!,
                      style: LocalizedDateTimeStyle.date,
                    ),
                  },
                ),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (channel.kind == 'whatsapp' &&
                channel.subscribed == null &&
                channel.error == null) ...[
              const SizedBox(height: 4),
              Text(
                language.translate('channels_subscription_unknown'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (channel.error != null) ...[
              const SizedBox(height: 8),
              Text(
                channel.error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
          ],
          if (umnicoOptions.isNotEmpty && !viaUmnico) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in umnicoOptions)
                  _umnicoButton(context, language, item),
              ],
            ),
          ],
          if (showForm) ...[
            const SizedBox(height: 12),
            if (channel.kind == 'instagram' && widget.facebookPage != null) ...[
              OutlinedButton(
                onPressed: _busy ? null : () => _connect(viaFacebook: true),
                child: Text(language.translate('channels_ig_via_facebook')),
              ),
              const SizedBox(height: 4),
              Text(
                language.translate(
                  'channels_ig_via_facebook_hint',
                  params: {'page': widget.facebookPage!},
                ),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                language.translate('channels_or'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (channel.kind == 'whatsapp') ...[
              TextField(
                controller: _phoneId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: language.translate('channels_wa_phone'),
                  helperText: language.translate('channels_wa_phone_hint'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _token,
              obscureText: true,
              decoration: InputDecoration(
                labelText: language.translate(switch (channel.kind) {
                  'facebook' => 'channels_fb_token',
                  'instagram' => 'channels_ig_token',
                  _ => 'channels_wa_token',
                }),
                helperText: channel.kind == 'whatsapp'
                    ? null
                    : language.translate(
                        channel.kind == 'facebook'
                            ? 'channels_fb_hint'
                            : 'channels_ig_hint',
                      ),
              ),
            ),
            if (channel.kind == 'whatsapp') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _businessId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: language.translate('channels_wa_business'),
                  helperText: language.translate('channels_wa_business_hint'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : () => _connect(viaFacebook: false),
                  child: Text(language.translate('channels_connect')),
                ),
                if (_editing)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _editing = false),
                    child: Text(language.translate('common_cancel')),
                  ),
              ],
            ),
          ],
          if (channel.connected && !_editing) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  child: Text(language.translate('channels_check')),
                ),
                if (!viaUmnico)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            _phoneId.text = channel.accountId ?? '';
                            _businessId.text = channel.businessId ?? '';
                            _token.clear();
                            setState(() {
                              _editing = true;
                              _error = null;
                            });
                          },
                    child: Text(language.translate('channels_replace')),
                  ),
                TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: Text(
                    language.translate('channels_disconnect'),
                    style: TextStyle(color: colors.accentRed),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UmnicoBlock extends StatefulWidget {
  const _UmnicoBlock({required this.state, required this.onChanged});

  final UmnicoState? state;
  final ValueChanged<UmnicoState> onChanged;

  @override
  State<_UmnicoBlock> createState() => _UmnicoBlockState();
}

class _UmnicoBlockState extends State<_UmnicoBlock> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _relogin = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final language = context.read<LanguageCubit>();
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = language.translate('channels_umnico_err_login'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await context.read<NetworkRepository>().connectUmnico(
        login: _login.text,
        password: _password.text,
      );
      if (!mounted) return;
      _password.clear();
      setState(() {
        _busy = false;
        _relogin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.translate('channels_umnico_toast_connected')),
        ),
      );
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = language.resolveMessage(userFacingError(error));
      });
    }
  }

  Future<void> _disconnect() async {
    final language = context.read<LanguageCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('channels_umnico_disconnect_title')),
        content: Text(language.translate('channels_umnico_disconnect_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('channels_umnico_disconnect')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final next = await context.read<NetworkRepository>().disconnectUmnico();
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.translate('channels_umnico_toast_disconnected'),
          ),
        ),
      );
      widget.onChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.resolveMessage(userFacingError(error))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final state = widget.state;
    final connected = state?.connected == true && !_relogin;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.translate('channels_umnico_title'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            language.translate('channels_umnico_intro'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          if (connected && state != null) ...[
            const SizedBox(height: 8),
            Text(
              language.translate(
                'channels_umnico_connected_as',
                params: {'login': state.login ?? ''},
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.polledAt == null
                  ? language.translate('channels_umnico_polling_soon')
                  : language.translate(
                      'channels_umnico_polling',
                      params: {
                        'every': '${state.pollEverySeconds}',
                        'when': formatLocalizedDateTime(
                          context,
                          state.polledAt!,
                          style: LocalizedDateTimeStyle.dateTime,
                        ),
                      },
                    ),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              language.translate(
                state.webhookOk
                    ? 'channels_umnico_webhook_ok'
                    : 'channels_umnico_webhook_missing',
              ),
              style: textStyles.captionSans.copyWith(
                color: state.webhookOk
                    ? colors.textSecondary
                    : colors.accentRed,
              ),
            ),
            if (state.error != null && state.error!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            if (state.integrationsError != null &&
                state.integrationsError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.integrationsError!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _login.text = state.login ?? '';
                          _password.clear();
                          setState(() {
                            _relogin = true;
                            _error = null;
                          });
                        },
                  child: Text(language.translate('channels_umnico_relogin')),
                ),
                TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: Text(
                    language.translate('channels_umnico_disconnect'),
                    style: TextStyle(color: colors.accentRed),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            TextField(
              controller: _login,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: language.translate('channels_umnico_login'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: language.translate('channels_umnico_password'),
              ),
              onSubmitted: (_) => _connect(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _connect,
                  child: Text(language.translate('channels_umnico_connect')),
                ),
                if (_relogin)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _relogin = false),
                    child: Text(language.translate('common_cancel')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
