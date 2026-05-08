enum SchemeType {
  central,
  state,
}

class Scheme {
  final String id;
  final String name;
  final SchemeType type;
  final String state;
  final String category;
  final String description;
  final List<String> benefits;
  final List<String> eligibility;
  final List<String> documents;
  final String deadline;
  final String applyLink;
  final bool isAiGenerated;
  final bool approved;

  const Scheme({
    required this.id,
    required this.name,
    required this.type,
    required this.state,
    required this.category,
    required this.description,
    required this.benefits,
    required this.eligibility,
    required this.documents,
    required this.deadline,
    required this.applyLink,
    required this.isAiGenerated,
    required this.approved,
  });

  static SchemeType parseSchemeType(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('central')) return SchemeType.central;
    if (lower.contains('state')) return SchemeType.state;
    return SchemeType.state;
  }

  factory Scheme.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString();
    final rawId = (json['id'] ?? json['_id'] ?? '').toString();
    
    return Scheme(
      id: rawId.isNotEmpty ? rawId : (json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: parseSchemeType(rawType),
      state: (json['state'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      benefits: (json['benefits'] as List? ?? const []).map((e) => e.toString()).toList(),
      eligibility: (json['eligibility'] as List? ?? const []).map((e) => e.toString()).toList(),
      documents: (json['documents'] as List? ?? const []).map((e) => e.toString()).toList(),
      deadline: (json['deadline'] ?? '').toString(),
      applyLink: (json['applyLink'] ?? '').toString(),
      isAiGenerated: json['isAiGenerated'] == true,
      approved: json['approved'] != false, // Default true
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type == SchemeType.central ? 'central' : 'state',
        'state': state,
        'category': category,
        'description': description,
        'benefits': benefits,
        'eligibility': eligibility,
        'documents': documents,
        'deadline': deadline,
        'applyLink': applyLink,
        'isAiGenerated': isAiGenerated,
        'approved': approved,
      };

  /// Returns true if this scheme is relevant to [farmerState].
  ///
  /// Rules (in priority order):
  /// 1. Central schemes always match any state.
  /// 2. State schemes tagged "All India" or "All" match any state.
  /// 3. If the farmer has no state preference yet, show everything.
  /// 4. State schemes with an empty [state] field are shown (data quality gap).
  /// 5. Otherwise do a case-insensitive substring check so slight naming
  ///    variations ("Andhra Pradesh" ↔ "andhra pradesh") still match.
  bool matchesFarmerState(String farmerState) {
    if (type != SchemeType.state) return true;
    final schemeState = state.trim().toLowerCase();
    if (schemeState == 'all india' || schemeState == 'all') return true;
    final farmer = farmerState.trim().toLowerCase();
    if (farmer.isEmpty) return true;
    if (schemeState.isEmpty) return true; // show rather than hide
    return schemeState.contains(farmer) || farmer.contains(schemeState);
  }
}
