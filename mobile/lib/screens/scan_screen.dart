// SPDX-License-Identifier: GPL-3.0-or-later
// Scans the pairing QR code shown on the computer. Returns the link text.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/pocket_style.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final _qrKey = GlobalKey(debugLabel: 'pocketdesk-qr');
  QRViewController? _controller;
  StreamSubscription<Barcode>? _sub;
  bool _done = false;
  bool _warnedOtherCode = false;
  bool? _permission;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.resumeCamera();
  }

  void _onCreated(QRViewController controller) {
    _controller = controller;
    _sub = controller.scannedDataStream.listen((barcode) {
      final code = barcode.code;
      if (_done || code == null) return;
      if (code.startsWith('pocketdesk://')) {
        _finish(code);
      } else if (!_warnedOtherCode && mounted) {
        _warnedOtherCode = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That\'s not a PocketDesk code. Scan the code on your computer.')),
        );
      }
    });
  }

  void _finish(String link) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    _controller?.pauseCamera();
    Navigator.of(context).pop(link);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller?.toggleFlash();
      final on = await _controller?.getFlashStatus();
      if (mounted) setState(() => _torch = on ?? !_torch);
    } catch (_) {}
  }

  /// iPhone: this app's page in the Settings app.
  Future<void> _openSettings() async {
    try {
      await launchUrl(Uri.parse('app-settings:'));
    } catch (_) {}
  }

  Future<void> _pasteLink() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final controller = TextEditingController(
      text: (clip?.text ?? '').startsWith('pocketdesk://') ? clip!.text : '',
    );
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste pairing link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'pocketdesk://pair?…',
            helperText: 'Shown under the QR code when you run\npocketdesk --pair',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
    if (link != null && link.isNotEmpty) _finish(link);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.viewPaddingOf(context);
    final cutOut = (size.shortestSide * 0.66).clamp(200.0, 300.0);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onCreated,
            formatsAllowed: const [BarcodeFormat.qrcode],
            onPermissionSet: (_, granted) => setState(() => _permission = granted),
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              overlayColor: const Color(0x6B000000),
              borderRadius: 36,
              borderLength: 48,
              borderWidth: 4,
              cutOutSize: cutOut,
            ),
          ),
          Positioned(
            top: pad.top + 16,
            left: 22,
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(33),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAIR A COMPUTER',
                    style: TextStyle(fontSize: 9, letterSpacing: 2.9, color: Color(0x991A1A1A)),
                  ),
                  SizedBox(height: 4),
                  Text('Scan the code', style: TextStyle(fontSize: 19, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
          ),
          Positioned(
            top: pad.top + 27,
            right: 22,
            child: _glassButton(Icons.close, 'Close', () => Navigator.of(context).maybePop()),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: pad.bottom + 140,
            child: const Text(
              'On your computer, open PocketDesk and choose "Pair a phone".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xD9FFFFFF)),
            ),
          ),
          Positioned(
            left: 24,
            bottom: pad.bottom + 24,
            child: Tooltip(
              message: 'Paste link instead',
              child: Material(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _pasteLink,
                  child: const SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 18, color: Color(0xFF1A1A1A)),
                          SizedBox(width: 8),
                          Text(
                            'PASTE A LINK INSTEAD',
                            style: TextStyle(fontSize: 10, letterSpacing: 2.4, color: Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: pad.bottom + 24,
            child: _glassButton(
              _torch ? Icons.flashlight_on : Icons.flashlight_off,
              'Torch',
              _toggleTorch,
              size: 52,
            ),
          ),
          // Kept mounted underneath, so the camera can resume once allowed.
          if (_permission == false) Positioned.fill(child: _cameraOff(context, pad)),
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, String tooltip, VoidCallback onTap, {double size = 44}) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0x29FFFFFF),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    ),
  );

  /// The camera is off for PocketDesk: say so, and offer the other ways.
  Widget _cameraOff(BuildContext context, EdgeInsets pad) {
    final c = PocketColors.of(context);
    final ios = Platform.isIOS;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PocketBackground(
        child: Stack(
          children: [
            Positioned(left: 18, top: pad.top + 100, child: const OutlineWordmark('CAMERA')),
            Positioned(
              top: pad.top + 16,
              left: 22,
              child: const PillHeader(label: 'PAIR A COMPUTER', title: 'Camera is off'),
            ),
            Positioned(
              top: pad.top + 27,
              right: 22,
              child: RoundIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(110, pad.top + 150, 28, 190),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle, boxShadow: c.shadow),
                      child: Icon(Icons.no_photography_outlined, size: 28, color: c.accInk),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'PocketDesk can\'t use the camera',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, height: 1.2, color: c.ink),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'PocketDesk needs the camera to scan the code on your computer. '
                      'Allow camera access in the Settings app, or paste the link instead.',
                      style: TextStyle(fontSize: 14, height: 1.55, color: c.ink2),
                    ),
                    if (ios) ...[
                      const SizedBox(height: 18),
                      PocketCard(
                        onTap: _openSettings,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const PocketBadge(size: 36, child: Icon(Icons.photo_camera_outlined)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SETTINGS · POCKETDESK',
                                      style: TextStyle(fontSize: 9, letterSpacing: 2.2, color: c.ink2),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Camera',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 110,
              bottom: 40 + pad.bottom,
              child: CapsAction(
                icon: Icons.link,
                label: 'PASTE A LINK',
                tooltip: 'Paste link instead',
                onPressed: _pasteLink,
              ),
            ),
            if (ios)
              Positioned(
                right: 0,
                bottom: 0,
                child: CornerAction(
                  icon: Icons.open_in_new,
                  label: 'SETTINGS',
                  tooltip: 'Open Settings',
                  onPressed: _openSettings,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
