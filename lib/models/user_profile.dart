class UserProfile {
  final String id;
  final String mobile;
  final String name;
  final String state;
  final String language;
  final List<String> crops;
  final String soilType; // Black / Red
  final int landSize;
  final String role;
  final String status;
  final bool isOnline;
  final DateTime? lastSeen;
  final String suspensionReason;
  final DateTime? deletedAt;
  final String deviceType;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.mobile,
    required this.name,
    required this.state,
    required this.language,
    required this.crops,
    required this.soilType,
    required this.landSize,
    required this.role,
    this.status = 'ACTIVE',
    this.isOnline = false,
    this.lastSeen,
    this.suspensionReason = '',
    this.deletedAt,
    this.deviceType = '',
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      language: (json['language'] ?? '').toString(),
      crops: (json['crops'] as List? ?? const []).map((e) => e.toString()).toList(),
      soilType: (json['soilType'] ?? '').toString(),
      landSize: int.tryParse((json['landSize'] ?? '0').toString()) ?? 0,
      role: (json['role'] ?? 'user').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
      suspensionReason: (json['suspensionReason'] ?? '').toString(),
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      deviceType: (json['deviceType'] ?? '').toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mobile': mobile,
        'name': name,
        'state': state,
        'language': language,
        'crops': crops,
        'soilType': soilType,
        'landSize': landSize,
        'role': role,
        'status': status,
        'isOnline': isOnline,
        'suspensionReason': suspensionReason,
        'deviceType': deviceType,
      };
}

class UserAuthData {
  final String mobile;
  final String password;
  final UserProfile profile;

  const UserAuthData({
    required this.mobile,
    required this.password,
    required this.profile,
  });

  factory UserAuthData.fromJson(Map<String, dynamic> json) {
    return UserAuthData(
      mobile: (json['mobile'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      profile: UserProfile.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
        'mobile': mobile,
        'password': password,
        ...profile.toJson(),
      };
}
