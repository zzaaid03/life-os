/// The recipe page. Placeholder seam; Lane B replaces the body.
library;

import 'package:flutter/material.dart';

/// Shows one recipe.
class RecipeDetailScreen extends StatelessWidget {
  /// Creates a [RecipeDetailScreen]. [args] is GoRouter's `extra` and is
  /// expected to be a `RecipeViewArgs`, but may be null after a web refresh.
  const RecipeDetailScreen({super.key, this.args});

  /// Untyped on purpose, see `recipe_routes.dart`.
  final Object? args;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
