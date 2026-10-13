import 'package:flutter/material.dart';

import '../../core/app_strings.dart';

/// Scrollable confirmed captions plus a separate provisional line.
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
      if (distance < 80) {
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
    final captionStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.45,
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final confirmed = widget.confirmedText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.confirmedLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    child: confirmed.isEmpty
                        ? Text(
                            AppStrings.emptyCaptions,
                            key: CaptionView.confirmedKey,
                            style: captionStyle,
                          )
                        : Text(
                            confirmed,
                            key: CaptionView.confirmedKey,
                            style: captionStyle,
                            softWrap: true,
                          ),
                  ),
                ),
                if (_showJump)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton(
                      key: CaptionView.jumpKey,
                      onPressed: () {
                        if (!_scroll.hasClients) {
                          return;
                        }
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                        setState(() => _showJump = false);
                      },
                      child: const Text(AppStrings.jumpToLatest),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.provisionalLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.onSurface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.provisional.trim().isEmpty
                      ? AppStrings.emptyCaptions
                      : widget.provisional,
                  key: CaptionView.provisionalKey,
                  style: captionStyle.copyWith(fontWeight: FontWeight.w500),
                  softWrap: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
