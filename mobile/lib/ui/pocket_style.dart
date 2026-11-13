// SPDX-License-Identifier: GPL-3.0-or-later
// The PocketDesk look from the design pass: white surfaces with soft depth,
// a black stadium pill as the hero, outlined vertical wordmarks, black square
// badges, one red accent, and a black quarter-circle corner action.

import 'package:flutter/material.dart';

/// Colours and shadows of the design, light and dark.
@immutable
class PocketColors extends ThemeExtension<PocketColors> {
  const PocketColors({
    required this.bgTop,
    required this.bgBottom,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.pill,
    required this.pillInk,
    required this.acc,
    required this.accInk,
    required this.wordmark,
    required this.field,
    required this.shadow,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// The black (or, in dark mode, near-white) hero pill, badges and corner.
  final Color pill;
  final Color pillInk;

  /// The one red accent, and the colour of text on it.
  final Color acc;
  final Color accInk;

  /// Outline colour of the big vertical word.
  final Color wordmark;
  final Color field;
  final List<BoxShadow> shadow;

  static const light = PocketColors(
    bgTop: Color(0xFFFCFCFB),
    bgBottom: Color(0xFFEFEFED),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1A1A),
    ink2: Color(0xFF76767A),
    ink3: Color(0xFFB6B6B8),
    pill: Color(0xFF1C1C1D),
    pillInk: Color(0xFFFAFAFA),
    acc: Color(0xFFE3352B),
    accInk: Color(0xFFFFFFFF),
    wordmark: Color(0x29000000),
    field: Color(0xFFF1F1EF),
    shadow: [
      BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 10)),
    ],
  );

  static const dark = PocketColors(
    bgTop: Color(0xFF1A1A1C),
    bgBottom: Color(0xFF0E0E0F),
    card: Color(0xFF232325),
    ink: Color(0xFFF3F3F1),
    ink2: Color(0xFF9C9CA0),
    ink3: Color(0xFF58585C),
    pill: Color(0xFFF3F3F1),
    pillInk: Color(0xFF161617),
    acc: Color(0xFFFF4A3D),
    accInk: Color(0xFFFFFFFF),
    wordmark: Color(0x29FFFFFF),
    field: Color(0xFF2D2D2F),
    shadow: [BoxShadow(color: Color(0x73000000), blurRadius: 26, offset: Offset(0, 12))],
  );

  /// The colours for this context, also where the theme carries no extension
  /// (a bare MaterialApp in a test).
  static PocketColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PocketColors>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  PocketColors copyWith() => this;

  @override
  PocketColors lerp(ThemeExtension<PocketColors>? other, double t) =>
      t < 0.5 ? this : (other as PocketColors? ?? this);
}

/// The screen background: a soft top-to-bottom gradient.
class PocketBackground extends StatelessWidget {
  const PocketBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bgTop, c.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

/// The black stadium pill that heads a screen: a caption over a title.
class PillHeader extends StatelessWidget {
  const PillHeader({super.key, required this.label, required this.title});

  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: c.pill,
        borderRadius: BorderRadius.circular(33),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, letterSpacing: 2.9, color: c.pillInk.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 19, color: c.pillInk)),
        ],
      ),
    );
  }
}

/// The big outlined word running down the left edge.
class OutlineWordmark extends StatelessWidget {
  const OutlineWordmark(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return ExcludeSemantics(
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 76,
            height: 1,
            fontWeight: FontWeight.w200,
            letterSpacing: 15,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = c.wordmark.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// A white card with the soft shadow.
class PocketCard extends StatelessWidget {
  const PocketCard({super.key, required this.child, this.height, this.radius = 16, this.onTap});

  final Widget child;
  final double? height;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    final shape = BorderRadius.circular(radius);
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.card, borderRadius: shape, boxShadow: c.shadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// A square badge in the pill colour, holding an icon or a number.
class PocketBadge extends StatelessWidget {
  const PocketBadge({super.key, required this.child, this.size = 38, this.muted = false});

  final Widget child;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? c.field : c.pill,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: IconTheme(
        data: IconThemeData(color: muted ? c.ink2 : c.pillInk, size: size * 0.5),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: muted ? c.ink2 : c.pillInk, fontWeight: FontWeight.w600),
          child: child,
        ),
      ),
    );
  }
}

/// The round button at the top right (settings).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, boxShadow: c.shadow),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, size: 22, color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// The black quarter circle in the bottom-right corner: the main action.
class CornerAction extends StatelessWidget {
  const CornerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    const size = 138.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: onPressed == null ? c.pill.withValues(alpha: 0.5) : c.pill,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(size)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size + bottom * 0.4,
              alignment: Alignment.bottomRight,
              padding: EdgeInsets.only(right: 34, bottom: 40 + bottom * 0.4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(icon, size: 28, color: c.pillInk),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(fontSize: 9, letterSpacing: 2.7, color: c.pillInk)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text action ("PASTE A LINK").
class CapsAction extends StatelessWidget {
  const CapsAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PocketColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.ink2),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 10, letterSpacing: 2.6, color: c.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app theme from the design: near-black ink on white, one red accent,
/// Manrope, pill-shaped buttons, soft cards. Every screen that doesn't draw
/// itself (control tabs, settings, sheets, dialogs) takes its look from here.
ThemeData pocketTheme({required bool dark}) {
  final c = dark ? PocketColors.dark : PocketColors.light;
  final base = dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.pill, brightness: base).copyWith(
    primary: c.pill,
    onPrimary: c.pillInk,
    primaryContainer: c.field,
    onPrimaryContainer: c.ink,
    secondary: c.acc,
    onSecondary: c.accInk,
    secondaryContainer: c.field,
    onSecondaryContainer: c.ink,
    tertiary: c.acc,
    error: c.acc,
    onError: c.accInk,
    surface: c.card,
    onSurface: c.ink,
    onSurfaceVariant: c.ink2,
    surfaceContainerLowest: c.bgTop,
    surfaceContainerLow: c.card,
    surfaceContainer: c.card,
    surfaceContainerHigh: c.card,
    surfaceContainerHighest: c.field,
    outline: c.ink3,
    outlineVariant: c.field,
  );
  const stadium = StadiumBorder();
  final radius = BorderRadius.circular(16);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: c.bgTop,
    canvasColor: c.bgTop,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.ink,
      textColor: c.ink,
      subtitleTextStyle: TextStyle(color: c.ink2),
    ),
    dividerTheme: DividerThemeData(color: c.field, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: c.pill,
      indicatorShape: stadium,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.pillInk : c.ink2, size: 22),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? c.ink : c.ink2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.pill,
        foregroundColor: c.pillInk,
        shape: stadium,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.ink3),
        shape: stadium,
        minimumSize: const Size(64, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.ink, shape: stadium),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.pill,
      foregroundColor: c.pillInk,
      shape: stadium,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.pillInk : c.ink2,
      ),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.pill : c.field),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.pill : c.ink3,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.pill,
      thumbColor: c.pill,
      inactiveTrackColor: c.field,
      overlayColor: c.pill.withValues(alpha: 0.12),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.pill,
      contentTextStyle: TextStyle(fontFamily: 'Manrope', color: c.pillInk),
      actionTextColor: c.pillInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.field,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.ink, width: 1.5),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: stadium,
        selectedBackgroundColor: c.pill,
        selectedForegroundColor: c.pillInk,
        foregroundColor: c.ink,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: stadium,
      backgroundColor: c.field,
      selectedColor: c.pill,
      side: BorderSide.none,
      labelStyle: TextStyle(color: c.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.pill, linearTrackColor: c.field),
    popupMenuTheme: PopupMenuThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
