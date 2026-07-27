class CartItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Item',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? '',
    );
  }
}

class Cart {
  final String id;
  final List<CartItem> items;
  final double itemTotal;
  final double deliveryFee;
  final double taxes;
  final double total;

  Cart({
    required this.id,
    required this.items,
    required this.itemTotal,
    required this.deliveryFee,
    required this.taxes,
    required this.total,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List<dynamic>? ?? [];
    List<CartItem> parsedItems = itemsList.map((i) => CartItem.fromJson(i)).toList();
    
    return Cart(
      id: json['id']?.toString() ?? '',
      items: parsedItems,
      itemTotal: (json['item_total'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
