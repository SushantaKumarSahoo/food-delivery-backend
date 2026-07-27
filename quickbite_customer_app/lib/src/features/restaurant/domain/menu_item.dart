class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? (json['base_price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? '',
    );
  }
}
