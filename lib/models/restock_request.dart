import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// Line item embedded in a `restock_requests` document's `items` array.
class RestockRequestItem {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int? receivedQuantity;
  final double estimatedUnitCost;

  const RestockRequestItem({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    this.receivedQuantity,
    required this.estimatedUnitCost,
  });

  factory RestockRequestItem.fromMap(Map<String, dynamic> map) => RestockRequestItem(
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        requestedQuantity: asInt(map['requestedQuantity']),
        receivedQuantity: map['receivedQuantity'] == null ? null : asInt(map['receivedQuantity']),
        estimatedUnitCost: asDouble(map['estimatedUnitCost']),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'requestedQuantity': requestedQuantity,
        'receivedQuantity': receivedQuantity,
        'estimatedUnitCost': estimatedUnitCost,
      };
}

/// `restock_requests` collection — merchant -> supplier restocking workflow.
class RestockRequest {
  final String id;
  final String merchantId;
  final String storeId;
  final String storeName;
  final String supplierId;
  final String supplierName;
  final List<RestockRequestItem> items;
  final RestockStatus status;
  final String? rejectionReason;
  final DateTime? estimatedDeliveryDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestockRequest({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.storeName,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.status,
    this.rejectionReason,
    this.estimatedDeliveryDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get estimatedTotal =>
      items.fold(0, (sum, i) => sum + (i.estimatedUnitCost * i.requestedQuantity));

  factory RestockRequest.fromMap(String id, Map<String, dynamic> map) => RestockRequest(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        supplierId: map['supplierId'] ?? '',
        supplierName: map['supplierName'] ?? '',
        items: ((map['items'] as List?) ?? const [])
            .map((e) => RestockRequestItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        status: RestockStatusX.fromName(map['status'] ?? 'draft'),
        rejectionReason: map['rejectionReason'],
        estimatedDeliveryDate: tsToDate(map['estimatedDeliveryDate']),
        notes: map['notes'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'storeName': storeName,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((e) => e.toMap()).toList(),
        'status': status.name,
        'rejectionReason': rejectionReason,
        'estimatedDeliveryDate': estimatedDeliveryDate,
        'notes': notes,
      };
}

/// `supplier_deliveries` collection — created when a request is dispatched;
/// merchant confirms receipt here, which triggers the stock-in Cloud
/// Function (inventory only increases after this confirmation).
class SupplierDelivery {
  final String id;
  final String restockRequestId;
  final String merchantId;
  final String storeId;
  final String supplierId;
  final RestockStatus status;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? confirmedAt;
  final String? confirmedByUserId;
  final String? trackingNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierDelivery({
    required this.id,
    required this.restockRequestId,
    required this.merchantId,
    required this.storeId,
    required this.supplierId,
    required this.status,
    this.dispatchedAt,
    this.deliveredAt,
    this.confirmedAt,
    this.confirmedByUserId,
    this.trackingNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierDelivery.fromMap(String id, Map<String, dynamic> map) => SupplierDelivery(
        id: id,
        restockRequestId: map['restockRequestId'] ?? '',
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        supplierId: map['supplierId'] ?? '',
        status: RestockStatusX.fromName(map['status'] ?? 'dispatched'),
        dispatchedAt: tsToDate(map['dispatchedAt']),
        deliveredAt: tsToDate(map['deliveredAt']),
        confirmedAt: tsToDate(map['confirmedAt']),
        confirmedByUserId: map['confirmedByUserId'],
        trackingNotes: map['trackingNotes'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'restockRequestId': restockRequestId,
        'merchantId': merchantId,
        'storeId': storeId,
        'supplierId': supplierId,
        'status': status.name,
        'dispatchedAt': dispatchedAt,
        'deliveredAt': deliveredAt,
        'confirmedAt': confirmedAt,
        'confirmedByUserId': confirmedByUserId,
        'trackingNotes': trackingNotes,
      };
}
