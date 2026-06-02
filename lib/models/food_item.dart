/// 食物模型
class FoodItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  final String? description;

  FoodItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'category': category,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem.fromMap(json);

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String?,
      description: map['description'] as String?,
    );
  }

  @override
  String toString() => 'FoodItem{name: $name, category: $category}';
}
