/// Privacy policy screen.
///
/// Reachable with no account (see the router's redirect rule for
/// [AppRoutes.privacy]): a Google OAuth reviewer or anyone else checking
/// the app before signing in needs to reach this without one. Static
/// content only, no providers.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Life OS Privacy Policy',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Last updated 8 August 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _Section(
                title: 'What Life OS is',
                body:
                    'Life OS is a personal task and life management app built '
                    'and run by one developer, not a company. This policy '
                    'describes what data the app collects and what happens '
                    'to it in plain language.',
              ),
              const _Section(
                title: 'Account information',
                body:
                    'When you create an account, we store your email address '
                    'and the display name you choose. If you sign in with '
                    'Google, we receive your name and email from Google, '
                    'nothing more.',
              ),
              const _Section(
                title: 'What you create in the app',
                body:
                    'Tasks, goals, job applications, and any notes you add to '
                    'them are stored so the app can show them back to you. '
                    'You can edit or delete any of these at any time from '
                    'within the app.',
              ),
              const _Section(
                title: 'Gmail inbox scanning',
                body:
                    'If you connect Gmail, Life OS reads a batch of your '
                    'inbox emails, whatever they are about, and sends their '
                    'content to a third-party AI service to look for tasks, '
                    'bills, appointments, deliveries, and job-application '
                    'updates. Only what the AI extracts, a task title, a '
                    'date, a status, is saved. The email content itself is '
                    'never stored anywhere, and each email is only ever sent '
                    'once. Gmail access is read-only: Life OS cannot send, '
                    'delete, or modify anything in your inbox.',
              ),
              const _Section(
                title: 'Files you upload',
                body:
                    'Uploaded files are stored privately and are never '
                    'visible to other users. Each file has a "private, never '
                    'send to AI" option. For files you don\'t mark private, '
                    'a short note you write about the file, never the file '
                    'itself, is sent to the same AI service so you can find '
                    'it later by searching.',
              ),
              const _Section(
                title: 'What Life OS learns about you',
                body:
                    'The app may infer general facts about your habits or '
                    'lifestyle from your own tasks, goals, and job '
                    'applications, to make its suggestions more relevant. '
                    'These are shown to you in Settings under "What Life '
                    'knows about you," and you can reject any fact you '
                    'think is wrong at any time.',
              ),
              const _Section(
                title: 'Who else sees your data',
                body:
                    'Life OS does not sell your data, and does not show ads '
                    'or use any advertising or analytics tracking. Data is '
                    'processed by two outside services strictly to run the '
                    'app: Google (for sign-in and, if connected, reading '
                    'your inbox) and Groq (an AI provider that processes '
                    'email content, file notes, and your own data to '
                    'generate the tasks and suggestions described above). '
                    'Your data is stored with Supabase, our database and '
                    'file storage provider.',
              ),
              const _Section(
                title: 'Deleting your data',
                body:
                    'You can delete any task, goal, job application, or file '
                    'yourself at any time. To delete your account and every '
                    'record tied to it, contact us at the email below and '
                    'we will remove it.',
              ),
              const _Section(
                title: 'Children',
                body:
                    'Life OS is not directed at children under 13, and we '
                    'do not knowingly collect information from them.',
              ),
              const _Section(
                title: 'Changes to this policy',
                body:
                    'If this policy changes, we will update it on this page '
                    'and change the date at the top.',
              ),
              const _Section(
                title: 'Contact',
                body:
                    'Questions about this policy or your data, or a request '
                    'to delete your account: jarrarzaid3@gmail.com.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
