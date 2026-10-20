/// Job application statuses and the forward-only rule for email updates.
library;

/// The five valid job-application statuses.
const List<String> kJobStatuses = [
  'applied',
  'viewed',
  'interview',
  'rejected',
  'accepted',
];

/// Position of [status] in the pipeline. Rejected and accepted share the top
/// rank. Unknown statuses rank 0.
int jobStatusRank(String status) {
  switch (status) {
    case 'applied':
      return 1;
    case 'viewed':
      return 2;
    case 'interview':
      return 3;
    case 'rejected':
    case 'accepted':
      return 4;
    default:
      return 0;
  }
}

/// Whether [status] is an end state (rejected or accepted).
bool isFinalJobStatus(String status) =>
    status == 'rejected' || status == 'accepted';

/// Whether an email may move a job from [current] to [incoming]: only forward,
/// and never out of a final status.
bool emailMayChangeStatus(String current, String incoming) {
  if (isFinalJobStatus(current)) return false;
  return jobStatusRank(incoming) > jobStatusRank(current);
}
