class Vertical {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? icon;

  Vertical({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.icon,
  });

  factory Vertical.fromJson(Map<String, dynamic> json) {
    return Vertical(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}
