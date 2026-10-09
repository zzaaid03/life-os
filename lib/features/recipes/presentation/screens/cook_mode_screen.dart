/// Cook mode. Placeholder seam; Lane C replaces the body.
library;

import 'package:flutter/material.dart';

/// Walks the user through cooking a recipe.
class CookModeScreen extends StatelessWidget {
  /// Creates a [CookModeScreen]. [args] is GoRouter's `extra` and is
  /// expected to be a `CookModeArgs`, but may be null after a web refresh.
  const CookModeScreen({super.key, this.args});

  /// Untyped on purpose, see `recipe_routes.dart`.
  final Object? args;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
