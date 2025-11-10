class UserResponses {
  String educationLevel;
  String cgpa;
  String thesisTopic;
  String major;
  List<String> programmingLanguages;
  String courseworkExperience;
  String skillReflection;
  String thesisFindings;
  String careerGoals;

  UserResponses({
    this.educationLevel = '',
    this.cgpa = '',
    this.thesisTopic = '',
    this.major = '',
    List<String>? programmingLanguages,
    this.courseworkExperience = '',
    this.skillReflection = '',
    this.thesisFindings = '',
    this.careerGoals = '',
    required Map<String, String> followUpAnswers,
  }) : programmingLanguages = programmingLanguages ?? [];

  Map<String, dynamic> toJson() => {
        "educationLevel": educationLevel,
        "cgpa": double.tryParse(cgpa),
        "thesisTopic": thesisTopic,
        "major": major,
        "programmingLanguages": programmingLanguages,
        "courseworkExperience": courseworkExperience,
        "skillReflection": skillReflection,
        "thesisFindings": thesisFindings,
        "careerGoals": careerGoals,
      };
}

// Global shared object
UserResponses globalUserResponses = UserResponses(followUpAnswers: {});
