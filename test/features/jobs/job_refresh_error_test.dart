import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';

class _FakeJobRepository extends Fake implements JobApplicationRepository {
  bool fail = false;

  @override
  Future<List<JobApplication>> getAll(String userId) async {
    if (fail) throw StateError('offline');
    return [
      JobApplication(
        id: 'j1',
        company: 'Acme',
        role: 'Engineer',
        status: 'applied',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }
}

void main() {
  test('a failed refresh keeps the jobs and sets an error', () async {
    final repo = _FakeJobRepository();
    final notifier = JobListNotifier(repo);

    await notifier.load('user-1');
    expect(notifier.state.jobs, hasLength(1));
    expect(notifier.state.error, isNull);

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, JobListStatus.loaded);
    expect(notifier.state.jobs, hasLength(1));
    expect(
      notifier.state.error,
      "Couldn't refresh your job applications. Check your connection and try again.",
    );
  });

  test('a later successful refresh clears the error', () async {
    final repo = _FakeJobRepository();
    final notifier = JobListNotifier(repo);
    await notifier.load('user-1');
    repo.fail = true;
    await notifier.refresh();
    repo.fail = false;
    await notifier.refresh();

    expect(notifier.state.error, isNull);
  });
}
