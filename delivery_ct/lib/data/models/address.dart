class Address {
  final int id;
  final int user;
  final String name;
  final double latitude;
  final double longitude;
  final String description;

  Address({
    required this.id,
    required this.user,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      user: json['user'],
      name: json['name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      description: json['description'],
    );
  }
}