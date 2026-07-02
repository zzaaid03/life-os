/// Profile creation screen.
///
/// The first screen after authentication for new users.
/// Asks only one question: "What should Life call you?"
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/profile/data/models/profile.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing display name if available (Google users)
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authProvider);
      final userId = authState.userId;
      if (userId == null) {
        throw StateError('User ID not found');
      }

      final provider = authState.email != null
          ? AuthProvider.email
          : AuthProvider.google;

      final profile = Profile(
        id: userId,
        displayName: _nameController.text.trim(),
        email: authState.email,
        provider: provider,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(profileProvider.notifier).upsertProfile(profile);

      if (mounted) {
        setState(() => _isLoading = false);
        context.go(AppRoutes.permissionNotifications);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save profile. $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.massive),
                // Progress indicator
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const Spacer(),
                // Question
                Text(
                  'What should\nLife call you?',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                const SizedBox(height: AppSpacing.xxl),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleContinue(),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    hintText: 'e.g. Zaid',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tell Life your name';
                    }
                    if (value.trim().length < 2) {
                      return 'That name seems too short';
                    }
                    return null;
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
