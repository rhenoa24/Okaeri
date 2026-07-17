/// The 16 Myers-Briggs personality types.
const List<String> kMbtiTypes = [
  'INTJ',
  'INTP',
  'ENTJ',
  'ENTP',
  'INFJ',
  'INFP',
  'ENFJ',
  'ENFP',
  'ISTJ',
  'ISFJ',
  'ESTJ',
  'ESFJ',
  'ISTP',
  'ISFP',
  'ESTP',
  'ESFP',
];

/// The 12 Western zodiac signs.
const List<String> kZodiacSigns = [
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// "Basic info" details shown on a profile — birthday, height, weight,
/// occupation, MBTI, zodiac sign, and hobbies.
class ProfileDetails {
  final DateTime? birthday;
  final double? heightCm;
  final double? weightKg;
  final String occupation;
  final String homeAddress;
  final String company;
  final String contactNumber;
  final String? mbti;
  final String? zodiac;
  final List<String> hobbies;

  const ProfileDetails({
    this.birthday,
    this.heightCm,
    this.weightKg,
    this.occupation = '',
    this.homeAddress = '',
    this.company = '',
    this.contactNumber = '',
    this.mbti,
    this.zodiac,
    this.hobbies = const [],
  });

  bool get isEmpty =>
      birthday == null &&
      heightCm == null &&
      weightKg == null &&
      occupation.isEmpty &&
      homeAddress.isEmpty &&
      company.isEmpty &&
      contactNumber.isEmpty &&
      mbti == null &&
      zodiac == null &&
      hobbies.isEmpty;

  ProfileDetails copyWith({
    DateTime? birthday,
    bool clearBirthday = false,
    double? heightCm,
    bool clearHeight = false,
    double? weightKg,
    bool clearWeight = false,
    String? occupation,
    String? homeAddress,
    String? company,
    String? contactNumber,
    String? mbti,
    bool clearMbti = false,
    String? zodiac,
    bool clearZodiac = false,
    List<String>? hobbies,
  }) {
    return ProfileDetails(
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      occupation: occupation ?? this.occupation,
      homeAddress: homeAddress ?? this.homeAddress,
      company: company ?? this.company,
      contactNumber: contactNumber ?? this.contactNumber,
      mbti: clearMbti ? null : (mbti ?? this.mbti),
      zodiac: clearZodiac ? null : (zodiac ?? this.zodiac),
      hobbies: hobbies ?? this.hobbies,
    );
  }

  // TODO: wire to Firestore. Suggested shape on the user doc:
  // { birthday: Timestamp?, heightCm: num?, weightKg: num?,
  //   occupation: String?, mbti: String?, zodiac: String?,
  //   hobbies: List<String>? }
  factory ProfileDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProfileDetails();
    return ProfileDetails(
      birthday: (map['birthday'] as dynamic)?.toDate(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      occupation: map['occupation'] as String? ?? '',
      homeAddress: map['homeAddress'] as String? ?? '',
      company: map['company'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      mbti: map['mbti'] as String?,
      zodiac: map['zodiac'] as String?,
      hobbies: List<String>.from(map['hobbies'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'birthday': birthday,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'occupation': occupation,
      'homeAddress': homeAddress,
      'company': company,
      'contactNumber': contactNumber,
      'mbti': mbti,
      'zodiac': zodiac,
      'hobbies': hobbies,
    };
  }
}
