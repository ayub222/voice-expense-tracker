class WaUser {
  final int id;
  final String name;
  final String whatsappNumber;
  final String whatsappDisplay;
  final bool isActive;
  final String createdAt;

  const WaUser({
    required this.id,
    required this.name,
    required this.whatsappNumber,
    required this.whatsappDisplay,
    required this.isActive,
    required this.createdAt,
  });

  factory WaUser.fromJson(Map<String, dynamic> json) {
    final rawActive = json['is_active'];
    final active = rawActive == true || rawActive == 1 || rawActive == '1';
    return WaUser(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? 'Pengguna').toString(),
      whatsappNumber: (json['whatsapp_number'] ?? '').toString(),
      whatsappDisplay:
          (json['whatsapp_display'] ?? json['whatsapp_number'] ?? '').toString(),
      isActive: active,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
