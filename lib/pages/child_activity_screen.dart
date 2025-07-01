import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your usage stats model
// import 'package:ai_guardian_parent/models/usage_stats.dart';

class ChildActivityScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildActivityScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildActivityScreen> createState() => _ChildActivityScreenState();
}

class _ChildActivityScreenState extends State<ChildActivityScreen> {
  List<Map<String, dynamic>> usageStats = [];
  bool isLoading = true;
  String selectedPeriod = 'Today';
  int totalScreenTime = 0;

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DateTime startDate;
        DateTime endDate = DateTime.now();

        // Determine date range based on selected period
        switch (selectedPeriod) {
          case 'Today':
            startDate = DateTime(endDate.year, endDate.month, endDate.day);
            break;
          case 'This Week':
            startDate = endDate.subtract(Duration(days: endDate.weekday - 1));
            startDate = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            break;
          case 'This Month':
            startDate = DateTime(endDate.year, endDate.month, 1);
            break;
          default:
            startDate = DateTime(endDate.year, endDate.month, endDate.day);
        }

        // Query usage stats from Firestore
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .where('childId', isEqualTo: widget.childId)
                .where(
                  'date',
                  isGreaterThanOrEqualTo: startDate.toIso8601String(),
                )
                .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
                .orderBy('date', descending: true)
                .get();

        List<Map<String, dynamic>> stats = [];
        int totalTime = 0;

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          stats.add(data);

          // Add to total screen time
          if (data['totalTimeInForeground'] != null) {
            totalTime += (data['totalTimeInForeground'] as num).toInt();
          }
        }

        setState(() {
          usageStats = stats;
          totalScreenTime = totalTime;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading usage stats: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity data: $e')),
      );
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getAppColor(String appName) {
    // Generate a color based on app name
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[appName.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName}\'s Activity'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            initialValue: selectedPeriod,
            onSelected: (value) {
              setState(() {
                selectedPeriod = value;
              });
              _loadUsageStats();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'Today', child: Text('Today')),
                  const PopupMenuItem(
                    value: 'This Week',
                    child: Text('This Week'),
                  ),
                  const PopupMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedPeriod,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Summary Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C5DF4), Color(0xFF6C7EF7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Screen Time',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(totalScreenTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedPeriod,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // App Usage List
                  Expanded(
                    child:
                        usageStats.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No activity data found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Activity data will appear here once the child uses their device',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: usageStats.length,
                              itemBuilder: (context, index) {
                                final app = usageStats[index];
                                final appName = app['appName'] ?? 'Unknown App';
                                final timeInForeground =
                                    app['totalTimeInForeground'] ?? 0;
                                final lastTimeUsed = app['lastTimeUsed'] ?? 0;
                                final launchCount = app['launchCount'] ?? 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getAppColor(appName),
                                      child: Text(
                                        appName.isNotEmpty
                                            ? appName[0].toUpperCase()
                                            : 'A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      appName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Usage: ${_formatDuration(timeInForeground)}',
                                        ),
                                        if (lastTimeUsed > 0)
                                          Text(
                                            'Last used: ${_formatTime(lastTimeUsed)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$launchCount opens',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
