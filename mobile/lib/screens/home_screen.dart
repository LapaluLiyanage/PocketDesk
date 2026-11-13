// SPDX-License-Identifier: GPL-3.0-or-later
// Paired computers. Tap one to connect; with a single computer the app
// connects by itself when it opens.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:url_launcher/url_launcher.dart';

import '../agent_connection.dart';
import '../files/share_inbox.dart';
import '../app_model.dart';
import '../pairing/laptop.dart';
import '../pairing/pairing_link.dart';
import '../ui/pocket_style.dart';
import '../update_check.dart';
import '../update_install.dart';
import 'control_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

/// iPhone only: Wi-Fi discovery silently fails if Local Network is off.
const _localNetworkTip =
    '\n• Local Network is on for PocketDesk (Settings → PocketDesk). iPhone needs it to find '
    'the computer on Wi-Fi; away from home, Tailscale or the relay work without it.';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.model, this.updates, this.installer});

  final AppModel model;

  /// New releases on GitHub (only in GitHub builds).
  final UpdateChecker? updates;

  /// Downloads and installs an update. Null in tests and on F-Droid builds.
  final UpdateInstaller? installer;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppModel get _model => widget.model;
  AgentConnection get _conn => _model.connection;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ShareInbox.instance.addListener(_onShared);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Opened from a pairing or "Get help" link.
      if (ShareInbox.instance.link != null) {
        _onShared();
        return;
      }
      if (!_model.autoConnectDone && _model.laptops.length == 1) {
        _model.autoConnectDone = true;
        _connect(_model.laptops.first);
      }
    });
  }

  @override
  void dispose() {
    ShareInbox.instance.removeListener(_onShared);
    super.dispose();
  }

  /// Something was shared with PocketDesk while no computer is open: with
  /// one computer, go straight to it (the control screen sends it).
  void _onShared() {
    if (!mounted) return;
    setState(() {});
    final route = ModalRoute.of(context);
    if (ShareInbox.instance.link != null && route != null && route.isCurrent && !_busy) {
      final link = ShareInbox.instance.takeLink();
      if (link != null) _pairWithLink(link);
      return;
    }
    if (ShareInbox.instance.pending != null &&
        route != null &&
        route.isCurrent &&
        !_busy &&
        _model.laptops.length == 1) {
      _connect(_model.laptops.first);
    }
  }

  // ---- Actions --------------------------------------------------------

  Future<void> _connect(Laptop laptop) async {
    if (_busy) return;
    final ok = await _withProgress(() => _model.connect(laptop), laptop: laptop);
    if (ok) await _openControl(laptop);
  }

  Future<void> _addComputer() async {
    if (_busy) return;
    final link = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (link == null || !mounted) return;
    await _pairWithLink(link);
  }

  /// A link someone sent (pairing, or "Get help"), pasted in.
  Future<void> _pasteLink() async {
    if (_busy) return;
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    final controller = TextEditingController(
      text: clip.startsWith('pocketdesk://') || clip.startsWith('https://pocketdesk.') ? clip : '',
    );
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A pairing or "Get help" link from PocketDesk on a computer.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: controller.text.isEmpty,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'https://pocketdesk.lapalu.me/p#…'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (link == null || link.isEmpty || !mounted) return;
    await _pairWithLink(link);
  }

  Future<void> _pairWithLink(String link) async {
    final PairingInfo info;
    try {
      info = parsePairingLink(link);
    } on PairingLinkException catch (e) {
      _showMessage('Can\'t use this link', e.message);
      return;
    }
    if (info.help) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.support_agent),
          title: Text('Help on ${info.name}?'),
          content: const Text(
            'Someone asked for your help. You\'ll see and control their computer for up to '
            '2 hours, or until either of you ends it. They see that you\'re connected.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Connect')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    Laptop? paired;
    final ok = await _withProgress(() async => paired = await _model.pair(info));
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          info.help
              ? 'Connected to ${paired!.name}.'
              : 'Paired with ${paired!.name}. It\'s saved on this phone.',
        ),
      ),
    );
    await _openControl(paired!);
  }

  Future<void> _openControl(Laptop laptop) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ControlScreen(connection: _conn, laptopKey: laptop.key, settings: _model.settings),
      ),
    );
    if (!mounted) return;
    final error = _conn.lastError;
    if (error == null) return;
    if (error.kind == FailureKind.notPaired && laptop.helping) {
      await _helpEnded(laptop);
    } else if (error.kind == FailureKind.notPaired) {
      await _explainFailure(error, laptop);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(label: 'Reconnect', onPressed: () => _connect(laptop)),
        ),
      );
    }
  }

  /// Runs [action] behind a progress dialog. Returns true on success.
  Future<bool> _withProgress(Future<void> Function() action, {Laptop? laptop}) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(connection: _conn),
    ).then((_) => dialogOpen = false);

    var ok = false;
    try {
      await action();
      ok = true;
    } on AgentException catch (e) {
      if (dialogOpen) navigator.pop();
      dialogOpen = false;
      if (mounted && e.kind != FailureKind.cancelled) {
        await _explainFailure(e, laptop);
      }
    } finally {
      if (dialogOpen) navigator.pop();
      if (mounted) setState(() => _busy = false);
    }
    return ok;
  }

  /// A help session's access ended on the computer: forget it here too.
  Future<void> _helpEnded(Laptop laptop) async {
    await _model.forget(laptop);
    if (!mounted) return;
    await _showMessage(
      'Help session ended',
      'Your access to ${laptop.name} ended. To help again, ask for a new "Get help" link.',
    );
  }

  Future<void> _explainFailure(AgentException e, Laptop? laptop) async {
    if (e.kind == FailureKind.notPaired && laptop != null && laptop.helping) return _helpEnded(laptop);
    final network = laptop?.reachableAnywhere == true
        ? '• the phone and the computer are on the same Wi-Fi, or, away from home, '
              'Tailscale is on, on both of them'
        : '• the phone and the computer are on the same Wi-Fi\n\n'
              'To connect when you\'re away from home, set up Tailscale: Settings → Connect from anywhere.';
    final (title, body) = switch (e.kind) {
      FailureKind.unreachable => (
        'Can\'t reach the computer',
        'Check that:\n'
            '• the computer is on and not asleep\n'
            '• PocketDesk is running on it (look for the tray icon)\n'
            '$network'
            '${Platform.isIOS ? _localNetworkTip : ''}',
      ),
      FailureKind.wrongComputer => (
        'Different computer',
        'Another device answered at this computer\'s address, so PocketDesk didn\'t connect. '
            'Make sure the computer is on this Wi-Fi, or that Tailscale is on.',
      ),
      FailureKind.notPaired => (
        'Pair again',
        'This computer no longer recognises this phone. It may have been removed in '
            'PocketDesk settings on the computer. Remove it here and scan a new code.',
      ),
      FailureKind.badToken => (
        'Code expired',
        'This pairing code was already used or has expired. Show a new code on the computer '
            'and scan it again.',
      ),
      FailureKind.version => ('Update needed', e.message),
      _ => ('Couldn\'t connect', e.message),
    };
    await _showMessage(
      title,
      body,
      forget: e.kind == FailureKind.notPaired ? laptop : null,
      settings: Platform.isIOS && e.kind == FailureKind.unreachable,
    );
  }

  Future<void> _showMessage(String title, String body, {Laptop? forget, bool settings = false}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          if (forget != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _model.forget(forget);
              },
              child: Text('Remove ${forget.name}'),
            ),
          if (settings)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await launchUrl(Uri.parse('app-settings:'));
                } catch (_) {}
              },
              child: const Text('Open Settings'),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _confirmForget(Laptop laptop) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${laptop.name}?'),
        content: const Text(
          'This phone will forget the computer. To use it again, scan a new pairing code. '
          'To also remove this phone from the computer, use PocketDesk settings there.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true) await _model.forget(laptop);
  }

  Future<void> _rename(Laptop laptop) async {
    final controller = TextEditingController(text: laptop.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(labelText: 'Name on this phone'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await _model.rename(laptop, name);
  }

  /// Lets the owner type an address PocketDesk hasn't seen, so a computer
  /// paired before Tailscale was set up isn't a dead end.
  Future<void> _addAddress(Laptop laptop) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add an address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An address this computer can be reached at. Its Remote access page shows them: '
              'the Tailscale one (100.x.x.x, or a name ending in .ts.net) works from anywhere '
              'with Tailscale on. A name of your own that points at your home connection works '
              'without it, if your router forwards the port \u2014 add ":port" if the router '
              'uses a different one.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 253,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Address', hintText: '100.101.102.103'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    final ok = await _model.addAddress(laptop, value);
    if (!mounted) return;
    if (!ok) {
      await _showMessage(
        'Not an address PocketDesk can use',
        'Type an IP address (like 192.168.1.5 or 100.101.102.103) or a name '
            '(like pc.tail1234.ts.net or home.example.org), and ":port" after it if '
            'the port is not the usual one.',
      );
    }
  }

  // ---- UI -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_model, ?widget.updates, ?widget.installer]),
      builder: (context, _) {
        final laptops = _model.laptops;
        final update = widget.updates?.available;
        final installer = widget.installer;
        final top = MediaQuery.viewPaddingOf(context).top;
        final bottom = MediaQuery.viewPaddingOf(context).bottom;
        final settings = _model.settings;
        final header = laptops.isEmpty ? 'PocketDesk · 3 steps' : 'PocketDesk · ${laptops.length}';
        final extras = <Widget>[
          if (update != null && installer != null)
            _UpdateCard(update: update, installer: installer, onDismiss: widget.updates!.dismiss),
          if (ShareInbox.instance.pending case final shared?)
            Card(
              child: ListTile(
                leading: const Icon(Icons.ios_share),
                title: Text(
                  shared.files.isEmpty
                      ? 'Text to send to a computer\'s clipboard'
                      : shared.files.length == 1
                      ? '${shared.files.single.name} to send'
                      : '${shared.files.length} files to send',
                ),
                subtitle: const Text('Choose a computer below.'),
                trailing: IconButton(
                  tooltip: 'Discard',
                  icon: const Icon(Icons.close),
                  onPressed: () => ShareInbox.instance.take(),
                ),
              ),
            ),
        ];
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: PocketBackground(
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  top: top + 100,
                  child: OutlineWordmark(laptops.isEmpty ? 'WELCOME' : 'COMPUTERS'),
                ),
                Positioned.fill(
                  child: laptops.isEmpty
                      ? _EmptyState(top: top + 112, extras: extras)
                      : ListView(
                          padding: EdgeInsets.fromLTRB(104, top + 106, 20, 190 + bottom),
                          children: [
                            ...extras.map(
                              (w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w),
                            ),
                            for (final l in laptops)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _LaptopTile(
                                  laptop: l,
                                  onTap: _busy ? null : () => _connect(l),
                                  onRename: () => _rename(l),
                                  onAddAddress: () => _addAddress(l),
                                  onForget: () => _confirmForget(l),
                                ),
                              ),
                          ],
                        ),
                ),
                Positioned(
                  top: top + 16,
                  left: 22,
                  child: PillHeader(label: laptops.isEmpty ? 'WELCOME' : 'MY COMPUTERS', title: header),
                ),
                if (settings != null)
                  Positioned(
                    top: top + 27,
                    right: 22,
                    child: RoundIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(settings: settings, updates: widget.updates),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 104,
                  bottom: 40 + bottom,
                  child: CapsAction(
                    icon: Icons.link,
                    label: 'PASTE A LINK',
                    tooltip: 'Paste a link',
                    onPressed: _busy ? null : _pasteLink,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CornerAction(
                    icon: Icons.qr_code_scanner,
                    label: 'SCAN',
                    tooltip: 'Scan pairing code',
                    onPressed: _busy ? null : _addComputer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UpdateCard extends StatefulWidget {
  const _UpdateCard({required this.update, required this.installer, required this.onDismiss});

  final AvailableUpdate update;
  final UpdateInstaller installer;
  final VoidCallback onDismiss;

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  Future<void> _update() async {
    final installer = widget.installer;
    if (!await installer.canInstall()) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Let PocketDesk install updates'),
          content: const Text(
            'Android asks for this once. On the next screen turn on "Allow from this source" '
            'for PocketDesk, then come back and press Update.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
          ],
        ),
      );
      if (go == true) await installer.requestPermission();
      return;
    }
    await installer.install(widget.update);
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final installer = widget.installer;
    final theme = Theme.of(context);
    final (title, detail) = switch (installer.stage) {
      UpdateStage.downloading => ('Downloading PocketDesk ${update.version}', null),
      UpdateStage.installing => ('Getting it ready\u2026', null),
      UpdateStage.waiting => (
        'Finish in Android',
        'Android is asking you to confirm. PocketDesk restarts once it is installed.',
      ),
      UpdateStage.failed => ('Update failed', installer.error),
      UpdateStage.idle => (
        'PocketDesk ${update.version} is available',
        'Press Update: PocketDesk downloads it and Android installs it over this version.',
      ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  installer.stage == UpdateStage.failed ? Icons.error_outline : Icons.system_update_outlined,
                  color: installer.stage == UpdateStage.failed ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            if (detail != null)
              Padding(padding: const EdgeInsets.only(left: 36, top: 4), child: Text(detail)),
            if (installer.stage == UpdateStage.downloading)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 12, right: 8),
                child: LinearProgressIndicator(value: installer.progress),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: switch (installer.stage) {
                UpdateStage.downloading || UpdateStage.installing => const <Widget>[],
                UpdateStage.waiting => [TextButton(onPressed: installer.reset, child: const Text('Close'))],
                UpdateStage.failed => [
                  TextButton(onPressed: installer.reset, child: const Text('Close')),
                  TextButton(
                    onPressed: () => launchUrl(update.notes, mode: LaunchMode.externalApplication),
                    child: const Text('Open GitHub'),
                  ),
                  FilledButton.tonal(onPressed: _update, child: const Text('Try again')),
                ],
                UpdateStage.idle => [
                  TextButton(onPressed: widget.onDismiss, child: const Text('Not now')),
                  TextButton(
                    onPressed: () => launchUrl(update.notes, mode: LaunchMode.externalApplication),
                    child: const Text('What\'s new'),
                  ),
                  FilledButton.tonal(onPressed: _update, child: const Text('Update')),
                ],
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LaptopTile extends StatelessWidget {
  const _LaptopTile({
    required this.laptop,
    required this.onTap,
    required this.onRename,
    required this.onAddAddress,
    required this.onForget,
  });

  final Laptop laptop;
  final VoidCallback? onTap;
  final VoidCallback onRename;
  final VoidCallback onAddAddress;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    final os = switch (laptop.os) {
      'windows' => 'Windows',
      'linux' => 'Linux',
      'macos' => 'macOS',
      _ => null,
    };
    final icon = laptop.helping
        ? Icons.support_agent
        : switch (laptop.os) {
            'macos' => Icons.laptop_mac,
            'windows' => Icons.window,
            'linux' => Icons.terminal,
            _ => Icons.computer,
          };
    final subtitle = laptop.helping
        ? 'Helping · temporary access'
        : switch ((os, laptop.reachableAnywhere)) {
            (null, true) => 'Here or away',
            (null, false) => 'Tap to connect',
            (final os?, true) => '$os · here or away',
            (final os?, false) => '$os · tap to connect',
          };
    return Dismissible(
      key: ValueKey(laptop.key),
      direction: DismissDirection.endToStart,
      // Swiping asks first; the row stays until the owner confirms.
      confirmDismiss: (_) async {
        onForget();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: c.accInk, size: 20),
            const SizedBox(height: 3),
            Text('REMOVE', style: TextStyle(fontSize: 9, letterSpacing: 2, color: c.accInk)),
          ],
        ),
      ),
      child: PocketCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              PocketBadge(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          laptop.helping ? 'HELPING' : 'PAIRED',
                          style: TextStyle(fontSize: 9, letterSpacing: 2.2, color: c.ink2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      laptop.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.ink2),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                iconColor: c.ink2,
                onSelected: (v) => switch (v) {
                  'rename' => onRename(),
                  'address' => onAddAddress(),
                  _ => onForget(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'address', child: Text('Add an address')),
                  PopupMenuItem(value: 'forget', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First launch: three steps, then scan.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.top, this.extras = const []});

  final double top;
  final List<Widget> extras;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    Widget step(String n, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PocketBadge(size: 34, child: Text(n)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
                ),
                const SizedBox(height: 3),
                Text(body, style: TextStyle(fontSize: 12.5, height: 1.4, color: c.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(104, top, 20, 190),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...extras.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
          Text(
            'Pair your computer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'You only do this once. After that, open the app and you\'re connected.',
            style: TextStyle(fontSize: 13, height: 1.45, color: c.ink2),
          ),
          const SizedBox(height: 26),
          step('1', 'Install PocketDesk on your computer', 'Mac or Windows. Open it and it shows a QR code.'),
          step('2', 'Scan it with this iPhone', 'Tap SCAN below. Once. No accounts, no passwords.'),
          step('3', 'Done', 'PocketDesk reconnects on its own — at home or away.'),
        ],
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.connection});

  final AgentConnection connection;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: ListenableBuilder(
          listenable: connection,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONNECTING', style: TextStyle(fontSize: 9.5, letterSpacing: 2.8, color: c.ink2)),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3, color: c.acc, backgroundColor: c.field),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(connection.progress ?? 'Connecting…', style: TextStyle(color: c.ink)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: connection.cancel, child: const Text('Cancel'))],
      ),
    );
  }
}
