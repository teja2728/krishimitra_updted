import 'dart:developer' as dev;

/// Domain restriction checker for KrishiMitra AI chat.
///
/// Acts as the first line of defence — runs entirely client-side so
/// non-agriculture queries are blocked instantly without an API call.
class AgriDomainChecker {
  AgriDomainChecker._();

  // ── English agriculture keywords ──────────────────────────────────────────
  static const _agriKeywordsEn = <String>[
    // Core agriculture
    'farm', 'farmer', 'farming', 'agriculture', 'agri', 'crop', 'crops',
    'cultivation', 'cultivate', 'harvest', 'harvesting', 'field', 'plantation',

    // Soil & land
    'soil', 'land', 'acre', 'hectare', 'plot', 'terrace', 'topsoil',
    'compost', 'manure', 'fertilizer', 'fertiliser', 'urea', 'npk',
    'organic', 'mulch', 'tilling', 'ploughing', 'plowing',

    // Water
    'irrigation', 'drip', 'sprinkler', 'canal', 'rainwater', 'borewell',
    'water table', 'waterlogging', 'drainage',

    // Plants & crops
    'seed', 'seeds', 'seedling', 'paddy', 'rice', 'wheat', 'maize', 'corn',
    'sugarcane', 'cotton', 'soybean', 'groundnut', 'peanut', 'pulses',
    'lentils', 'chickpea', 'mustard', 'sunflower', 'barley', 'millet',
    'jowar', 'bajra', 'ragi', 'turmeric', 'ginger', 'chilli', 'pepper',
    'tomato', 'onion', 'potato', 'vegetables', 'fruits', 'mango', 'banana',
    'papaya', 'coconut', 'rubber', 'jute', 'hemp', 'tea', 'coffee', 'spice',

    // Plant health
    'pest', 'pesticide', 'insecticide', 'herbicide', 'fungicide', 'weed',
    'disease', 'blight', 'aphid', 'locust', 'nematode', 'spray', 'fungal',
    'bacterial', 'virus', 'infestation', 'crop protection', 'biological control',

    // Livestock
    'livestock', 'cattle', 'cow', 'buffalo', 'goat', 'sheep', 'pig', 'poultry',
    'chicken', 'hen', 'dairy', 'milk', 'egg', 'breed', 'veterinary', 'vet',
    'animal husbandry', 'fish', 'fishery', 'aquaculture', 'beekeeping', 'honey',

    // Equipment
    'tractor', 'thresher', 'harvester', 'plough', 'pump', 'dryer',
    'storage', 'silo', 'warehouse', 'cold storage',

    // Government & finance
    'scheme', 'yojana', 'subsidy', 'loan', 'credit', 'kcc', 'kisan',
    'pm-kisan', 'pm kisan', 'pmfby', 'pmgsy', 'fasal bima', 'mgnrega',
    'msp', 'minimum support price', 'ration', 'e-nam', 'enam', 'apmc',
    'mandi', 'market', 'price', 'procurement', 'fci', 'nafed',

    // Weather & environment
    'weather', 'monsoon', 'rain', 'drought', 'flood', 'climate', 'temperature',
    'humidity', 'forecast', 'season', 'rabi', 'kharif', 'zaid',

    // Practices
    'crop rotation', 'intercropping', 'mixed farming', 'greenhouse',
    'polyhouse', 'hydroponic', 'vertical farming', 'precision agriculture',
    'natural farming', 'sustainable', 'zero budget', 'regenerative',

    // Markets
    'agro', 'agri market', 'vegetable market', 'grain', 'yield', 'produce',
    'export', 'import', 'cold chain', 'fpo', 'cooperative', 'shg',
  ];

  // ── Telugu agriculture keywords ───────────────────────────────────────────
  static const _agriKeywordsTe = <String>[
    'రైతు', 'వ్యవసాయం', 'పంట', 'విత్తనాలు', 'నేల', 'ఎరువు', 'నీటిపారుదల',
    'పురుగుమందు', 'కంది', 'వరి', 'గోధుమ', 'మొక్కజొన్న', 'వేరుశనగ',
    'మిర్చి', 'టమాటో', 'ఉల్లిపాయ', 'అరటి', 'పశుపాలన', 'పాడి', 'యోజన',
    'సబ్సిడీ', 'రుణం', 'వర్షం', 'కరువు', 'వాతావరణం', 'ధర', 'మండి',
    'కిసాన్', 'పీఎం కిసాన్', 'ఫసల్ బీమా', 'రైతు సంఘం', 'ఆర్గానిక్',
  ];

  // ── Hindi agriculture keywords ────────────────────────────────────────────
  static const _agriKeywordsHi = <String>[
    'किसान', 'खेती', 'फसल', 'बीज', 'मिट्टी', 'खाद', 'सिंचाई', 'कीटनाशक',
    'गेहूं', 'चावल', 'मक्का', 'दलहन', 'सरसों', 'कपास', 'गन्ना', 'आलू',
    'टमाटर', 'प्याज', 'पशुपालन', 'गाय', 'भैंस', 'मुर्गीपालन', 'डेयरी',
    'योजना', 'सब्सिडी', 'ऋण', 'बारिश', 'सूखा', 'मौसम', 'मंडी', 'भाव',
    'पीएम किसान', 'फसल बीमा', 'जैविक', 'उर्वरक', 'ट्रैक्टर', 'हार्वेस्ट',
    'रबी', 'खरीफ', 'प्रधानमंत्री', 'किसान सम्मान', 'कृषि',
  ];

  // ── Kannada agriculture keywords ──────────────────────────────────────────
  static const _agriKeywordsKn = <String>[
    'ರೈತ', 'ಕೃಷಿ', 'ಬೆಳೆ', 'ಬೀಜ', 'ಮಣ್ಣು', 'ಗೊಬ್ಬರ', 'ನೀರಾವರಿ',
    'ಕೀಟನಾಶಕ', 'ಭತ್ತ', 'ಗೋಧಿ', 'ಜೋಳ', 'ರಾಗಿ', 'ತೊಗರಿ', 'ಕಡಲೆ',
    'ಮೆಣಸಿನಕಾಯಿ', 'ಟೊಮ್ಯಾಟೊ', 'ಈರುಳ್ಳಿ', 'ಪಶುಪಾಲನೆ', 'ಹಾಲು',
    'ಯೋಜನೆ', 'ಸಹಾಯಧನ', 'ಸಾಲ', 'ಮಳೆ', 'ಬರ', 'ಹವಾಮಾನ', 'ಮಂಡಿ',
    'ಕಿಸಾನ್', 'ಪಿಎಂ ಕಿಸಾನ್', 'ಸಾವಯವ', 'ಟ್ರ್ಯಾಕ್ಟರ್',
  ];

  // ── Obvious off-topic signal words ────────────────────────────────────────
  // A query containing these AND no agriculture keyword is clearly off-topic.
  static const _offTopicSignals = <String>[
    'java', 'python', 'javascript', 'typescript', 'kotlin', 'swift', 'rust',
    'golang', 'c++', 'c#', 'ruby', 'php', 'html', 'css', 'sql', 'react',
    'flutter widget', 'angular', 'vue', 'node.js', 'nodejs', 'express',
    'programming', 'coding', 'code', 'algorithm', 'data structure',
    'fibonacci', 'factorial', 'sorting', 'linked list', 'binary tree',
    'blockchain', 'nft', 'cryptocurrency', 'bitcoin', 'ethereum',
    'movie', 'film', 'netflix', 'cricket', 'ipl', 'football', 'gaming',
    'game', 'pubg', 'fortnite', 'valorant', 'playstation', 'xbox',
    'politics', 'election', 'party', 'prime minister speech', 'bollywood',
    'celebrity', 'hack', 'hacking', 'malware', 'virus removal',
    'relationship', 'girlfriend', 'boyfriend', 'love story',
    'homework', 'essay', 'poem about love', 'joke', 'riddle',
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns `true` if [query] is agriculture-related (should be processed).
  /// Returns `false` if the query should be blocked.
  static bool isAgricultureQuery(String query) {
    if (query.trim().isEmpty) return false;

    final normalized = query.toLowerCase().trim();

    // 1. Check all agri keyword banks
    final allAgri = [
      ..._agriKeywordsEn,
      ..._agriKeywordsTe,
      ..._agriKeywordsHi,
      ..._agriKeywordsKn,
    ];

    final hasAgriKeyword = allAgri.any((kw) => normalized.contains(kw));

    if (hasAgriKeyword) {
      dev.log('[AgriChecker] ✅ Allowed: "$query" (matched agri keyword)');
      return true;
    }

    // 2. Check for obvious off-topic signals
    final hasOffTopicSignal =
        _offTopicSignals.any((kw) => normalized.contains(kw));
    if (hasOffTopicSignal) {
      dev.log('[AgriChecker] ❌ Blocked: "$query" (off-topic signal matched)');
      return false;
    }

    // 3. Short greetings / meta-questions — allow them (AI will redirect)
    final greetingPatterns = [
      'hello', 'hi ', 'namaste', 'help', 'who are you', 'what can you do',
      'your name', 'about you',
    ];
    final isGreeting = greetingPatterns.any((g) => normalized.startsWith(g) ||
        normalized.contains(g));
    if (isGreeting) {
      dev.log('[AgriChecker] ✅ Allowed: "$query" (greeting/meta)');
      return true;
    }

    // 4. Default: allow short or ambiguous queries — the backend system prompt
    //    will handle off-topic replies gracefully
    if (normalized.split(' ').length <= 4) {
      dev.log('[AgriChecker] ✅ Allowed (short query): "$query"');
      return true;
    }

    // 5. Block longer queries with no agri signal
    dev.log('[AgriChecker] ❌ Blocked: "$query" (no agri keyword found)');
    return false;
  }

  /// Friendly block message shown to user when query is rejected.
  /// Returns a localized string based on [language].
  static String blockMessage(String language) {
    switch (language.toLowerCase()) {
      case 'telugu':
        return '🌾 నేను KrishiMitra AI అసిస్టెంట్‌ని. నేను వ్యవసాయం, పంటలు, '
            'రైతు పథకాలు మరియు వ్యవసాయ విషయాల గురించి మాత్రమే సహాయం చేయగలను.\n\n'
            'మీరు ఇవి అడగవచ్చు:\n'
            '• పంటలు & విత్తనాలు\n'
            '• ఎరువులు & నీటిపారుదల\n'
            '• ప్రభుత్వ పథకాలు\n'
            '• వ్యాధి నివారణ\n'
            '• వాతావరణం & మండి ధరలు';
      case 'hindi':
        return '🌾 मैं KrishiMitra AI असिस्टेंट हूँ। मैं केवल कृषि, फसल, '
            'किसान योजनाओं और खेती से जुड़े विषयों पर सहायता कर सकता हूँ।\n\n'
            'आप पूछ सकते हैं:\n'
            '• फसलें और बीज\n'
            '• उर्वरक और सिंचाई\n'
            '• सरकारी योजनाएं\n'
            '• रोग नियंत्रण\n'
            '• मौसम और मंडी भाव';
      case 'kannada':
        return '🌾 ನಾನು KrishiMitra AI ಸಹಾಯಕ. ನಾನು ಕೃಷಿ, ಬೆಳೆ, '
            'ರೈತ ಯೋಜನೆಗಳು ಮತ್ತು ಕೃಷಿ ವಿಷಯಗಳ ಬಗ್ಗೆ ಮಾತ್ರ ಸಹಾಯ ಮಾಡಬಲ್ಲೆ.\n\n'
            'ನೀವು ಕೇಳಬಹುದು:\n'
            '• ಬೆಳೆ ಮತ್ತು ಬೀಜ\n'
            '• ಗೊಬ್ಬರ ಮತ್ತು ನೀರಾವರಿ\n'
            '• ಸರ್ಕಾರಿ ಯೋಜನೆಗಳು\n'
            '• ರೋಗ ನಿಯಂತ್ರಣ\n'
            '• ಹವಾಮಾನ ಮತ್ತು ಮಂಡಿ ಬೆಲೆ';
      default:
        return '🌾 I am KrishiMitra AI, your agriculture assistant.\n'
            'I only answer questions about farming, crops, and farmer welfare.\n\n'
            'You can ask me about:\n'
            '• Crops & Seeds\n'
            '• Fertilizers & Irrigation\n'
            '• Government Schemes\n'
            '• Pest & Disease Control\n'
            '• Weather & Market Prices\n'
            '• Soil Health & Organic Farming';
  }
  }
}
