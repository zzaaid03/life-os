/// Subscription editor dialog.
///
/// A centered dialog for manually creating or editing a subscription:
/// name, amount, currency, billing cycle, optional next charge date, and
/// optional notes. Mirrors the job/goal editor dialogs' visual language.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';

/// What the user asked the dialog to do.
enum SubscriptionEditorAction {
  /// Save the entered fields (create or update).
  save,

  /// Set the subscription's status to cancelled, without deleting it.
  cancelSubscription,

  /// Delete the subscription entirely.
  delete,
}

/// The result of closing [SubscriptionEditorDialog] with a real action.
class SubscriptionEditorResult {
  /// A save action: create or update with the collected field values.
  const SubscriptionEditorResult.save({
    required this.name,
    required this.amountCents,
    required this.currency,
    required this.cycle,
    this.nextChargeDate,
    this.notes,
  }) : action = SubscriptionEditorAction.save;

  /// Signals that the user asked to cancel the subscription instead of
  /// saving it.
  const SubscriptionEditorResult.cancelSubscription()
    : action = SubscriptionEditorAction.cancelSubscription,
      name = '',
      amountCents = 0,
      currency = 'USD',
      cycle = BillingCycle.monthly,
      nextChargeDate = null,
      notes = null;

  /// Signals that the user asked to delete the subscription instead of
  /// saving it.
  const SubscriptionEditorResult.delete()
    : action = SubscriptionEditorAction.delete,
      name = '',
      amountCents = 0,
      currency = 'USD',
      cycle = BillingCycle.monthly,
      nextChargeDate = null,
      notes = null;

  /// Which action the user asked for.
  final SubscriptionEditorAction action;

  /// Subscription name. Only meaningful when [action] is
  /// [SubscriptionEditorAction.save].
  final String name;

  /// The charge, in cents. Only meaningful for [SubscriptionEditorAction.save].
  final int amountCents;

  /// Three-letter uppercase ISO currency code.
  final String currency;

  /// How often the charge repeats.
  final BillingCycle cycle;

  /// The next expected charge, when set.
  final DateTime? nextChargeDate;

  /// Free-text note.
  final String? notes;
}

/// Starting values for a subscription the user has not created yet.
///
/// This exists so a caller can open the editor pre-filled without inventing a
/// [Subscription], which would need an id and timestamps for a row that does
/// not exist. The inbox scan is the caller this was built for: it maps what a
/// model read out of an email onto these fields.
///
/// **Every field is nullable on purpose.** A model that could not find an
/// amount must leave it null so the field opens empty and the user types it,
/// rather than being handed a confident zero. A null here means "the email did
/// not say", never "assume the default".
class SubscriptionDraft {
  /// Creates a [SubscriptionDraft].
  const SubscriptionDraft({
    this.name,
    this.amountCents,
    this.currency,
    this.cycle,
    this.nextChargeDate,
    this.notes,
  });

  /// Suggested name, or null to leave the field empty.
  final String? name;

  /// Suggested charge in cents, or null to leave the field empty.
  final int? amountCents;

  /// Suggested three-letter ISO code, or null to fall back to the default.
  final String? currency;

  /// Suggested billing cycle, or null to fall back to the default.
  final BillingCycle? cycle;

  /// Suggested next charge date, or null for none.
  final DateTime? nextChargeDate;

  /// Suggested note, or null for none.
  final String? notes;
}

/// A centered dialog for creating or editing a subscription.
class SubscriptionEditorDialog extends StatefulWidget {
  /// Creates a [SubscriptionEditorDialog]. Pass [existing] to edit, or
  /// [draft] to create with fields pre-filled.
  const SubscriptionEditorDialog({super.key, this.existing, this.draft});

  /// The subscription being edited, or null to create a new one.
  final Subscription? existing;

  /// Starting values for a new subscription. Ignored when [existing] is set,
  /// since editing a real row must never be overwritten by a suggestion.
  final SubscriptionDraft? draft;

  /// Shows the editor. Resolves to the entered values/action, or null on
  /// cancel.
  static Future<SubscriptionEditorResult?> show(
    BuildContext context, {
    Subscription? existing,
    SubscriptionDraft? draft,
  }) {
    return showDialog<SubscriptionEditorResult>(
      context: context,
      builder: (_) => SubscriptionEditorDialog(existing: existing, draft: draft),
    );
  }

  @override
  State<SubscriptionEditorDialog> createState() =>
      _SubscriptionEditorDialogState();
}

class _SubscriptionEditorDialogState extends State<SubscriptionEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _notesController;
  late BillingCycle _cycle;
  DateTime? _nextChargeDate;
  String? _amountError;
  String? _currencyError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    // A real row always wins over a suggestion, so the draft is only consulted
    // when there is nothing being edited.
    final draft = existing == null ? widget.draft : null;
    final draftAmount = draft?.amountCents;
    _nameController = TextEditingController(
      text: existing?.name ?? draft?.name ?? '',
    );
    _amountController = TextEditingController(
      text: existing != null
          ? formatAmount(existing.amountCents)
          : draftAmount != null
          ? formatAmount(draftAmount)
          : '',
    );
    _currencyController = TextEditingController(
      text: existing?.currency ?? draft?.currency ?? 'USD',
    );
    _notesController = TextEditingController(
      text: existing?.notes ?? draft?.notes ?? '',
    );
    _cycle = existing?.cycle ?? draft?.cycle ?? BillingCycle.monthly;
    _nextChargeDate = existing?.nextChargeDate ?? draft?.nextChargeDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      parseAmountCents(_amountController.text) != null &&
      _currencyController.text.trim().length == 3;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextChargeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() => _nextChargeDate = picked);
    }
  }

  void _validate() {
    final amountCents = parseAmountCents(_amountController.text);
    setState(() {
      _amountError = amountCents == null
          ? 'Enter a valid amount, e.g. 12.99'
          : null;
      _currencyError = _currencyController.text.trim().length == 3
          ? null
          : 'Use a 3-letter code, e.g. USD';
    });
  }

  void _save() {
    final amountCents = parseAmountCents(_amountController.text);
    if (_nameController.text.trim().isEmpty ||
        amountCents == null ||
        _currencyController.text.trim().length != 3) {
      _validate();
      return;
    }
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      SubscriptionEditorResult.save(
        name: _nameController.text.trim(),
        amountCents: amountCents,
        currency: _currencyController.text.trim().toUpperCase(),
        cycle: _cycle,
        nextChargeDate: _nextChargeDate,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final existing = widget.existing;

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
                  existing != null ? 'Edit Subscription' : 'New Subscription',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _nameController,
                  autofocus: existing == null,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Netflix',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: '12.99',
                          errorText: _amountError,
                        ),
                        onChanged: (_) => setState(() {
                          _amountError = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _currencyController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 3,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Currency',
                          hintText: 'USD',
                          counterText: '',
                          errorText: _currencyError,
                        ),
                        onChanged: (_) => setState(() {
                          _currencyError = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<BillingCycle>(
                  initialValue: _cycle,
                  decoration: const InputDecoration(labelText: 'Billing cycle'),
                  items: [
                    for (final cycle in BillingCycle.values)
                      DropdownMenuItem(
                        value: cycle,
                        child: Text(
                          cycle.name[0].toUpperCase() + cycle.name.substring(1),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _cycle = value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Next charge date',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _nextChargeDate != null
                                ? formatDay(_nextChargeDate!)
                                : 'No date',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (_nextChargeDate != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _nextChargeDate = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear date',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
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
                        onPressed: _isValid ? _save : _validate,
                        child: Text(existing != null ? 'Save' : 'Create'),
                      ),
                    ),
                  ],
                ),
                if (existing != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (existing.status == SubscriptionStatus.active)
                    TextButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const SubscriptionEditorResult.cancelSubscription()),
                      icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                      label: const Text('Cancel subscription'),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const SubscriptionEditorResult.delete()),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
