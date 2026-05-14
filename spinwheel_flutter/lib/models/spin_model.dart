// ============================================================
// models/spin_model.dart
// Selaras dengan struktur tabel "spins" di Supabase
// Kolom: id, user_id, options (array), result, created_at
// ============================================================

class SpinModel {
  final String id;
  final String userId;
  final List<String> options;
  final String result;
  final DateTime createdAt;

  SpinModel({
    required this.id,
    required this.userId,
    required this.options,
    required this.result,
    required this.createdAt,
  });

  factory SpinModel.fromJson(Map<String, dynamic> json) {
    return SpinModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : [],
      result: json['result']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'options': options,
        'result': result,
        'created_at': createdAt.toIso8601String(),
      };
}
