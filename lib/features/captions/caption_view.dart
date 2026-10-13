import 'package:flutter/material.dart';

import '../../core/app_strings.dart';

/// Large reading view. Older lines stay readable; the newest line is biggest.
class CaptionView extends StatefulWidget {
  const CaptionView({
    required this.confirmedText,
    required this.provisional,
    required this.fontSize,
    super.key,
  });

  final String confirmedText;
  final String provisional;
  final double fontSize;

  static const confirmedKey = Key('confirmed-captions');
  static const provisionalKey = Key('provisional-captions');
  static const jumpKey = Key('jump-to-latest');

  @override
  State<CaptionView> createState() => _CaptionViewState();
}

class _CaptionViewState extends State<CaptionView> {
  final ScrollController _scroll = ScrollController();
  var _showJump = false;

  @override
  void didUpdateWidget(CaptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confirmedText != widget.confirmedText ||
        oldWidget.provisional != widget.provisional) {
      _scheduleScroll();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      final position = _scroll.position;
      final distance = position.maxScrollExtent - position.pixels;
      if (distance < 120) {
        _scroll.jumpTo(position.maxScrollExtent);
        if (_showJump) {
          setState(() => _showJump = false);
        }
      } else if (!_showJump) {
        setState(() => _showJump = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111111);
    final confirmed = widget.confirmedText.trim();
    final provisional = widget.provisional.trim();
    final lines = confirmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final older = lines.length > 1
        ? lines.sublist(0, lines.length - 1).join('\n')
        : '';
    final latest = lines.isEmpty ? '' : lines.last;
    final latestStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.45,
      color: ink,
      fontWeight: FontWeight.w800,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (older.isNotEmpty) ...[
                        Text(
                          older,
                          style: latestStyle.copyWith(
                            fontSize: widget.fontSize * 0.62,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: ink.withValues(alpha: 0.62),
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (latest.isNotEmpty)
                        Text(
                          latest,
                          key: CaptionView.confirmedKey,
                          style: latestStyle,
                          softWrap: true,
                        )
                      else if (provisional.isEmpty)
                        Text(
                          AppStrings.emptyCaptions,
                          key: CaptionView.confirmedKey,
                          style: latestStyle.copyWith(
                            color: ink.withValues(alpha: 0.28),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (provisional.isNotEmpty) ...[
                        if (latest.isNotEmpty) const SizedBox(height: 14),
                        Text(
                          provisional,
                          key: CaptionView.provisionalKey,
                          style: latestStyle.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_showJump)
              Positioned(
                right: 12,
                bottom: 4,
                child: IconButton.filled(
                  key: CaptionView.jumpKey,
                  tooltip: AppStrings.jumpToLatest,
                  onPressed: () {
                    if (!_scroll.hasClients) {
                      return;
                    }
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                    setState(() => _showJump = false);
                  },
                  icon: const Icon(Icons.arrow_downward),
                ),
              ),
          ],
        );
      },
    );
  }
}
