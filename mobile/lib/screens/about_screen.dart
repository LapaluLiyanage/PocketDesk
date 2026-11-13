// SPDX-License-Identifier: GPL-3.0-or-later
// About & credits: what PocketDesk is built from, and who made what.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/pocket_style.dart';

final _upstreamRepo = Uri.parse('https://github.com/sandunMadhushan/pairdesk');
final _pocketdeskRepo = Uri.parse('https://github.com/LapaluLiyanage/pocketdesk');
final _licence = Uri.parse('https://www.gnu.org/licenses/gpl-3.0.html');

Future<void> _open(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    final pad = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PocketBackground(
        child: Stack(
          children: [
            Positioned(
              top: pad.top + 27,
              left: 22,
              child: RoundIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, pad.top + 80, 20, pad.bottom + 28),
                child: Column(
                  children: [
                    const _AppIcon(size: 96),
                    const SizedBox(height: 16),
                    Text(
                      'PocketDesk',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: c.ink),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (_, snap) {
                        final i = snap.data;
                        final v = i == null
                            ? ''
                            : 'VERSION ${i.version}${i.buildNumber.isEmpty ? '' : ' (${i.buildNumber})'}';
                        return Text(v, style: TextStyle(fontSize: 9, letterSpacing: 2.7, color: c.ink2));
                      },
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: c.pill,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 20)),
                        ],
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(fontFamily: 'Manrope', color: c.pillInk),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _caps(c, 'CREDITS', 2.9),
                            const SizedBox(height: 18),
                            _caps(c, 'BASED ON', 2.3),
                            const SizedBox(height: 4),
                            const Text('PairDesk by Sandun Madhushan', style: TextStyle(fontSize: 19)),
                            InkWell(
                              onTap: () => _open(_upstreamRepo),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 36),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'github.com/sandunMadhushan/pairdesk',
                                      style: TextStyle(fontSize: 12, color: c.pillInk.withValues(alpha: 0.8)),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_outward,
                                      size: 15,
                                      color: c.pillInk.withValues(alpha: 0.8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _rule(c),
                            _caps(c, 'IPHONE & MAC VERSIONS BY', 2.3),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _open(_pocketdeskRepo),
                              child: const Text('Lapalu Liyanage', style: TextStyle(fontSize: 19)),
                            ),
                            _rule(c),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _caps(c, 'LICENCE', 2.3),
                                    const SizedBox(height: 4),
                                    const Text('GPL-3.0-or-later', style: TextStyle(fontSize: 15)),
                                  ],
                                ),
                                Tooltip(
                                  message: 'Read the licence',
                                  child: Material(
                                    color: c.acc,
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _open(_licence),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Icon(Icons.arrow_forward, size: 20, color: c.accInk),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'PocketDesk is an independent version. It isn’t the official PairDesk app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1.5, color: c.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _caps(PocketColors c, String text, double spacing) => Text(
    text,
    style: TextStyle(fontSize: 9, letterSpacing: spacing, color: c.pillInk.withValues(alpha: 0.6)),
  );

  static Widget _rule(PocketColors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(height: 1, thickness: 1, color: c.pillInk.withValues(alpha: 0.14)),
  );
}

/// The app icon ("In the pocket"), drawn from the same shapes as the SVG.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 20, offset: Offset(0, 12))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: CustomPaint(painter: _IconPainter()),
    ),
  );
}

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 256, size.height / 256);
    const ink = Color(0xFF1C1C1D);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 256, 256), Paint()..color = Colors.white);
    // Phone outline.
    final phone = RRect.fromRectAndRadius(const Rect.fromLTWH(88, 40, 80, 130), const Radius.circular(18));
    canvas.drawRRect(phone, Paint()..color = Colors.white);
    canvas.drawRRect(
      phone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = ink,
    );
    canvas.drawCircle(const Offset(128, 86), 13, Paint()..color = const Color(0xFFE3352B));
    // The pocket.
    final pocket = Path()
      ..moveTo(48, 124)
      ..lineTo(208, 124)
      ..lineTo(208, 172)
      ..arcToPoint(const Offset(164, 216), radius: const Radius.circular(44))
      ..lineTo(92, 216)
      ..arcToPoint(const Offset(48, 172), radius: const Radius.circular(44))
      ..close();
    canvas.drawPath(pocket, Paint()..color = ink);
    // Stitching.
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (double x = 72; x < 184; x += 19) {
      canvas.drawLine(Offset(x, 150), Offset((x + 10).clamp(72, 184), 150), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
