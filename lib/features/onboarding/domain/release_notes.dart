/// Release notes content for the announcements engine.
///
/// Each [Release] is a versioned set of [AnnouncementSlide]s shown to users
/// once via the onboarding/what's-new carousel. Add a new [Release] with a
/// higher [Release.version] to announce a future update.
library;

import 'package:flutter/material.dart';

/// A single slide within a release's announcement carousel.
class AnnouncementSlide {
  /// Creates an [AnnouncementSlide].
  const AnnouncementSlide({
    required this.icon,
    required this.headline,
    required this.body,
  });

  /// Icon shown at the top of the slide.
  final IconData icon;

  /// Short, punchy title.
  final String headline;

  /// One or two sentences explaining the feature.
  final String body;
}

/// A versioned set of announcement slides.
class Release {
  /// Creates a [Release].
  const Release({required this.version, required this.slides});

  /// Monotonically increasing version number. Bump this to ship a new
  /// "what's new" announcement to existing users.
  final int version;

  /// Slides shown for this release.
  final List<AnnouncementSlide> slides;
}

/// All releases, in ascending version order.
const List<Release> kReleases = [
  Release(
    version: 1,
    slides: [
      AnnouncementSlide(
        icon: Icons.auto_awesome_rounded,
        headline: 'Welcome to Life OS',
        body: 'Your life, organized by AI.',
      ),
      AnnouncementSlide(
        icon: Icons.mark_email_read_outlined,
        headline: 'AI reads your inbox',
        body:
            'Turn recent emails into tasks and job-application updates, '
            'automatically.',
      ),
      AnnouncementSlide(
        icon: Icons.checklist_rounded,
        headline: 'Tasks & timeline',
        body:
            'Capture tasks with due dates and see everything on one '
            'unified timeline.',
      ),
      AnnouncementSlide(
        icon: Icons.flag_outlined,
        headline: 'Goals, broken down',
        body:
            'Give Life OS a big goal and AI splits it into concrete, '
            'trackable tasks.',
      ),
      AnnouncementSlide(
        icon: Icons.wb_sunny_outlined,
        headline: 'Your Daily Brief',
        body:
            'Each day, an AI brief highlights what matters. Switch '
            'light/dark theme any time in Settings.',
      ),
    ],
  ),
  Release(
    version: 2,
    slides: [
      AnnouncementSlide(
        icon: Icons.auto_awesome_outlined,
        headline: 'Life is learning about you',
        body:
            'From your tasks, goals and files, Life quietly picks up on '
            'patterns: your routines, and what you\'re focused on '
            'right now.',
      ),
      AnnouncementSlide(
        icon: Icons.visibility_outlined,
        headline: 'See what it knows',
        body:
            'Settings → "What Life knows about you" shows every fact it '
            'has learned, with the evidence behind it. Nothing is hidden.',
      ),
      AnnouncementSlide(
        icon: Icons.close_rounded,
        headline: 'Wrong? Remove it',
        body:
            'Tap the X on any fact to remove it for good. Life won\'t '
            'infer it again.',
      ),
    ],
  ),
  Release(
    version: 3,
    slides: [
      AnnouncementSlide(
        icon: Icons.repeat_rounded,
        headline: 'Tasks that repeat',
        body:
            'Set a task to repeat daily, weekly or monthly. Complete it '
            'and the next one is created automatically.',
      ),
      AnnouncementSlide(
        icon: Icons.edit_calendar_outlined,
        headline: 'Set it once',
        body:
            'Pick "Repeats" in the task editor and Life OS keeps the '
            'schedule going, no need to re-add the task each time.',
      ),
    ],
  ),
];

/// The most recent release version. Bumping [kReleases] with a new entry
/// automatically raises this.
int get kLatestReleaseVersion => kReleases.last.version;
