/// The Recipes screen: ask the AI chef for a recipe and browse saved ones.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/presentation/screens/recipes_tab.dart';

/// Hosts the recipes content under its own AppBar.
class RecipesScreen extends StatelessWidget {
  /// Creates a [RecipesScreen].
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: const RecipesTab(),
    );
  }
}
