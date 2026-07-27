class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? 'Item',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final String? specialInstructions;
  final List<OrderItem> items;
  final DateTime createdAt;
  final double customerTrustScore;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.specialInstructions,
    required this.items,
    required this.createdAt,
    this.customerTrustScore = 100.0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      status: json['status'] ?? 'unknown',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      specialInstructions: json['specialInstructions'],
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      customerTrustScore: (json['customerTrustScore'] ?? 100.0).toDouble(),
    );
  }
}
