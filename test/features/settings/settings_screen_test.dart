import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/data/repositories/auth_repository.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/google_credentials_repository.dart';
import 'package:life_os/features/profile/data/repositories/profile_repository.dart';
import 'package:life_os/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:life_os/features/recipes/data/repositories/recipe_repository.dart';
import 'package:life_os/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthRepo extends Fake implements AuthRepository {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthState> getCurrentAuthState() async => const AuthState();
}

class _ProfileRepo extends Fake implements ProfileRepository {}

class _FoodRepo extends Fake implements FoodPreferencesRepository {}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings still renders when the gmail check throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProviderOverride.overrideWithValue(_AuthRepo()),
          profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
          foodPreferencesRepositoryProvider.overrideWithValue(_FoodRepo()),
          gmailConnectedProvider.overrideWith(
            (ref) => throw Exception('google_connected failed'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Gmail access'), findsNothing);
  });
}
