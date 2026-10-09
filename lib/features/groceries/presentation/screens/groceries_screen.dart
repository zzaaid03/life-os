/// The groceries screen. Placeholder seam so the route and the home card can
/// be built in parallel; Lane A replaces the body.
library;

import 'package:flutter/material.dart';

/// Shows the grocery list.
class GroceriesScreen extends StatelessWidget {
  /// Creates a [GroceriesScreen].
  const GroceriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groceries')),
      body: const SizedBox.shrink(),
    );
  }
}
