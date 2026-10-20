/// Cook mode: a full-screen, step-by-step walk through a recipe, built for
/// messy hands at the stove (big text, big targets, the screen kept awake).
///
/// Pages: "Get ready" (mise en place), one page per step, then the finish.
/// Timers are app-wide (`cookTimersProvider`), so leaving cook mode only
/// stops them when the user says so.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/notifications/domain/providers/notification_service_provider.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:life_os/features/recipes/presentation/recipe_routes.dart';
import 'package:life_os/features/recipes/presentation/sheets/ask_chef_sheet.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_bottom_bar.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_finish_page.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_palette.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_progress_bar.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_step_page.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/mise_en_place_page.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/timers/active_timers_bar.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/timers/timer_alert_listener.dart';
import 'package:life_os/features/recipes/presentation/widgets/recipe_hero_badge.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Walks the user through cooking a recipe.
class CookModeScreen extends StatelessWidget {
  /// Creates a [CookModeScreen]. [args] is GoRouter's `extra` and is
  /// expected to be a `CookModeArgs`, but may be null after a web refresh.
  const CookModeScreen({super.key, this.args});

  /// Untyped on purpose, see `recipe_routes.dart`.
  final Object? args;

  @override
  Widget build(BuildContext context) {
    final args = this.args;
    if (args is! CookModeArgs) return const _RecipeNotFound();
    return _CookModeView(args: args);
  }
}

/// Leaving cook mode while timers run.
enum _LeaveChoice { keep, stop }

class _CookModeView extends ConsumerStatefulWidget {
  const _CookModeView({required this.args});

  final CookModeArgs args;

  @override
  ConsumerState<_CookModeView> createState() => _CookModeViewState();
}

class _CookModeViewState extends ConsumerState<_CookModeView> {
  static const _pageDuration = Duration(milliseconds: 420);

  final _pages = PageController();
  final _checked = <int>{};
  int _page = 0;

  bool _readAloud = false;
  FlutterTts? _tts;

  /// Set before the first `markCooked` call so it can never run twice.
  bool _cookRecorded = false;
  int? _timesCooked;
  CookSaveState _saveState = CookSaveState.idle;

  bool _askedPermission = false;
  bool _leaveDialogOpen = false;

  Recipe get _recipe => widget.args.recipe;
  int get _stepCount => _recipe.steps.length;
  int get _lastPage => _stepCount + 1;

  /// The step on screen, or null on the mise en place and finish pages.
  int? get _stepIndex => _page >= 1 && _page <= _stepCount ? _page - 1 : null;

  @override
  void initState() {
    super.initState();
    unawaited(_quietly(WakelockPlus.enable));
  }

  @override
  void dispose() {
    unawaited(_quietly(WakelockPlus.disable));
    _stopSpeaking();
    _pages.dispose();
    super.dispose();
  }

  /// Runs a platform call that must never break cook mode.
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {}
  }

  // --- Navigation ---

  void _goTo(int page) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      page.clamp(0, _lastPage),
      duration: _pageDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _stopSpeaking();
    if (_readAloud) _speakCurrentStep();
    if (page == _lastPage) unawaited(_recordCook());
  }

  // --- Read aloud ---

  void _setReadAloud(bool on) {
    setState(() => _readAloud = on);
    if (on) {
      _speakCurrentStep();
    } else {
      _stopSpeaking();
    }
  }

  void _speakCurrentStep() {
    final i = _stepIndex;
    if (i != null) unawaited(_speak(_recipe.steps[i].text));
  }

  Future<void> _speak(String text) async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      await tts.speak(text);
    } catch (_) {}
  }

  void _stopSpeaking() {
    final tts = _tts;
    if (tts != null) unawaited(_quietly(tts.stop));
  }

  // --- Timers ---

  bool _isMine(CookTimer t) => t.recipeTitle == _recipe.title;

  bool _hasRunningTimers() => ref.read(cookTimersProvider).any((t) => _isMine(t) && t.isRunning);

  void _cancelMyTimers() {
    final notifier = ref.read(cookTimersProvider.notifier);
    for (final t in ref.read(cookTimersProvider).where(_isMine).toList()) {
      notifier.cancel(t.id);
    }
  }

  /// Asks for notification permission the first time one of this recipe's
  /// timers starts, so the alarm is heard with the phone locked.
  void _onTimersChanged(List<CookTimer>? previous, List<CookTimer> next) {
    if (_askedPermission || kIsWeb) return;
    final runningBefore = {
      for (final t in previous ?? const <CookTimer>[])
        if (t.isRunning) t.id,
    };
    final started = next.any((t) => _isMine(t) && t.isRunning && !runningBefore.contains(t.id));
    if (!started) return;
    _askedPermission = true;
    final service = ref.read(notificationServiceProvider);
    unawaited(_quietly(service.requestPermission));
  }

  // --- Finish ---

  Future<void> _recordCook() async {
    final id = widget.args.savedId;
    if (_cookRecorded || id == null) return;
    // Null while the saved list is still loading; the listener in build
    // calls this again once the row arrives.
    final saved = ref.read(savedRecipeByIdProvider(id));
    if (saved == null) return;
    _cookRecorded = true;
    try {
      final updated = await ref.read(savedRecipesProvider.notifier).markCooked(saved);
      if (mounted) setState(() => _timesCooked = updated.timesCooked);
    } catch (e) {
      debugPrint('markCooked failed: $e');
      _snack("Couldn't save that you cooked this.");
    }
  }

  Future<void> _save() async {
    setState(() => _saveState = CookSaveState.saving);
    try {
      final notifier = ref.read(savedRecipesProvider.notifier);
      final saved = await notifier.save(_recipe);
      if (mounted) setState(() => _saveState = CookSaveState.saved);
      // Saved from the finish page, so it was just cooked: count it, or a
      // recipe you have made reads "Cooked 0 times" next time.
      // Its own guard: a failure here must not report the save as failed.
      try {
        final updated = await notifier.markCooked(saved);
        if (mounted) setState(() => _timesCooked = updated.timesCooked);
      } catch (e) {
        debugPrint('markCooked failed: $e');
        _snack("Couldn't save that you cooked this.");
      }
    } catch (e) {
      debugPrint('Recipe save failed: $e');
      if (!mounted) return;
      setState(() => _saveState = CookSaveState.idle);
      _snack("Couldn't save the recipe. Try again.");
    }
  }

  void _done() {
    _cancelMyTimers();
    _exit();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Leaving ---

  Future<void> _requestLeave() async {
    if (_leaveDialogOpen) return;
    if (!_hasRunningTimers()) {
      _exit();
      return;
    }
    _leaveDialogOpen = true;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timers are still running'),
        content: const Text(
          'Keep them going in the background, or stop them before you leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.stop),
            child: const Text('Stop timers'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.keep),
            child: const Text('Keep timers running'),
          ),
        ],
      ),
    );
    _leaveDialogOpen = false;
    if (!mounted || choice == null) return;
    if (choice == _LeaveChoice.stop) _cancelMyTimers();
    _exit();
  }

  /// Pops directly, past the [PopScope] (the choice has been made).
  void _exit() {
    _stopSpeaking();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final args = widget.args;
    final palette = CookPalette.of(context, recipe);
    final hasRunning = ref.watch(
      cookTimersProvider.select((ts) => ts.any((t) => _isMine(t) && t.isRunning)),
    );

    ref.listen<List<CookTimer>>(cookTimersProvider, _onTimersChanged);
    final savedId = args.savedId;
    if (savedId != null) {
      ref.listen<SavedRecipe?>(savedRecipeByIdProvider(savedId), (_, next) {
        if (next != null && _page == _lastPage) unawaited(_recordCook());
      });
    }

    final onFinish = _page == _lastPage;

    return TimerAlertListener(
      recipeTitle: recipe.title,
      onAnnounce: (sentence) {
        if (_readAloud) unawaited(_speak(sentence));
      },
      child: PopScope(
        canPop: !hasRunning,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_requestLeave());
        },
        child: Scaffold(
          backgroundColor: palette.backgroundBottom,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.backgroundTop, palette.backgroundBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    recipe: recipe,
                    heroTag: args.heroTag,
                    palette: palette,
                    pageCount: _lastPage + 1,
                    page: _page,
                    onClose: () => unawaited(_requestLeave()),
                  ),
                  ActiveTimersBar(
                    recipeTitle: recipe.title,
                    currentStepIndex: _stepIndex,
                    onJumpToStep: (i) => _goTo(i + 1),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _lastPage + 1,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, page) {
                        if (page == 0) {
                          return MiseEnPlacePage(
                            recipe: recipe,
                            servings: args.servings,
                            palette: palette,
                            checked: _checked,
                            onToggle: (i) => setState(() {
                              if (!_checked.remove(i)) _checked.add(i);
                            }),
                            onReady: () => _goTo(1),
                          );
                        }
                        if (page == _lastPage) {
                          return CookFinishPage(
                            recipe: recipe,
                            palette: palette,
                            isSaved: savedId != null,
                            timesCooked: _timesCooked,
                            saveState: _saveState,
                            onSave: () => unawaited(_save()),
                            onDone: _done,
                          );
                        }
                        return CookStepPage(
                          recipe: recipe,
                          stepIndex: page - 1,
                          servings: args.servings,
                          palette: palette,
                        );
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: onFinish
                        ? const SizedBox(width: double.infinity)
                        : CookBottomBar(
                            palette: palette,
                            readAloud: _readAloud,
                            onReadAloudChanged: _setReadAloud,
                            onAskChef: () => unawaited(
                              AskChefSheet.show(context, recipe: recipe, stepIndex: _stepIndex),
                            ),
                            onBack: _page == 0 ? null : () => _goTo(_page - 1),
                            onNext: () => _goTo(_page + 1),
                            nextLabel: _page == _stepCount ? 'Finish' : 'Next',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.recipe,
    required this.heroTag,
    required this.palette,
    required this.pageCount,
    required this.page,
    required this.onClose,
  });

  final Recipe recipe;
  final String heroTag;
  final CookPalette palette;
  final int pageCount;
  final int page;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                tooltip: 'Close cook mode',
                iconSize: 30,
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: AppSpacing.xs),
              RecipeHeroBadge(recipe: recipe, heroTag: heroTag, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  recipe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: CookProgressBar(
              count: pageCount,
              current: page,
              fill: palette.accent,
              track: palette.track,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeNotFound extends StatelessWidget {
  const _RecipeNotFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍳', style: TextStyle(fontSize: 56)),
                const SizedBox(height: AppSpacing.lg),
                Text('Recipe not found', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Open it again from your recipes to start cooking.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                    ),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                    child: const Text('Go back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
