import '../core/utils/firestore_helpers.dart';

/// `product_categories` collection — admin-managed global category list.
class ProductCategory {
  final String id;
  final String name;
  final String? iconName;
  final bool active;
  final DateTime createdAt;

  const ProductCategory({
    required this.id,
    required this.name,
    this.iconName,
    this.active = true,
    required this.createdAt,
  });

  factory ProductCategory.fromMap(String id, Map<String, dynamic> map) => ProductCategory(
        id: id,
        name: map['name'] ?? '',
        iconName: map['iconName'],
        active: map['active'] ?? true,
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {'name': name, 'iconName': iconName, 'active': active};
}
