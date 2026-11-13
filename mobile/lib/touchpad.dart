// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/pocket_style.dart';
import 'agent_connection.dart';
import 'touchpad_gestures.dart';

/// Full-area touchpad that drives the laptop cursor.
class Touchpad extends StatefulWidget {
  const Touchpad({super.key, required this.connection, this.speed = 1.0, this.naturalScroll = true});

  final AgentConnection connection;

  /// Multiplies cursor speed (1.0 = default).
  final double speed;

  /// True: content follows the fingers.
  final bool naturalScroll;

  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad> {
  late final TouchpadGestures _gestures = TouchpadGestures(
    onMove: widget.connection.move,
    onScroll: (dx, dy) => widget.naturalScroll
        ? widget.connection.scroll(dx: dx, dy: dy)
        : widget.connection.scroll(dx: -dx, dy: -dy),
    onClick: (b) {
      HapticFeedback.lightImpact();
      widget.connection.click(b);
    },
  );

  int _fingers = 0;

  void _sync() {
    if (_fingers != _gestures.activePointers) {
      setState(() => _fingers = _gestures.activePointers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = PocketColors.of(context);
    _gestures.sensitivity = 1.6 * widget.speed;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _gestures.pointerDown(e.pointer, e.localPosition, e.timeStamp);
        _sync();
      },
      onPointerMove: (e) => _gestures.pointerMove(e.pointer, e.localPosition, e.timeStamp),
      onPointerUp: (e) {
        _gestures.pointerUp(e.pointer, e.localPosition, e.timeStamp);
        _sync();
      },
      onPointerCancel: (e) {
        _gestures.pointerCancel(e.pointer);
        _sync();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _fingers > 0 ? pc.field : pc.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: pc.shadow,
        ),
        child: Center(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ONE FINGER · MOVE · TAP TO CLICK\n'
                'TWO FINGERS · SCROLL · TAP FOR RIGHT-CLICK',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, height: 2, letterSpacing: 2.4, color: pc.ink3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A mouse button that stays pressed while your finger is on it, so you can
/// drag with another finger on the touchpad.
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.connection, required this.button, required this.label});

  final AgentConnection connection;
  final MouseBtn button;
  final String label;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _down = false;

  void _press() {
    if (_down) return;
    HapticFeedback.selectionClick();
    setState(() => _down = true);
    widget.connection.buttonDown(widget.button);
  }

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
    widget.connection.buttonUp(widget.button);
  }

  @override
  void dispose() {
    if (_down) widget.connection.buttonUp(widget.button);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = PocketColors.of(context);
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _down ? pc.acc : pc.pill,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
            color: _down ? pc.accInk : pc.pillInk,
          ),
        ),
      ),
    );
  }
}
