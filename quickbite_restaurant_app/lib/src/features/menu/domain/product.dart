class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String? imageUrl;
  final String categoryId;
  final String verticalId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    this.imageUrl,
    required this.categoryId,
    required this.verticalId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      isAvailable: json['isAvailable'] ?? true,
      imageUrl: json['imageUrl'],
      categoryId: json['categoryId'] ?? '',
      verticalId: json['verticalId'] ?? '',
    );
  }
}
