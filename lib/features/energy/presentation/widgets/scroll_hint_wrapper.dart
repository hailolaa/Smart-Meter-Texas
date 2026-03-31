import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Wraps a horizontally-scrollable child and overlays a subtle floating
/// "scroll →" arrow on the right edge. The arrow fades out once the user
/// reaches the end (or after a short auto-hide delay).
class ScrollHintWrapper extends StatefulWidget {
  const ScrollHintWrapper({
    super.key,
    required this.child,
    this.scrollController,
    this.autoHideDelay = const Duration(seconds: 3),
  });

  /// The scrollable content (typically a [SingleChildScrollView]).
  final Widget child;

  /// Optionally provide the scroll controller that drives the inner
  /// [SingleChildScrollView] so the hint can react to scroll position.
  /// If omitted, the wrapper will try to discover it from
  /// [Scrollable.of] after layout.
  final ScrollController? scrollController;

  /// Duration after which the hint auto-fades even if the user hasn't
  /// scrolled to the end. Set to [Duration.zero] to disable auto-hide.
  final Duration autoHideDelay;

  @override
  State<ScrollHintWrapper> createState() => _ScrollHintWrapperState();
}

class _ScrollHintWrapperState extends State<ScrollHintWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  ScrollController? _ownController;
  bool _visible = true;

  ScrollController? get _activeController =>
      widget.scrollController ?? _ownController;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0, // starts visible
    );
    // Schedule a post-frame check so the scroll extent is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discoverController();
      _evaluateVisibility();
      _scheduleAutoHide();
    });
  }

  @override
  void dispose() {
    _activeController?.removeListener(_onScroll);
    _fade.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────

  void _discoverController() {
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
      return;
    }
    // Try to find one from the widget tree.
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _ownController = scrollable.widget.controller;
      _ownController?.addListener(_onScroll);
    }
  }

  void _onScroll() => _evaluateVisibility();

  void _evaluateVisibility() {
    final ctrl = _activeController;
    if (ctrl == null || !ctrl.hasClients) return;
    final pos = ctrl.position;
    // Hide when scrolled to the end (within 8px tolerance).
    final atEnd = pos.pixels >= pos.maxScrollExtent - 8;
    if (atEnd && _visible) {
      _visible = false;
      _fade.reverse();
    } else if (!atEnd && !_visible) {
      _visible = true;
      _fade.forward();
    }
  }

  void _scheduleAutoHide() {
    if (widget.autoHideDelay == Duration.zero) return;
    Future.delayed(widget.autoHideDelay, () {
      if (!mounted) return;
      if (_visible) {
        _visible = false;
        _fade.reverse();
      }
    });
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Floating arrow on the right edge.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: FadeTransition(
            opacity: _fade,
            child: IgnorePointer(
              child: Container(
                width: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      AppColors.cardBackground.withValues(alpha: 0.95),
                      AppColors.cardBackground.withValues(alpha: 0),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
