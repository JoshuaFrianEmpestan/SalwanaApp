import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `products` collection. Inventory quantities live directly on the product
/// document (Firestore has no cheap cross-collection join), and every
/// change to them must go through a Cloud Function transaction that also
/// appends a record to `inventory_movements` — see functions/src/inventory.ts.
class Product {
  final String id;
  final String storeId;
  final String merchantId;
  final String name;
  final String description;
  final String category;
  final String brand;
  final List<String> imageUrls;
  final String? supplierId;
  final double costPrice;
  final double sellingPrice;
  final int currentStock;
  final int reservedStock;
  final int minStockLevel;
  final String unit;
  final String? batchNumber;
  final DateTime? expirationDate;
  final String? barcode;
  final ProductStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.storeId,
    required this.merchantId,
    required this.name,
    required this.description,
    required this.category,
    required this.brand,
    this.imageUrls = const [],
    this.supplierId,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    this.reservedStock = 0,
    required this.minStockLevel,
    this.unit = 'pc',
    this.batchNumber,
    this.expirationDate,
    this.barcode,
    this.status = ProductStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  int get availableStock => currentStock - reservedStock;
  bool get isLowStock => availableStock <= minStockLevel;
  bool get isOutOfStock => availableStock <= 0;

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        storeId: map['storeId'] ?? '',
        merchantId: map['merchantId'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        category: map['category'] ?? 'General',
        brand: map['brand'] ?? '',
        imageUrls: List<String>.from(map['imageUrls'] ?? const []),
        supplierId: map['supplierId'],
        costPrice: asDouble(map['costPrice']),
        sellingPrice: asDouble(map['sellingPrice']),
        currentStock: asInt(map['currentStock']),
        reservedStock: asInt(map['reservedStock']),
        minStockLevel: asInt(map['minStockLevel']),
        unit: map['unit'] ?? 'pc',
        batchNumber: map['batchNumber'],
        expirationDate: tsToDate(map['expirationDate']),
        barcode: map['barcode'],
        status: ProductStatusX.fromName(map['status'] ?? 'active'),
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'merchantId': merchantId,
        'name': name,
        'description': description,
        'category': category,
        'brand': brand,
        'imageUrls': imageUrls,
        'supplierId': supplierId,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'currentStock': currentStock,
        'reservedStock': reservedStock,
        'minStockLevel': minStockLevel,
        'unit': unit,
        'batchNumber': batchNumber,
        'expirationDate': expirationDate,
        'barcode': barcode,
        'status': status.name,
      };
}
