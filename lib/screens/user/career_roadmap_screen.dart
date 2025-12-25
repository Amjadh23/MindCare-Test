import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// New screen for job indexes
class JobIndexesScreen extends StatelessWidget {
  final String testId;
  final List<String> jobIndexes;

  const JobIndexesScreen({
    super.key,
    required this.testId,
    required this.jobIndexes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F8D46),
        title: const Text(
          'Job Indexes',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test ID:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              testId,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Monospace',
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Job Indexes:',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: jobIndexes.length,
                itemBuilder: (context, index) {
                  final jobIndex = jobIndexes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF2F8D46).withOpacity(0.1),
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      title: Text(
                        'Job Index: $jobIndex',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      subtitle: Text(
                        'Associated with: ${testId.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main Career Roadmap Screen
class CareerRoadmapScreen extends StatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  State<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends State<CareerRoadmapScreen> {
  static const Color geekGreen = Color(0xFF2F8D46);
  static const Color geekDarkGreen = Color(0xFF1B5E20);
  static const Color geekBackground = Color(0xFFE8F5E9);
  static const Color geekCardBg = Color(0xFFFFFFFF);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<String>> roadmapsByTestId = {};
  List<String> userTestIds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCareerRoadmaps();
  }

  Future<void> _loadCareerRoadmaps() async {
    try {
      final querySnapshot = await _firestore.collection('career_roadmap').get();

      final Map<String, List<String>> groupedData = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('user_test_id') && data.containsKey('job_index')) {
          final testId = data['user_test_id'] as String;
          final jobIndex = data['job_index'] as String;

          if (!groupedData.containsKey(testId)) {
            groupedData[testId] = [];
          }
          groupedData[testId]!.add(jobIndex);
        }
      }

      // Sort test IDs and job indexes
      final sortedTestIds = groupedData.keys.toList()..sort();
      for (final testId in sortedTestIds) {
        groupedData[testId]!.sort();
      }

      if (mounted) {
        setState(() {
          roadmapsByTestId = groupedData;
          userTestIds = sortedTestIds;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading career roadmaps: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _navigateToJobIndexes(String testId) {
    final jobIndexes = roadmapsByTestId[testId] ?? [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobIndexesScreen(
          testId: testId,
          jobIndexes: jobIndexes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: geekBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Career Roadmaps',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click on a Test ID to view job indexes',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2F8D46),
                  ),
                )
              else if (userTestIds.isEmpty)
                Center(
                  child: Text(
                    'No data found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: userTestIds.length,
                    itemBuilder: (context, index) {
                      final testId = userTestIds[index];
                      final jobIndexes = roadmapsByTestId[testId] ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        child: ListTile(
                          onTap: () => _navigateToJobIndexes(testId),
                          leading: CircleAvatar(
                            backgroundColor: geekGreen.withOpacity(0.1),
                            child: const Icon(
                              Icons.list_alt,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          title: Text(
                            testId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Monospace',
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          subtitle: Text(
                            '${jobIndexes.length} job index(es)',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
