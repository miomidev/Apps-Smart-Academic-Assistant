class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? university;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.university,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      firebaseUid: json['firebaseUid'] as String? ?? json['firebase_uid'] as String? ?? '',
      email: json['email'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      university: json['university'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'university': university,
      'timezone': timezone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? name,
    String? photoUrl,
    String? university,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      university: university ?? this.university,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
