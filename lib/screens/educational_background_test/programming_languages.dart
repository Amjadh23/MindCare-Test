import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'coursework_experience.dart';

class ProgrammingLanguages extends StatefulWidget {
  final UserResponses userResponse; // <-- changed

  const ProgrammingLanguages({super.key, required this.userResponse});

  @override
  State<ProgrammingLanguages> createState() => _ProgrammingLanguagesState();
}

class _ProgrammingLanguagesState extends State<ProgrammingLanguages> {
  final List<String> languages = [
    "Python",
    "Java",
    "JavaScript",
    "TypeScript",
    "C",
    "C++",
    "C#",
    "PHP",
    "Ruby",
    "Go (Golang)",
    "Rust",
    "Swift",
    "Kotlin",
    "Scala",
    "R",
    "SQL",
    "Pascal",
    "Perl",
    "Dart",
    "Lua",
    "Objective-C",
    "Visual Basic",
    "None"
  ];

  // tracks user's selected languages
  final List<String> selectedLanguages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Programming Languages")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What programming languages have you learned?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = selectedLanguages.contains(lang);
                return ListTile(
                  title: Text(lang),
                  // show checkmark for selected languages
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      // toggle selection: add if not selected, remove if already selecte
                      isSelected
                          ? selectedLanguages.remove(lang)
                          : selectedLanguages.add(lang);
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // save selected languages to user response object
              widget.userResponse.programmingLanguages =
                  List.from(selectedLanguages);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CourseworkExperience(userResponse: widget.userResponse),
                ),
              );
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }
}
