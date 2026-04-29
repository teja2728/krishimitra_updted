class FeedbackEntry {
  final String mobile;
  final String message;
  final DateTime createdAt;

  const FeedbackEntry({
    required this.mobile,
    required this.message,
    required this.createdAt,
  });

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    return FeedbackEntry(
      mobile: (json['mobile'] ?? json['mobile'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mobile': mobile,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };
}

