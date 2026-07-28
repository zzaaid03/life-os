/// In-memory [FactRepository] for the sandbox demo mode.
///
/// Demo mode makes zero network calls; that property is verified elsewhere
/// and must not regress. Seeded with believable facts for "Alex," the demo
/// persona, each carrying real evidence text since that's what the Settings
/// mirror actually displays.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/learning/data/models/user_fact.dart';
import 'package:life_os/features/learning/data/repositories/fact_repository.dart';

/// Repository for [UserFact] records backed by an in-memory demo list.
class DemoFactRepository implements FactRepository {
  /// Creates a [DemoFactRepository] seeded with Alex's facts.
  DemoFactRepository() : _facts = _buildDemoFacts();

  final List<UserFact> _facts;

  @override
  Future<List<UserFact>> getAll(String userId) async {
    if (userId != demoUserId) return const [];
    return List.unmodifiable(_facts);
  }

  @override
  Future<void> suppress(UserFact fact) async {
    _facts.removeWhere((f) => f.id == fact.id);
  }
}

List<UserFact> _buildDemoFacts() {
  final now = DateTime.now();
  return [
    UserFact(
      id: 'demo-fact-evening-worker',
      userId: demoUserId,
      category: FactCategory.routine,
      fact: 'You usually finish tasks in the evening.',
      evidence:
          'Both completed tasks ("Finish Apex Analytics take-home", "Attend '
          'Halcyon Health phone screen") were marked done after 6pm.',
      factKey: 'evening worker',
      firstSeenAt: now.subtract(const Duration(days: 5)),
      lastConfirmedAt: now,
    ),
    UserFact(
      id: 'demo-fact-job-hunting',
      userId: demoUserId,
      category: FactCategory.situation,
      fact: "You're actively job hunting for Product Manager roles.",
      evidence:
          '4 open job applications tracked: Meridian Financial (interview), '
          'Nimbus Labs (applied), Vertex Design (viewed), Orbital Systems '
          '(rejected).',
      factKey: 'actively job hunting for pm roles',
      firstSeenAt: now.subtract(const Duration(days: 6)),
      lastConfirmedAt: now,
    ),
    UserFact(
      id: 'demo-fact-breaks-goals-down',
      userId: demoUserId,
      category: FactCategory.preference,
      fact: 'You break big goals into small, linked tasks.',
      evidence:
          'Both goals ("Land a Product Manager role by Q4", "Build a '
          'standout portfolio") have several tasks linked via goal_id rather '
          'than standing alone.',
      factKey: 'breaks goals into linked tasks',
      firstSeenAt: now.subtract(const Duration(days: 4)),
      lastConfirmedAt: now,
    ),
    UserFact(
      id: 'demo-fact-interview-prep-heavy',
      userId: demoUserId,
      category: FactCategory.routine,
      fact: 'You prepare heavily before interviews.',
      evidence:
          'Tasks "Prep for Meridian Financial interview" and "Practice '
          'system-design questions" are both linked to the Meridian '
          'application ahead of its interview stage.',
      factKey: 'prepares heavily before interviews',
      firstSeenAt: now.subtract(const Duration(days: 2)),
      lastConfirmedAt: now,
    ),
    UserFact(
      id: 'demo-fact-avoids-overcommitting',
      userId: demoUserId,
      category: FactCategory.constraint,
      fact: "You don't chase every application at once.",
      evidence:
          'The Orbital Systems application was marked rejected and has no '
          'follow-up tasks, while effort concentrates on Meridian and '
          'Nimbus instead.',
      factKey: 'does not chase every application at once',
      firstSeenAt: now.subtract(const Duration(days: 3)),
      lastConfirmedAt: now,
    ),
  ];
}
