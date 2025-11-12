import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'education_major.dart';

class Cgpa extends StatefulWidget {
  final UserResponses userResponse;

  const Cgpa({super.key, required this.userResponse});

  @override
  State<Cgpa> createState() => _CgpaState();
}

class _CgpaState extends State<Cgpa> {
  final TextEditingController cgpaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Current CGPA")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "What is your current CGPA?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: cgpaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter your CGPA",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (cgpaController.text.isNotEmpty) {
                  // save CGPA to response object
                  widget.userResponse.cgpa = cgpaController.text;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EducationMajor(userResponse: widget.userResponse),
                    ),
                  );
                }
              },
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}
