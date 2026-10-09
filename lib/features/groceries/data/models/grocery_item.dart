/// The grocery list item model.
library;

/// One thing to buy.
class GroceryItem {
  /// Creates a [GroceryItem].
  const GroceryItem({
    required this.id,
    required this.userId,
    required this.name,
    this.quantity,
    this.checked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parses a row from `public.grocery_items`.
  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      checked: json['checked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  /// Row id.
  final String id;

  /// Owning user.
  final String userId;

  /// What to buy, e.g. "Chicken thighs".
  final String name;

  /// Free-text amount, e.g. "500 g" or "2". Null when unstated.
  final String? quantity;

  /// Whether it has been bought.
  final bool checked;

  /// When the item was added.
  final DateTime createdAt;

  /// When the item last changed.
  final DateTime updatedAt;

  /// Returns a copy with the given overrides.
  ///
  /// [clearQuantity] exists because `quantity ?? this.quantity` cannot set
  /// the field back to null.
  GroceryItem copyWith({
    String? name,
    String? quantity,
    bool clearQuantity = false,
    bool? checked,
  }) {
    return GroceryItem(
      id: id,
      userId: userId,
      name: name ?? this.name,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      checked: checked ?? this.checked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// An item that does not exist yet, used when adding one or several at once.
class GroceryDraft {
  /// Creates a [GroceryDraft].
  const GroceryDraft({required this.name, this.quantity});

  /// What to buy.
  final String name;

  /// Free-text amount, or null.
  final String? quantity;

  /// The insert payload for [userId]. Trims both fields and stores an empty
  /// quantity as null so the list never shows a blank amount.
  Map<String, dynamic> toInsertJson(String userId) {
    final q = quantity?.trim();
    return {
      'user_id': userId,
      'name': name.trim(),
      'quantity': (q == null || q.isEmpty) ? null : q,
    };
  }
}

/// Sorts for display: unchecked first, then checked, each oldest first so a
/// newly added item lands at the bottom of its group like a paper list.
List<GroceryItem> sortForDisplay(List<GroceryItem> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    if (a.checked != b.checked) return a.checked ? 1 : -1;
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}
