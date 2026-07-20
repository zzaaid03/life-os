/// Presentation helpers for job entries.
///
/// A scan-derived job update or a persisted application may lack a company
/// (and sometimes a role) when the AI couldn't identify one. These helpers
/// build a sensible, never-blank title from whatever is available.
library;

/// Builds a display title for a job entry.
///
/// - company non-empty → `company` (with ` · role` appended when role set)
/// - company empty, role non-empty → `role`
/// - both empty → a status-based fallback headline so the title is never blank
String jobDisplayTitle({
  required String company,
  required String role,
  required String status,
}) {
  final trimmedCompany = company.trim();
  final trimmedRole = role.trim();

  if (trimmedCompany.isNotEmpty) {
    return trimmedRole.isEmpty
        ? trimmedCompany
        : '$trimmedCompany · $trimmedRole';
  }
  if (trimmedRole.isNotEmpty) return trimmedRole;
  return jobStatusHeadline(status);
}

/// A short status-based headline used when neither company nor role is known.
String jobStatusHeadline(String status) {
  return switch (status.toLowerCase()) {
    'rejected' => 'Rejected',
    'interview' => 'Interview',
    'accepted' => 'Accepted',
    'viewed' => 'Application viewed',
    _ => 'Application update',
  };
}
