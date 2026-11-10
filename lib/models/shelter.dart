import 'enums.dart';

class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.capacity,
    required this.occupancy,
    required this.updatedAt,
    this.address = '',
    this.source = 'local',
    this.phone = '',
    this.notes = '',
    this.isDemo = false,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final ShelterStatus status;
  final int capacity;
  final int occupancy;
  final DateTime updatedAt;
  final String address;
  final String source;
  final String phone;
  final String notes;
  final bool isDemo;

  int get available => (capacity - occupancy).clamp(0, capacity);
  double get occupancyRatio =>
      capacity <= 0 ? 0 : (occupancy / capacity).clamp(0, 1);

  bool get hasCapacity => status == ShelterStatus.open && available > 0;

  Shelter copyWith({
    String? name,
    ShelterStatus? status,
    int? capacity,
    int? occupancy,
    DateTime? updatedAt,
    String? address,
    String? phone,
    String? notes,
  }) =>
      Shelter(
        id: id,
        name: name ?? this.name,
        latitude: latitude,
        longitude: longitude,
        status: status ?? this.status,
        capacity: capacity ?? this.capacity,
        occupancy: occupancy ?? this.occupancy,
        updatedAt: updatedAt ?? this.updatedAt,
        address: address ?? this.address,
        source: source,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        isDemo: isDemo,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'status': status.wire,
        'capacity': capacity,
        'occupancy': occupancy,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
        'address': address,
        'source': source,
        'phone': phone,
        'notes': notes,
        'is_demo': isDemo ? 1 : 0,
      };

  factory Shelter.fromMap(Map<String, Object?> map) => Shelter(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Shelter',
        latitude: (map['lat'] as num?)?.toDouble() ?? 0,
        longitude: (map['lng'] as num?)?.toDouble() ?? 0,
        status: ShelterStatus.fromWire(map['status'] as String?),
        capacity: (map['capacity'] as num?)?.toInt() ?? 0,
        occupancy: (map['occupancy'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        address: map['address'] as String? ?? '',
        source: map['source'] as String? ?? 'local',
        phone: map['phone'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        isDemo: ((map['is_demo'] as num?)?.toInt() ?? 0) == 1,
      );
}
