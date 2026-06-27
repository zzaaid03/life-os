/// Forgot password screen.
///
/// Allows users to request a password reset email.
/// Shows clear success and error states.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_icons.dart';

import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/auth/presentation/widgets/auth_error_banner.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) setState(() => _isSent = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to send reset email. Please check your email address.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(AppIcons.back),
                    tooltip: 'Back',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_isSent) ...[
                  // Success state
                  const Icon(
                    Icons.mark_email_read_rounded,
                    size: 56,
                    color: AppColors.success,
                  ).animate().scale(duration: 400.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Check your email',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'We sent a password reset link to\n${_emailController.text.trim()}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  const SizedBox(height: AppSpacing.xxxl),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to Sign In'),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ] else ...[
                  Text(
                    'Reset password',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter your email and we\'ll send you a reset link.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  const SizedBox(height: AppSpacing.xxxl),
                  if (_errorMessage != null) ...[
                    AuthErrorBanner(
                      message: _errorMessage!,
                    ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    onFieldSubmitted: (_) => _handleReset(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(AppIcons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your email address';
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleReset,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
