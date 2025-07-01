import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// You'll need to create this model if it doesn't exist
class AppUsageStats {
  final String appName;
  final String packageName;
  final int totalTimeInForeground;
  final int launchCount;
  final int lastTimeUsed;
  final String childId;
  final DateTime date;

  AppUsageStats({
    required this.appName,
    required this.packageName,
    required this.totalTimeInForeground,
    required this.launchCount,
    required this.lastTimeUsed,
    required this.childId,
    required this.date,
  });

  factory AppUsageStats.fromJson(Map<String, dynamic> json) {
    // print('📱 Parsing AppUsageStats from JSON: $json');

    try {
      final appStats = AppUsageStats(
        appName: json['appName'] ?? json['app_name'] ?? '',
        packageName: json['packageName'] ?? json['package_name'] ?? '',
        totalTimeInForeground: _parseTimeValue(
          json['totalTimeInForeground'] ??
              json['total_time_in_foreground'] ??
              json['usage_time'] ??
              0,
        ),
        launchCount: json['launchCount'] ?? json['launch_count'] ?? 0,
        lastTimeUsed: json['lastTimeUsed'] ?? json['last_time_used'] ?? 0,
        childId: json['childId'] ?? json['child_id'] ?? '',
        date: _parseDate(json['date']),
      );

      // print(
      //   '✅ Successfully parsed AppUsageStats: ${appStats.appName} - ${appStats.totalTimeInForeground}ms',
      // );
      return appStats;
    } catch (e, stackTrace) {
      // print('❌ Error parsing AppUsageStats: $e');
      // print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static int _parseTimeValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue is String) {
      return DateTime.tryParse(dateValue) ?? DateTime.now();
    } else if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'AppUsageStats(appName: $appName, packageName: $packageName, totalTime: ${totalTimeInForeground}ms, launches: $launchCount)';
  }
}

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

class _ChildActivityScreenState extends State<ChildActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Daily navigation
  DateTime _selectedDate = DateTime.now();
  final PageController _pageController = PageController(initialPage: 1000);

  // Daily stats cache
  final Map<String, Map<String, dynamic>?> _dailyStatsCache = {};
  final Map<String, List<AppUsageStats>> _dailyAppsCache = {};
  final Map<String, Map<String, int>> _dailyCategoriesCache = {};

  // Current day data
  Map<String, dynamic>? _currentDayStats;
  List<AppUsageStats> _currentAppUsageList = [];
  Map<String, int> _currentCategoryUsage = {};

  @override
  void initState() {
    super.initState();
    // print('🚀 Initializing ChildActivityScreen for child: ${widget.childId}');
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = DateTime.now();
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    // print(
    //   '🔄 Initializing screen for date: ${_formatDateString(_selectedDate)}',
    // );
    try {
      await _loadDataForDate(_selectedDate);
      // print('✅ Screen initialization completed');
    } catch (e, stackTrace) {
      print('❌ Error initializing screen: $e');
      print('Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataForDate(DateTime date) async {
    final dateString = _formatDateString(date);
    // print('📅 Loading data for date: $dateString');

    // Check cache first
    if (_dailyStatsCache.containsKey(dateString) &&
        _dailyAppsCache.containsKey(dateString)) {
      // print('💾 Loading data from cache for $dateString');
      setState(() {
        _currentDayStats = _dailyStatsCache[dateString];
        _currentAppUsageList = _dailyAppsCache[dateString] ?? [];
        _currentCategoryUsage = _dailyCategoriesCache[dateString] ?? {};
      });
      // print(
      //   '📊 Cache data loaded - Apps: ${_currentAppUsageList.length}, Stats: $_currentDayStats',
      // );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Load stats and apps for the specific date
      // print('🔄 Loading fresh data for $dateString');
      await Future.wait([_loadStatsForDate(date), _loadAppsForDate(date)]);
      // print('✅ Data loading completed for $dateString');
    } catch (e, stackTrace) {
      print('❌ Error loading data for date $dateString: $e');
      // print('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      print(
        '📊 Loading stats for date: $dateString, childId: ${widget.childId}',
      );

      // Check if it's today - use real-time data
      if (_isToday(date)) {
        await _loadTodayRealTimeStats(dateString);
      } else {
        await _loadHistoricalStats(dateString);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading stats for date: $e');
      // print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadTodayRealTimeStats(String dateString) async {
    try {
      // print('🔴 Loading today\'s real-time stats for $dateString');

      // For today, try to get the most up-to-date data
      final doc =
          await FirebaseFirestore.instance
              .collection('usage_tracking')
              .doc(widget.childId)
              .collection('daily_stats')
              .doc(dateString)
              .get();

      Map<String, dynamic>? statsData;

      if (doc.exists && doc.data() != null) {
        statsData = doc.data();
        // print('✅ Found today stats in usage_tracking: $statsData');
      } else {
        // print('⚠️ No data in usage_tracking, trying alternative collection');
        // Try alternative collection
        final altDoc =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .doc(dateString)
                .get();

        if (altDoc.exists && altDoc.data() != null) {
          statsData = altDoc.data();
          // print('✅ Found stats in alternative collection: $statsData');
        } else {
          print('⚠️ No stats found in either collection for today');
        }
      }

      // Cache and update current stats
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });

      // print('📊 Current day stats set: $_currentDayStats');
    } catch (e, stackTrace) {
      print('❌ Error loading today real-time stats: $e');
      // print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadHistoricalStats(String dateString) async {
    try {
      // print('📚 Loading historical stats for $dateString');

      // For historical dates, check both collections
      final futures = [
        FirebaseFirestore.instance
            .collection('usage_tracking')
            .doc(widget.childId)
            .collection('daily_stats')
            .doc(dateString)
            .get(),
        FirebaseFirestore.instance
            .collection('usage_stats')
            .doc(widget.childId)
            .collection('daily')
            .doc(dateString)
            .get(),
      ];

      final results = await Future.wait(futures);
      Map<String, dynamic>? statsData;

      for (int i = 0; i < results.length; i++) {
        final doc = results[i];
        final collectionName = i == 0 ? 'usage_tracking' : 'usage_stats';

        if (doc.exists && doc.data() != null) {
          statsData = doc.data() as Map<String, dynamic>?;
          // print(
          //   '✅ Found historical stats for $dateString in $collectionName: $statsData',
          // );
          break;
        } else {
          print('⚠️ No data found in $collectionName for $dateString');
        }
      }

      // if (statsData == null) {
      //   print('⚠️ No historical stats found in any collection for $dateString');
      // }

      // Cache and update current stats
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading historical stats: $e');
      // print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadAppsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      // print('📱 Loading apps for date: $dateString');

      List<AppUsageStats> appStats = [];

      // If it's today, try to get real-time data first
      if (_isToday(date)) {
        appStats = await _loadTodayAppStats(dateString);
      } else {
        appStats = await _loadHistoricalAppStats(dateString);
      }

      // print('📱 Loaded ${appStats.length} apps for $dateString');

      // Log each app for debugging
      for (int i = 0; i < appStats.length; i++) {
        final app = appStats[i];
        // print('  App $i: ${app.appName} - ${app.totalTimeInForeground}ms');
      }

      // Calculate category usage
      final categoryUsage = _calculateCategoryUsage(appStats);
      // print('📊 Category usage calculated: $categoryUsage');

      // Cache the results
      _dailyAppsCache[dateString] = appStats;
      _dailyCategoriesCache[dateString] = categoryUsage;

      setState(() {
        _currentAppUsageList = appStats;
        _currentCategoryUsage = categoryUsage;
      });

      print(
        '✅ Apps loading completed - Final count: ${_currentAppUsageList.length}',
      );
    } catch (e, stackTrace) {
      print('❌ Error loading apps for date: $e');
      // print('Stack trace: $stackTrace');
    }
  }

  Future<List<AppUsageStats>> _loadTodayAppStats(String dateString) async {
    try {
      // print('🔴 Loading today\'s app stats for $dateString');
      // For today, fallback to Firebase directly since we don't have UsageTrackingService
      return await _loadAppStatsFromFirebase(dateString);
    } catch (e, stackTrace) {
      print('❌ Error loading today app stats: $e');
      // print('Stack trace: $stackTrace');
      return await _loadAppStatsFromFirebase(dateString);
    }
  }

  Future<List<AppUsageStats>> _loadHistoricalAppStats(String dateString) async {
    // print('📚 Loading historical app stats for $dateString');
    return await _loadAppStatsFromFirebase(dateString);
  }

  Future<List<AppUsageStats>> _loadAppStatsFromFirebase(
    String dateString,
  ) async {
    try {
      // print('🔥 Loading app usage from Firebase for date: $dateString');
      print('🔥 Child ID: ${widget.childId}');

      // Try multiple collection paths
      final collectionPaths = [
        // Path 1: usage_stats/childId/daily/date/apps
        () async {
          print(
            '🔍 Trying path: usage_stats/${widget.childId}/daily/$dateString/apps',
          );
          return await FirebaseFirestore.instance
              .collection('usage_stats')
              .doc(widget.childId)
              .collection('daily')
              .doc(dateString)
              .collection('apps')
              .get();
        },
        // Path 2: usage_tracking/childId/daily_stats/date/apps
        () async {
          print(
            '🔍 Trying path: usage_tracking/${widget.childId}/daily_stats/$dateString/apps',
          );
          return await FirebaseFirestore.instance
              .collection('usage_tracking')
              .doc(widget.childId)
              .collection('daily_stats')
              .doc(dateString)
              .collection('apps')
              .get();
        },
        // Path 3: Check if apps are stored directly in the daily stats document
        () async {
          print(
            '🔍 Trying path: usage_stats/${widget.childId}/daily/$dateString (looking for apps field)',
          );
          final doc =
              await FirebaseFirestore.instance
                  .collection('usage_stats')
                  .doc(widget.childId)
                  .collection('daily')
                  .doc(dateString)
                  .get();

          if (doc.exists && doc.data()?.containsKey('apps') == true) {
            final appsData = doc.data()!['apps'];
            if (appsData is List) {
              // Create a fake QuerySnapshot-like structure
              return _createMockQuerySnapshot(appsData, dateString);
            }
          }
          throw Exception('No apps field found');
        },
      ];

      for (int i = 0; i < collectionPaths.length; i++) {
        try {
          final appsQuery = await collectionPaths[i]();

          if (appsQuery.docs.isNotEmpty) {
            print('✅ Found ${appsQuery.docs.length} apps in path ${i + 1}');

            final List<AppUsageStats> firebaseStats = [];
            for (int j = 0; j < appsQuery.docs.length; j++) {
              try {
                final doc = appsQuery.docs[j];
                final data = Map<String, dynamic>.from(doc.data() as Map);

                print('📱 Processing app document $j: ${doc.id}');
                print('📄 Raw data: $data');

                // Ensure required fields
                data['childId'] = widget.childId;

                // Handle date field
                if (!data.containsKey('date') || data['date'] == null) {
                  data['date'] = dateString;
                }

                final appStat = AppUsageStats.fromJson(data);

                // Only include apps with actual usage time
                if (appStat.totalTimeInForeground > 0) {
                  firebaseStats.add(appStat);
                  print(
                    '✅ Added app: ${appStat.appName} with ${appStat.totalTimeInForeground}ms',
                  );
                } else {
                  print('⚠️ Skipped app ${appStat.appName} - no usage time');
                }
              } catch (e, stackTrace) {
                print('❌ Error parsing app stat from Firebase: $e');
                print('Stack trace: $stackTrace');
              }
            }

            if (firebaseStats.isNotEmpty) {
              firebaseStats.sort(
                (a, b) =>
                    b.totalTimeInForeground.compareTo(a.totalTimeInForeground),
              );
              print('✅ Returning ${firebaseStats.length} valid app stats');
              return firebaseStats;
            } else {
              print('⚠️ No valid app stats found in path ${i + 1}');
            }
          } else {
            print('⚠️ No documents found in path ${i + 1}');
          }
        } catch (e) {
          print('⚠️ Path ${i + 1} failed: $e');
        }
      }

      // Try to get all documents in the parent collections to debug
      await _debugFirebaseCollections(dateString);

      print('❌ No app data found in any collection path');
      return [];
    } catch (e, stackTrace) {
      print('❌ Error loading from Firebase: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Helper method to debug Firebase collections
  Future<void> _debugFirebaseCollections(String dateString) async {
    try {
      print('🔍 DEBUG: Checking Firebase collections structure...');

      // Check usage_stats collection
      final usageStatsDoc =
          await FirebaseFirestore.instance
              .collection('usage_stats')
              .doc(widget.childId)
              .get();

      if (usageStatsDoc.exists) {
        // print('✅ usage_stats document exists for child ${widget.childId}');

        // Check daily subcollection
        final dailyCollection =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .get();

        // print(
        //   '📅 Daily collection has ${dailyCollection.docs.length} documents',
        // );
        for (final doc in dailyCollection.docs.take(5)) {
          print('  Document: ${doc.id} - ${doc.data().keys.toList()}');
        }

        // Check specific date
        final dateDoc =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .doc(dateString)
                .get();

        if (dateDoc.exists) {
          print(
            '✅ Date document $dateString exists with keys: ${dateDoc.data()?.keys.toList()}',
          );
        } else {
          print('❌ Date document $dateString does not exist');
        }
      } else {
        print(
          '❌ usage_stats document does not exist for child ${widget.childId}',
        );
      }

      // Check usage_tracking collection
      final usageTrackingDoc =
          await FirebaseFirestore.instance
              .collection('usage_tracking')
              .doc(widget.childId)
              .get();

      if (usageTrackingDoc.exists) {
        print('✅ usage_tracking document exists for child ${widget.childId}');
      } else {
        print(
          '❌ usage_tracking document does not exist for child ${widget.childId}',
        );
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // Helper method to create mock QuerySnapshot for apps stored as array
  dynamic _createMockQuerySnapshot(List appsData, String dateString) {
    // This is a simplified approach - you might need to adjust based on your actual data structure
    final docs =
        appsData.map((appData) {
          return MockDocumentSnapshot(appData as Map<String, dynamic>);
        }).toList();

    return MockQuerySnapshot(docs);
  }

  Map<String, int> _calculateCategoryUsage(List<AppUsageStats> stats) {
    // print('📊 Calculating category usage for ${stats.length} apps');
    final categories = <String, int>{
      'Social Media': 0,
      'Games': 0,
      'Education': 0,
      'Entertainment': 0,
      'Others': 0,
    };

    for (final stat in stats) {
      final category = _getAppCategory(stat.packageName);
      categories[category] =
          (categories[category] ?? 0) + stat.totalTimeInForeground;
      // print(
      //   '  ${stat.appName} (${stat.packageName}) -> $category: ${stat.totalTimeInForeground}ms',
      // );
    }

    // print('📊 Final category usage: $categories');
    return categories;
  }

  String _getAppCategory(String packageName) {
    final lowerPackage = packageName.toLowerCase();

    if (lowerPackage.contains('facebook') ||
        lowerPackage.contains('instagram') ||
        lowerPackage.contains('snapchat') ||
        lowerPackage.contains('tiktok') ||
        lowerPackage.contains('twitter') ||
        lowerPackage.contains('whatsapp')) {
      return 'Social Media';
    } else if (lowerPackage.contains('game') ||
        lowerPackage.contains('play') ||
        lowerPackage.contains('minecraft') ||
        lowerPackage.contains('roblox')) {
      return 'Games';
    } else if (lowerPackage.contains('edu') ||
        lowerPackage.contains('learn') ||
        lowerPackage.contains('khan') ||
        lowerPackage.contains('duolingo')) {
      return 'Education';
    } else if (lowerPackage.contains('youtube') ||
        lowerPackage.contains('netflix') ||
        lowerPackage.contains('spotify') ||
        lowerPackage.contains('video')) {
      return 'Entertainment';
    }
    return 'Others';
  }

  // Date utility functions
  String _formatDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _formatDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Navigation functions
  void _navigateToPreviousDay() {
    final previousDay = _selectedDate.subtract(Duration(days: 1));
    _navigateToDate(previousDay);
  }

  void _navigateToNextDay() {
    final nextDay = _selectedDate.add(Duration(days: 1));
    final now = DateTime.now();

    // Don't allow navigation to future dates
    if (nextDay.isBefore(now) || _isSameDay(nextDay, now)) {
      _navigateToDate(nextDay);
    }
  }

  void _navigateToDate(DateTime date) {
    // print('🗓️ Navigating to date: ${_formatDateString(date)}');
    setState(() {
      _selectedDate = date;
    });
    _loadDataForDate(date);
  }

  void _showDatePicker() async {
    final now = DateTime.now();
    final initialDate = _selectedDate.isAfter(now) ? now : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4C5DF4), // Header background color
              onPrimary: Colors.white, // Header text color),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      _navigateToDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // print(
    //   '🔄 Building widget - Loading: $_isLoading, Apps: ${_currentAppUsageList.length}, Stats: $_currentDayStats',
    // );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '${widget.childName}\'s Activity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showDatePicker,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // print('🔄 Manual refresh triggered');
              // Clear cache for current date
              final dateString = _formatDateString(_selectedDate);
              _dailyStatsCache.remove(dateString);
              _dailyAppsCache.remove(dateString);
              _dailyCategoriesCache.remove(dateString);

              setState(() {
                _isLoading = true;
              });
              _loadDataForDate(_selectedDate);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              // Date navigation
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: _navigateToPreviousDay,
                    ),
                    GestureDetector(
                      onTap: _showDatePicker,
                      child: Column(
                        children: [
                          Text(
                            _formatDisplayDate(_selectedDate),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDayName(_selectedDate),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color:
                            _selectedDate.isBefore(DateTime.now())
                                ? Colors.white
                                : Colors.white30,
                      ),
                      onPressed:
                          _selectedDate.isBefore(DateTime.now())
                              ? _navigateToNextDay
                              : null,
                    ),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Apps'),
                  Tab(text: 'Categories'),
                ],
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Loading activity data...'),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAppsTab(),
                  _buildCategoriesTab(),
                ],
              ),
    );
  }

  Widget _buildOverviewTab() {
    final totalScreenTime =
        _currentDayStats?['totalScreenTimeMinutes'] ??
        _currentDayStats?['timeInMinutes'] ??
        _currentDayStats?['total_screen_time'] ??
        0;
    final appCount =
        _currentDayStats?['appCount'] ??
        _currentDayStats?['app_count'] ??
        _currentAppUsageList.length;

    // print(
    //   '📊 Overview - Screen time: $totalScreenTime, App count: $appCount, Apps list length: ${_currentAppUsageList.length}',
    // );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debug info card (remove in production)
          // Card(
          //   elevation: 2,
          //   color: Colors.blue[50],
          //   child: Padding(
          //     padding: EdgeInsets.all(12),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           '🔍 Debug Info',
          //           style: TextStyle(fontWeight: FontWeight.bold),
          //         ),
          //         SizedBox(height: 8),
          //         Text('Date: ${_formatDateString(_selectedDate)}'),
          //         Text('Child ID: ${widget.childId}'),
          //         Text('Stats available: ${_currentDayStats != null}'),
          //         Text('Apps loaded: ${_currentAppUsageList.length}'),
          //         Text('Categories: ${_currentCategoryUsage.length}'),
          //         if (_currentDayStats != null)
          //           Text('Stats keys: ${_currentDayStats!.keys.toList()}'),
          //       ],
          //     ),
          //   ),
          // ),

          // SizedBox(height: 16),

          // Screen Time Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.phone_android, size: 48, color: Colors.deepPurple),
                  SizedBox(height: 12),
                  Text(
                    'Total Screen Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${totalScreenTime}m',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatDisplayDate(_selectedDate),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Apps Used',
                  '$appCount',
                  Icons.apps,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Average',
                  '${appCount > 0 ? (totalScreenTime / appCount).round() : 0}m',
                  Icons.timeline,
                  Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Most Used Apps
          Text(
            'Most Used Apps',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),

          if (_currentAppUsageList.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.apps, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No app usage data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isToday(_selectedDate)
                        ? 'Use some apps throughout the day'
                        : 'No data recorded for this date',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  // SizedBox(height: 16),
                  // ElevatedButton(
                  //   onPressed: () {
                  //     print('🔄 Debug refresh button pressed');
                  //     final dateString = _formatDateString(_selectedDate);
                  //     _dailyStatsCache.remove(dateString);
                  //     _dailyAppsCache.remove(dateString);
                  //     _dailyCategoriesCache.remove(dateString);
                  //     _loadDataForDate(_selectedDate);
                  //   },
                  //   child: Text('Debug Refresh'),
                  // ),
                ],
              ),
            )
          else
            ..._currentAppUsageList
                .take(5)
                .map((app) => _buildAppUsageItem(app)),
        ],
      ),
    );
  }

  Widget _buildAppsTab() {
    print('📱 Building Apps tab with ${_currentAppUsageList.length} apps');

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Debug info
        // Card(
        //   elevation: 2,
        //   color: Colors.orange[50],
        //   child: Padding(
        //     padding: EdgeInsets.all(12),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           '🔍 Apps Debug Info',
        //           style: TextStyle(fontWeight: FontWeight.bold),
        //         ),
        //         SizedBox(height: 8),
        //         Text('Total apps loaded: ${_currentAppUsageList.length}'),
        //         Text('Cache entries: ${_dailyAppsCache.length}'),
        //         Text('Current date: ${_formatDateString(_selectedDate)}'),
        //         if (_currentAppUsageList.isNotEmpty) ...[
        //           SizedBox(height: 8),
        //           Text('Top app: ${_currentAppUsageList.first.appName}'),
        //           Text(
        //             'Top app time: ${_currentAppUsageList.first.totalTimeInForeground}ms',
        //           ),
        //         ],
        // ],
        //     ),
        //   ),
        // ),

        // SizedBox(height: 16),
        Text(
          'All Apps Usage',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),

        if (_currentAppUsageList.isEmpty)
          Center(
            child: Column(
              children: [
                SizedBox(height: 100),
                Icon(Icons.apps_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No app usage data available',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  _isToday(_selectedDate)
                      ? 'App usage will appear here as you use apps'
                      : 'No app usage recorded for this date',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    print('🔄 Debug: Running Firebase collection check');
                    await _debugFirebaseCollections(
                      _formatDateString(_selectedDate),
                    );
                  },
                  child: Text('Debug Firebase'),
                ),
              ],
            ),
          )
        else
          ..._currentAppUsageList.map((app) => _buildAppUsageItem(app)),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    final totalUsage = _currentCategoryUsage.values.fold(
      0,
      (sum, value) => sum + value,
    );

    print(
      '📊 Building Categories tab - Total usage: $totalUsage, Categories: $_currentCategoryUsage',
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debug info
          // Card(
          //   elevation: 2,
          //   color: Colors.green[50],
          //   child: Padding(
          //     padding: EdgeInsets.all(12),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           '🔍 Categories Debug Info',
          //           style: TextStyle(fontWeight: FontWeight.bold),
          //         ),
          //         SizedBox(height: 8),
          //         Text('Total usage: ${totalUsage}ms'),
          //         Text(
          //           'Categories with data: ${_currentCategoryUsage.entries.where((e) => e.value > 0).length}',
          //         ),
          //         ..._currentCategoryUsage.entries.map(
          //           (entry) => Text('${entry.key}: ${entry.value}ms'),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),

          // SizedBox(height: 16),
          Text(
            'Usage by Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24),

          // Pie Chart
          Container(
            height: 300,
            child:
                totalUsage > 0
                    ? PieChart(
                      PieChartData(
                        sections:
                            _currentCategoryUsage.entries
                                .where((entry) => entry.value > 0)
                                .map(
                                  (entry) => PieChartSectionData(
                                    color: _getCategoryColor(entry.key),
                                    value: entry.value.toDouble(),
                                    title:
                                        '${((entry.value / totalUsage) * 100).round()}%',
                                    radius: 100,
                                    titleStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                                .toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No category data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _isToday(_selectedDate)
                                ? 'Category usage will appear here as you use apps'
                                : 'No category data for this date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
          ),

          SizedBox(height: 24),

          // Category Legend
          if (totalUsage > 0)
            ..._currentCategoryUsage.entries
                .where((entry) => entry.value > 0)
                .map((entry) => _buildCategoryItem(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageItem(AppUsageStats app) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Text(
            app.appName.isNotEmpty ? app.appName[0].toUpperCase() : 'A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(app.appName, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Package: ${app.packageName}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDuration(app.totalTimeInForeground),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            Text(
              '${app.launchCount} launches',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category, int usage) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(category, style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          _formatDuration(usage),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Social Media':
        return Colors.blue;
      case 'Games':
        return Colors.red;
      case 'Education':
        return Colors.green;
      case 'Entertainment':
        return Colors.purple;
      case 'Others':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}

// Mock classes for handling apps stored as arrays
class MockDocumentSnapshot {
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this._data);

  Map<String, dynamic> data() => _data;
  String get id => _data['packageName'] ?? 'unknown';
}

class MockQuerySnapshot {
  final List<MockDocumentSnapshot> docs;

  MockQuerySnapshot(this.docs);
}
