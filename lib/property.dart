  


  class _Property {
  final String? id;
  final String title;
  final String type;
  final String location;
  final int priceNumber;

  _Property({
    this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.priceNumber,
  });

  factory _Property.fromMap(Map<String, dynamic> map) {
    return _Property(
      id: map['id'],
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      location: map['location'] ?? '',
      priceNumber: map['priceNumber'] ?? 0,
    );
  }
}
