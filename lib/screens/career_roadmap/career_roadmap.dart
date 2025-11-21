import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CareerRoadmap extends StatefulWidget {
  final String userTestId;
  final String jobIndex;

  const CareerRoadmap({
    super.key,
    required this.userTestId,
    required this.jobIndex,
  });

  @override
  State<CareerRoadmap> createState() => _CareerRoadmapState();
}

class _CareerRoadmapState extends State<CareerRoadmap> {
  Map<String, dynamic>? roadmap;
  List<dynamic> recommendedJobs = [];
  String? currentJobIndex;
  String? currentJobTitle;
  bool isLoading = true;
  bool isLoadingJobs = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    currentJobIndex = widget.jobIndex;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load all recommended jobs first
      await _loadRecommendedJobs();

      // Generate all career roadmaps for the user
      await ApiService.generateCareerRoadMaps(widget.userTestId);

      // Load the initial career roadmap
      await _loadCareerRoadmap();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        isLoadingJobs = false;
      });
    }
  }

  Future<void> _loadRecommendedJobs() async {
    try {
      final response =
          await ApiService.getAllRecommendedJobs(widget.userTestId);

      if (response.containsKey('data')) {
        setState(() {
          recommendedJobs = response['data'];
          isLoadingJobs = false;
        });

        // Set current job title if available
        if (currentJobIndex != null) {
          _setCurrentJobTitle();
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load recommended jobs: $e";
        isLoadingJobs = false;
      });
    }
  }

  Future<void> _loadCareerRoadmap() async {
    if (currentJobIndex == null) return;

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final results = await ApiService.getCareerRoadmap(
          widget.userTestId, currentJobIndex!);

      // Extract the data
      final responseData = results['data'];
      if (responseData == null) {
        throw Exception('No data in response');
      }

      // The actual roadmap data is in responseData['data']
      final roadmapData = responseData['data'];
      if (roadmapData == null) {
        throw Exception('No roadmap data found');
      }

      // Transform the data into the structure needed for the UI
      final Map<String, Map<String, List<String>>> levels = {};

      // Process topics and sub_topics
      if (roadmapData['topics'] != null && roadmapData['sub_topics'] != null) {
        final topics = Map<String, dynamic>.from(roadmapData['topics']);
        final subTopics = Map<String, dynamic>.from(roadmapData['sub_topics']);

        topics.forEach((topicName, level) {
          final levelName = _formatLevelName(level.toString());
          final topicSubTopics = List<String>.from(subTopics[topicName] ?? []);

          if (!levels.containsKey(levelName)) {
            levels[levelName] = {};
          }
          levels[levelName]![topicName] = topicSubTopics;
        });
      }

      setState(() {
        roadmap = {
          'user_test_id': roadmapData['user_test_id'] ?? widget.userTestId,
          'job_index': roadmapData['job_index'] ?? currentJobIndex,
          'job_title': currentJobTitle,
          'levels': levels,
        };
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load roadmap: $e';
        isLoading = false;
      });
    }
  }

  String _formatLevelName(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      case 'expert':
        return 'Expert';
      default:
        return level;
    }
  }

  void _setCurrentJobTitle() {
    try {
      final job = recommendedJobs.firstWhere(
        (job) => job['job_index'] == currentJobIndex,
        orElse: () => {'job_title': 'Unknown Title'},
      );
      setState(() {
        currentJobTitle = job['job_title'];
      });
    } catch (e) {
      setState(() {
        currentJobTitle = 'Unknown Title';
      });
    }
  }

  void _onJobSelected(String jobIndex, String jobTitle) {
    setState(() {
      currentJobIndex = jobIndex;
      currentJobTitle = jobTitle;
    });
    _loadCareerRoadmap();
  }

  Widget _buildJobSelector() {
    if (isLoadingJobs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recommendedJobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No recommended jobs found',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recommendedJobs.length,
        itemBuilder: (context, index) {
          final job = recommendedJobs[index];
          final jobIndex = job['job_index'];
          final jobTitle = job['job_title'];
          final isSelected = currentJobIndex == jobIndex;

          return Container(
            width: 200,
            margin: EdgeInsets.only(
              right: 12,
              left: index == 0 ? 0 : 0,
            ),
            child: Card(
              elevation: 2,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: () => _onJobSelected(jobIndex, jobTitle),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Career #${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jobTitle.length > 20
                            ? '${jobTitle.substring(0, 20)}...'
                            : jobTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: $jobIndex',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoadmapContent() {
    if (isLoading) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your career roadmap...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading roadmap',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadCareerRoadmap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (roadmap == null) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Nothing to see here D:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Complete your assessments to unlock your\npersonalized career roadmap!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final levels = roadmap?['levels'] as Map<String, dynamic>?;
    if (levels == null || levels.isEmpty) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No roadmap data available',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with job title - matching your Figma design
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalized Career Roadmap',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentJobTitle ?? 'Unknown Career',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Roadmap levels
          Expanded(
            child: ListView(
              children: _buildLevels(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLevels() {
    final levels = roadmap?['levels'] as Map<String, dynamic>?;
    if (levels == null || levels.isEmpty) {
      return [
        const Center(
          child: Text('No roadmap levels available'),
        ),
      ];
    }

    final levelWidgets = <Widget>[];
    final levelNames = levels.keys.toList();

    // Sort levels in logical order
    levelNames.sort((a, b) {
      final order = {
        'Beginner': 0,
        'Intermediate': 1,
        'Advanced': 2,
        'Expert': 3
      };
      return (order[a] ?? 4).compareTo(order[b] ?? 4);
    });

    for (int i = 0; i < levelNames.length; i++) {
      final levelName = levelNames[i];
      final topicsMap = Map<String, dynamic>.from(levels[levelName]!);

      levelWidgets.add(
        _buildLevelCard(levelName, topicsMap, i),
      );

      // Add spacing between levels
      if (i < levelNames.length - 1) {
        levelWidgets.add(const SizedBox(height: 24));
      }
    }

    return levelWidgets;
  }

  Widget _buildLevelCard(
      String levelName, Map<String, dynamic> topicsMap, int levelIndex) {
    // Different colors for different levels like in your Figma
    final levelColors = [
      const Color(0xFF4CAF50), // Beginner - Green
      const Color(0xFF2196F3), // Intermediate - Blue
      const Color(0xFFFF9800), // Advanced - Orange
      const Color(0xFFF44336), // Expert - Red
    ];

    final backgroundColor = levelColors[levelIndex % levelColors.length];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: backgroundColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level header - matching your Figma
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: backgroundColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      levelName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: backgroundColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${topicsMap.length} ${topicsMap.length == 1 ? 'Topic' : 'Topics'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Topics list - clean layout like your Figma
              if (topicsMap.isNotEmpty)
                ...topicsMap.entries.map((entry) {
                  final topicName = entry.key;
                  final subTopics = List<String>.from(entry.value ?? []);
                  return _buildTopicCard(topicName, subTopics, backgroundColor);
                }).toList()
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No topics for this level',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(
      String topicName, List<String> subTopics, Color levelColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic name
            Text(
              topicName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Subtopic list - clean bullet points
            if (subTopics.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subTopics
                    .map((subTopic) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 2.0, right: 8.0),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: levelColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  subTopic,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Career Roadmap',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching your Figma
            Text(
              'Your Recommended Careers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a career to view its detailed learning path',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Job selector
            _buildJobSelector(),
            const SizedBox(height: 32),

            // Roadmap content
            _buildRoadmapContent(),
          ],
        ),
      ),
    );
  }
}
