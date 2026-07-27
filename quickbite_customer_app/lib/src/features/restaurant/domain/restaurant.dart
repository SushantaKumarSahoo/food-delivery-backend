class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double rating;
  final int deliveryTimeMinutes;
  final double deliveryFee;
  final String type;
  final List<String> tags;
  final bool isSponsored;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.rating,
    required this.deliveryTimeMinutes,
    required this.deliveryFee,
    this.type = 'Food',
    this.tags = const [],
    this.isSponsored = false,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      deliveryTimeMinutes: json['delivery_time_minutes'] as int? ?? 30,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'Food',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isSponsored: json['isSponsored'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'rating': rating,
      'delivery_time_minutes': deliveryTimeMinutes,
      'delivery_fee': deliveryFee,
      'type': type,
      'tags': tags,
      'isSponsored': isSponsored,
    };
  }
}
