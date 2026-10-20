import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/jobs/domain/job_status.dart';

void main() {
  group('emailMayChangeStatus', () {
    test('allows moving forward', () {
      expect(emailMayChangeStatus('applied', 'viewed'), isTrue);
      expect(emailMayChangeStatus('viewed', 'interview'), isTrue);
      expect(emailMayChangeStatus('interview', 'rejected'), isTrue);
      expect(emailMayChangeStatus('applied', 'accepted'), isTrue);
    });

    test('blocks moving backward', () {
      expect(emailMayChangeStatus('interview', 'applied'), isFalse);
      expect(emailMayChangeStatus('viewed', 'applied'), isFalse);
    });

    test('blocks the same status', () {
      expect(emailMayChangeStatus('viewed', 'viewed'), isFalse);
    });

    test('blocks any change out of a final status', () {
      expect(emailMayChangeStatus('rejected', 'applied'), isFalse);
      expect(emailMayChangeStatus('accepted', 'interview'), isFalse);
    });

    test('blocks final to final', () {
      expect(emailMayChangeStatus('rejected', 'accepted'), isFalse);
      expect(emailMayChangeStatus('accepted', 'rejected'), isFalse);
    });
  });
}
