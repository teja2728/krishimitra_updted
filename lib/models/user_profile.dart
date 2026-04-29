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
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      language: (json['language'] ?? '').toString(),
      crops: (json['crops'] as List? ?? const []).map((e) => e.toString()).toList(),
      soilType: (json['soilType'] ?? '').toString(),
      landSize: int.tryParse((json['landSize'] ?? '0').toString()) ?? 0,
      role: (json['role'] ?? 'user').toString(),
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
