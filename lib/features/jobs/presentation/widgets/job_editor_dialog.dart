/// Job application editor dialog.
///
/// A centered dialog for manually creating or editing a job application:
/// company, role, status (dropdown of the five statuses), and optional
/// summary/location. Mirrors the task editor's visual language.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';

/// The five valid job-application statuses.
const List<String> kJobStatuses = [
  'applied',
  'viewed',
  'interview',
  'rejected',
  'accepted',
];

/// The values collected by [JobEditorDialog].
class JobEditorResult {
  /// Creates a [JobEditorResult].
  const JobEditorResult({
    required this.company,
    required this.role,
    required this.status,
    this.summary,
    this.location,
  });

  /// Company name (may be empty for a company-less entry).
  final String company;

  /// Role title.
  final String role;

  /// One of [kJobStatuses].
  final String status;

  /// Optional one-line summary.
  final String? summary;

  /// Optional location.
  final String? location;
}

/// A centered dialog for creating or editing a job application.
class JobEditorDialog extends StatefulWidget {
  /// Creates a [JobEditorDialog]. Pass [existing] to edit.
  const JobEditorDialog({super.key, this.existing});

  /// The application being edited, or null to create a new one.
  final JobApplication? existing;

  /// Shows the editor. Resolves to the entered values, or null on cancel.
  static Future<JobEditorResult?> show(
    BuildContext context, {
    JobApplication? existing,
  }) {
    return showDialog<JobEditorResult>(
      context: context,
      builder: (_) => JobEditorDialog(existing: existing),
    );
  }

  @override
  State<JobEditorDialog> createState() => _JobEditorDialogState();
}

class _JobEditorDialogState extends State<JobEditorDialog> {
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _locationController;
  late String _status;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _companyController = TextEditingController(text: existing?.company ?? '');
    _roleController = TextEditingController(text: existing?.role ?? '');
    _summaryController = TextEditingController(text: existing?.summary ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _status = kJobStatuses.contains(existing?.status)
        ? existing!.status
        : 'applied';
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _summaryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// At least one of company/role must be present so the row has a title.
  bool get _isValid =>
      _companyController.text.trim().isNotEmpty ||
      _roleController.text.trim().isNotEmpty;

  void _save() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      JobEditorResult(
        company: _companyController.text.trim(),
        role: _roleController.text.trim(),
        status: _status,
        summary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: screenHeight * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing != null
                      ? 'Edit Application'
                      : 'New Application',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _companyController,
                  autofocus: widget.existing == null,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    hintText: 'Who did you apply to?',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _roleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    hintText: 'Position title',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in kJobStatuses)
                      DropdownMenuItem(
                        value: status,
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _locationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _summaryController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Summary (optional)',
                    hintText: 'Latest update in one sentence',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isValid ? _save : null,
                        child: Text(
                          widget.existing != null ? 'Save' : 'Create',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
