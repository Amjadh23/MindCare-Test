import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/services/api_service.dart';
import '../results/report.dart';

class RecentReportWidget extends StatefulWidget {
  const RecentReportWidget({Key? key}) : super(key: key);

  @override
  _RecentReportWidgetState createState() => _RecentReportWidgetState();
}

class _RecentReportWidgetState extends State<RecentReportWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _availableJobs = [];
  Map<String, dynamic>? _selectedJob;
  Map<String, dynamic>? _reportData;
  String? _userTestId;
  int? _attemptNumber;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showJobDropdown = false;

  // Color scheme
  static const Color geekGreen = Color(0xFF2F8D46);
  static const Color geekDarkGreen = Color(0xFF1B5E20);
  static const Color geekLightGreen = Color(0xFF4CAF50);
  static const Color geekBackground = Color(0xFFE8F5E9);
  static const Color geekCardBg = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadRecentReport();
  }

  Future<void> _loadRecentReport() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final attempts = data['assessmentAttempts'] as List?;

        if (attempts != null && attempts.isNotEmpty) {
          attempts.sort((a, b) {
            final aDate = DateTime.parse(a['completedAt']);
            final bDate = DateTime.parse(b['completedAt']);
            return bDate.compareTo(aDate);
          });

          final latestAttempt = attempts.first;
          _userTestId = latestAttempt['testId'];
          _attemptNumber = latestAttempt['attemptNumber'];
        } else {
          _userTestId = null;
        }

        if (_userTestId != null && _userTestId!.isNotEmpty) {
          await _loadAllJobs();
        } else {
          setState(() {
            _errorMessage = 'No assessment taken yet';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading report: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllJobs() async {
    if (_userTestId == null) return;

    try {
      for (int jobIndex = 0; jobIndex < 3; jobIndex++) {
        try {
          final response = await ApiService.generateReport(
              _userTestId!, jobIndex.toString());

          if (response['data'] != null && response['data']['job'] != null) {
            _availableJobs.add({
              'job_index': jobIndex.toString(),
              'job_title':
                  response['data']['job']['job_title'] ?? 'Job ${jobIndex + 1}',
              'job_description':
                  response['data']['job']['job_description'] ?? '',
              'similarity_percentage':
                  response['data']['job']['similarity_percentage'] ?? '',
              'report_data': response['data'],
            });
          }
        } catch (e) {
          print('Error loading job $jobIndex: $e');
        }
      }

      _availableJobs.sort((a, b) {
        final aPercent =
            double.tryParse(a['similarity_percentage']?.toString() ?? '0') ?? 0;
        final bPercent =
            double.tryParse(b['similarity_percentage']?.toString() ?? '0') ?? 0;
        return bPercent.compareTo(aPercent);
      });

      if (_availableJobs.isNotEmpty) {
        _selectedJob = _availableJobs.first;
        _reportData = _selectedJob!['report_data'];
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _errorMessage = 'No job recommendations found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading job recommendations: $e';
        _isLoading = false;
      });
    }
  }

  void _onJobSelected(Map<String, dynamic> job) {
    setState(() {
      _selectedJob = job;
      _reportData = job['report_data'];
      _showJobDropdown = false;
    });
  }

  String _truncateText(String text, {int maxLength = 80}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return geekDarkGreen;
    if (percentage >= 70) return geekGreen;
    if (percentage >= 60) return geekLightGreen;
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: geekCardBg,
        border: Border.all(color: geekGreen, width: 4),
        boxShadow: [
          BoxShadow(
            color: geekGreen.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_showJobDropdown && _availableJobs.length > 1)
            _buildJobDropdown(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _reportData != null
                        ? _buildReportContent()
                        : _buildNoReportState(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: geekBackground,
        border: Border(bottom: BorderSide(color: geekGreen, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: geekGreen,
                    border: Border.all(color: geekDarkGreen, width: 2),
                  ),
                  child: const Icon(Icons.videogame_asset,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '⚡ CAREER QUEST ⚡',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: geekDarkGreen,
                      letterSpacing: 1.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_availableJobs.length > 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showJobDropdown = !_showJobDropdown),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: geekGreen,
                  border: Border.all(color: geekDarkGreen, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_availableJobs.length} QUESTS',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showJobDropdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobDropdown() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: geekBackground,
        border: Border.all(color: geekGreen, width: 2),
      ),
      child: Column(
        children: _availableJobs.asMap().entries.map((entry) {
          final index = entry.key;
          final job = entry.value;
          final isSelected = _selectedJob?['job_index'] == job['job_index'];
          final similarity = double.tryParse(
                  job['similarity_percentage']?.toString() ?? '0') ??
              0;

          return GestureDetector(
            onTap: () => _onJobSelected(job),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? geekCardBg : geekBackground,
                border: Border.all(
                  color: isSelected ? geekDarkGreen : geekGreen,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getSimilarityColor(similarity),
                      border: Border.all(color: geekDarkGreen, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['job_title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? geekDarkGreen : geekGreen,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSimilarityColor(similarity),
                            border: Border.all(color: geekDarkGreen, width: 1),
                          ),
                          child: Text(
                            '${similarity.toStringAsFixed(0)}% MATCH',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_box, color: geekGreen, size: 24),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: geekBackground,
        border: Border.all(color: geekGreen, width: 2),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: geekGreen, strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            '⚡ LOADING QUESTS ⚡',
            style: TextStyle(
              color: geekDarkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: geekBackground,
        border: Border.all(color: Color(0xFFFF6B6B), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 48),
          const SizedBox(height: 12),
          const Text(
            '⚠ ERROR ⚠',
            style: TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: geekDarkGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReportState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: geekBackground,
        border: Border.all(color: geekGreen, width: 2),
      ),
      child: const Column(
        children: [
          Icon(Icons.help_outline, color: geekGreen, size: 48),
          SizedBox(height: 12),
          Text(
            '⚡ NO QUESTS AVAILABLE ⚡',
            style: TextStyle(
              color: geekDarkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete an assessment\nto unlock career quests!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: geekGreen, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final jobTitle =
        _reportData!['job']?['job_title'] ?? 'Job Title Not Available';
    final jobDescription = _reportData!['job']?['job_description'] ??
        'Job description not available';
    final similarity = double.tryParse(
            _selectedJob?['similarity_percentage']?.toString() ??
                _reportData!['job']?['similarity_percentage']?.toString() ??
                '0') ??
        0;

    final currentRank = _availableJobs.indexWhere(
            (job) => job['job_index'] == _selectedJob!['job_index']) +
        1;
    final isBestMatch = currentRank == 1;

    return Column(
      children: [
        if (_availableJobs.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBestMatch ? geekGreen : geekLightGreen,
              border: Border.all(color: geekDarkGreen, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBestMatch)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.star, color: Colors.white, size: 16),
                  ),
                Text(
                  isBestMatch
                      ? '★ LEGENDARY MATCH ★'
                      : 'QUEST #$currentRank OF ${_availableJobs.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: geekDarkGreen, width: 1),
                  ),
                  child: Text(
                    '${similarity.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _getSimilarityColor(similarity),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (_userTestId != null && _selectedJob != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportScreen(
                    userTestId: _userTestId!,
                    jobIndex: _selectedJob!['job_index'],
                    atemptNumber: _attemptNumber,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: geekBackground,
              border: Border.all(
                color: isBestMatch ? geekDarkGreen : geekGreen,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isBestMatch ? geekDarkGreen : geekGreen)
                      .withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBestMatch)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: geekGreen,
                            border: Border.all(color: geekDarkGreen, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              '★',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobTitle.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isBestMatch ? geekDarkGreen : geekGreen,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: geekDarkGreen, width: 2),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: similarity / 100,
                                      child: Container(
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color:
                                              _getSimilarityColor(similarity),
                                          border: Border.all(
                                              color: geekDarkGreen, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getSimilarityColor(similarity),
                                  border: Border.all(
                                      color: geekDarkGreen, width: 2),
                                ),
                                child: Text(
                                  '${similarity.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _truncateText(jobDescription, maxLength: 120),
                  style: const TextStyle(
                    fontSize: 12,
                    color: geekDarkGreen,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (_reportData!['job']?['required_skills'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: geekGreen,
                          border: Border.all(color: geekDarkGreen, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${(_reportData!['job']['required_skills'] as Map).length} SKILLS',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getSimilarityColor(similarity),
                          border: Border.all(color: geekDarkGreen, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isBestMatch ? '★' : '#$currentRank',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isBestMatch ? 'LEGEND' : 'RANK #$currentRank',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_userTestId != null && _selectedJob != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportScreen(
                          userTestId: _userTestId!,
                          jobIndex: _selectedJob!['job_index'],
                          atemptNumber: _attemptNumber,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBestMatch ? geekDarkGreen : geekGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(),
                  side: BorderSide(color: geekDarkGreen, width: 3),
                  elevation: 0,
                ),
                child: Text(
                  isBestMatch ? '⚡ VIEW LEGEND ⚡' : '▶ OPEN QUEST',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            if (_availableJobs.length > 1) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final currentIndex = _availableJobs.indexWhere((job) =>
                        job['job_index'] == _selectedJob!['job_index']);
                    final nextIndex =
                        (currentIndex + 1) % _availableJobs.length;
                    _onJobSelected(_availableJobs[nextIndex]);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: geekLightGreen,
                    padding: const EdgeInsets.all(12),
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide(color: geekDarkGreen, width: 3),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.navigate_next,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
