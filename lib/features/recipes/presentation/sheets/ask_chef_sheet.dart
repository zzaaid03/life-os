/// "Ask the chef" bottom sheet: a short question and answer thread about
/// the recipe on screen. The thread lives only as long as the sheet.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/recipe_chef_service.dart';
import 'package:life_os/features/recipes/presentation/sheets/chef_sheet_parts.dart';

/// A mid-cook question to the chef about this recipe.
abstract final class AskChefSheet {
  /// Shows the sheet for [recipe]. [stepIndex] is the step on screen, or
  /// null before the steps (mise en place).
  static Future<void> show(
    BuildContext context, {
    required Recipe recipe,
    int? stepIndex,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (_) => _AskChefBody(recipe: recipe, stepIndex: stepIndex),
    );
  }
}

/// Starter chips. An incomplete one (ending in an ellipsis) fills the field
/// so the user can finish it; a complete one sends straight away.
const _starters = [
  ('What can I use instead of…?', false),
  ('How do I know it\'s done?', true),
  ('I burnt it a bit, what now?', true),
  ('Can I make this ahead?', true),
];

class _Message {
  _Message.user(this.text) : fromUser = true, error = false;
  _Message.chef(this.text) : fromUser = false, error = false;
  _Message.error(this.text, this.question) : fromUser = false, error = true;

  final String text;
  final bool fromUser;
  final bool error;

  /// For an error, the question to retry.
  String? question;
}

class _AskChefBody extends ConsumerStatefulWidget {
  const _AskChefBody({required this.recipe, this.stepIndex});

  final Recipe recipe;
  final int? stepIndex;

  @override
  ConsumerState<_AskChefBody> createState() => _AskChefBodyState();
}

class _AskChefBodyState extends ConsumerState<_AskChefBody> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  bool _waiting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _fillStarter(String text) {
    // Drop the trailing ellipsis and question mark so the user types the
    // ingredient straight after "instead of ".
    final stem = text.replaceAll('…?', ' ');
    _controller.value = TextEditingValue(
      text: stem,
      selection: TextSelection.collapsed(offset: stem.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _controller.text).trim();
    if (question.isEmpty || _waiting) return;
    if (text == null) _controller.clear();
    setState(() {
      _messages.add(_Message.user(question));
      _waiting = true;
    });
    _scrollToEnd();
    await _ask(question);
  }

  Future<void> _retry(_Message failed) async {
    final question = failed.question;
    if (question == null || _waiting) return;
    setState(() {
      _messages.remove(failed);
      _waiting = true;
    });
    _scrollToEnd();
    await _ask(question);
  }

  Future<void> _ask(String question) async {
    _Message reply;
    try {
      final answer = await ref
          .read(recipeChefServiceProvider)
          .ask(widget.recipe, question, stepIndex: widget.stepIndex);
      reply = _Message.chef(answer);
    } on RecipeChefException catch (e) {
      reply = _Message.error(e.message, question);
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _waiting = false;
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final step = widget.stepIndex;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: math.max(
          200,
          math.min(
            media.size.height * 0.75,
            media.size.height - media.viewInsets.bottom - media.padding.top - 56,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask the chef',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    step == null
                        ? widget.recipe.title
                        : '${widget.recipe.title} · About step ${step + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _messages.isEmpty && !_waiting
                  ? _buildStarters(context)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: _messages.length + (_waiting ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _messages.length) {
                          return const _ChefRow(child: _TypingIndicator());
                        }
                        final m = _messages[i];
                        if (m.fromUser) return _UserBubble(text: m.text);
                        if (m.error) {
                          return _ChefRow(
                            child: _ErrorBubble(
                              message: m.text,
                              onRetry: () => _retry(m),
                            ),
                          );
                        }
                        return _ChefRow(child: _ChefBubble(text: m.text));
                      },
                    ),
            ),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStarters(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Text('👨‍🍳', style: TextStyle(fontSize: 44))
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stuck on something? Ask away.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (i, (label, complete)) in _starters.indexed)
                ActionChip(
                  label: Text(label),
                  onPressed: () => complete ? _send(label) : _fillStarter(label),
                )
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (80 + 50 * i).ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _controller.text.trim().isNotEmpty && !_waiting;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask about this recipe',
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.xxl),
                  ),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            onPressed: canSend ? _send : null,
            icon: const Icon(Icons.arrow_upward_rounded),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(
          left: AppSpacing.huge,
          bottom: AppSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.lg),
            bottomRight: Radius.circular(AppRadius.xs),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.15, end: 0);
  }
}

/// A chef avatar followed by [child], aligned left.
class _ChefRow extends StatelessWidget {
  const _ChefRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.huge,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: const Text('👨‍🍳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: child),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.15, end: 0);
  }
}

BoxDecoration _chefBubbleDecoration(ThemeData theme, {Color? color}) {
  return BoxDecoration(
    color: color ?? theme.colorScheme.surfaceContainerHighest,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(AppRadius.lg),
      topRight: Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(AppRadius.xs),
      bottomRight: Radius.circular(AppRadius.lg),
    ),
  );
}

class _ChefBubble extends StatelessWidget {
  const _ChefBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: _chefBubbleDecoration(theme),
      child: SelectableText(text, style: theme.textTheme.bodyMedium),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: _chefBubbleDecoration(
            theme,
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "I couldn't answer that",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ChefRawMessage(
                message: message,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    'Tap to try again',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots bouncing in turn while the chef thinks.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: _chefBubbleDecoration(theme),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            )
                // Same 600ms cycle for every dot; only the start is offset,
                // so they stay in step forever.
                .animate(
                  delay: (150 * i).ms,
                  onPlay: (c) => c.repeat(reverse: true),
                )
                .moveY(begin: 2, end: -4, duration: 300.ms, curve: Curves.easeInOut)
                .fade(begin: 0.4, end: 1, duration: 300.ms),
        ],
      ),
    );
  }
}
