import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Standard pull-to-refresh component for the Condomeet mobile application.
///
/// Encapsulates [RefreshIndicator] ensuring:
/// - Brand visual identity ([AppColors.primary] indicator, white background);
/// - Seamless pull-to-refresh on short lists and empty states via [wrapEmpty] or [isEmpty]/[emptyWidget];
/// - Strict concurrency protection preventing simultaneous/duplicate refresh executions.
class CondoPullToRefresh extends StatefulWidget {
  /// The asynchronous callback invoked when user triggers a pull-to-refresh.
  final Future<void> Function() onRefresh;

  /// The scrollable child widget (e.g. [ListView], [SingleChildScrollView], [CustomScrollView]).
  final Widget child;

  /// Optional flag indicating if the current dataset is empty.
  /// When true and [emptyWidget] is supplied, [emptyWidget] will be rendered
  /// wrapped inside a scrollable view with [AlwaysScrollableScrollPhysics] so
  /// pull-to-refresh remains functional on empty states.
  final bool? isEmpty;

  /// Optional empty state widget displayed when [isEmpty] is true.
  final Widget? emptyWidget;

  /// Color of the refresh spinner. Defaults to [AppColors.primary].
  final Color? color;

  /// Background color of the refresh indicator circle. Defaults to [Colors.white].
  final Color? backgroundColor;

  /// The displacement of the refresh indicator. Defaults to 40.0.
  final double displacement;

  /// The offset at which the refresh indicator starts. Defaults to 0.0.
  final double edgeOffset;

  const CondoPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.isEmpty,
    this.emptyWidget,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
  });

  /// Factory constructor to wrap any non-scrollable widget (such as a standalone empty state)
  /// in a scrollable view with [AlwaysScrollableScrollPhysics] so pull-to-refresh is enabled.
  factory CondoPullToRefresh.scrollable({
    Key? key,
    required Future<void> Function() onRefresh,
    required Widget child,
    Color? color,
    Color? backgroundColor,
    double displacement = 40.0,
    double edgeOffset = 0.0,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
  }) {
    return CondoPullToRefresh(
      key: key,
      onRefresh: onRefresh,
      color: color,
      backgroundColor: backgroundColor,
      displacement: displacement,
      edgeOffset: edgeOffset,
      child: wrapEmpty(
        child: child,
        padding: padding,
        physics: physics,
      ),
    );
  }

  /// Helper that wraps a non-scrollable child widget into a full-height, scrollable view
  /// using [AlwaysScrollableScrollPhysics].
  static Widget wrapEmpty({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: physics,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
            minWidth: constraints.maxWidth,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// Standard scroll physics to ensure pull-to-refresh works on short lists.
  static const ScrollPhysics alwaysScrollablePhysics = AlwaysScrollableScrollPhysics();

  @override
  State<CondoPullToRefresh> createState() => CondoPullToRefreshState();
}

class CondoPullToRefreshState extends State<CondoPullToRefresh> {
  bool _isRefreshing = false;

  /// Indicates whether a refresh operation is currently in progress.
  bool get isRefreshing => _isRefreshing;

  Future<void> _handleRefresh() async {
    // Concurrency guard: ignore duplicate calls while a refresh is already in flight.
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      } else {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.isEmpty == true && widget.emptyWidget != null) {
      content = CondoPullToRefresh.wrapEmpty(
        child: widget.emptyWidget!,
      );
    } else {
      content = widget.child;
    }

    return RefreshIndicator(
      color: widget.color ?? AppColors.primary,
      backgroundColor: widget.backgroundColor ?? Colors.white,
      displacement: widget.displacement,
      edgeOffset: widget.edgeOffset,
      onRefresh: _handleRefresh,
      child: content,
    );
  }
}
