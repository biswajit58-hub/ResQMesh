class RescueTeam {
  const RescueTeam({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.unitType,
    required this.status,
    required this.capabilities,
    this.isDemo = false,
    this.contact = '',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String unitType;
  final String status;
  final List<String> capabilities;
  final bool isDemo;
  final String contact;
}
