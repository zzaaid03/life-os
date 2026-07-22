/// Announcements modal carousel.
///
/// Shown after sign-in whenever there are unseen releases, and re-openable
/// any time from Settings → About → "What's new".
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/onboarding/domain/release_notes.dart';

/// A modal, swipeable carousel of announcement slides.
class AnnouncementsSheet extends StatefulWidget {
  const AnnouncementsSheet._({required this.slides});

  /// Flattened slides from one or more releases.
  final List<AnnouncementSlide> slides;

  /// Shows the announcements carousel for the given [releases].
  static Future<void> show(BuildContext context, List<Release> releases) {
    final slides = releases.expand((r) => r.slides).toList();
    if (slides.isEmpty) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (_) => AnnouncementsSheet._(slides: slides),
    );
  }

  @override
  State<AnnouncementsSheet> createState() => _AnnouncementsSheetState();
}

class _AnnouncementsSheetState extends State<AnnouncementsSheet> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == widget.slides.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == widget.slides.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Skip'),
                ),
              ),
              SizedBox(
                height: 360,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final slide = widget.slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(
                              slide.icon,
                              color: theme.colorScheme.primary,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            slide.headline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.circular),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
