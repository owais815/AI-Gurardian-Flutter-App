import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// AppUsageStats model (unchanged)
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
      return appStats;
    } catch (e, stackTrace) {
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

  // Blocked apps cache
  final Map<String, Map<String, dynamic>> _blockedAppsCache = {};

  @override
  void initState() {
    super.initState();
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
    try {
      await Future.wait([_loadDataForDate(_selectedDate), _loadBlockedApps()]);
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

  Future<void> _loadBlockedApps() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('blocked_apps')
              .doc(widget.childId)
              .collection('apps')
              .get();

      final blockedApps = <String, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        blockedApps[doc.id] = doc.data();
      }
      setState(() {
        _blockedAppsCache.addAll(blockedApps);
      });
    } catch (e) {
      print('❌ Error loading blocked apps: $e');
    }
  }

  Future<void> _blockApp(AppUsageStats app, {Duration? duration}) async {
    try {
      final blockData = {
        'appName': app.appName,
        'packageName': app.packageName,
        'blockedAt': Timestamp.now(),
        'durationMs': duration?.inMilliseconds ?? -1, // -1 for indefinite block
        'isBlocked': true,
      };

      await FirebaseFirestore.instance
          .collection('blocked_apps')
          .doc(widget.childId)
          .collection('apps')
          .doc(app.packageName)
          .set(blockData);

      setState(() {
        _blockedAppsCache[app.packageName] = blockData;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${app.appName} has been blocked')),
      );
    } catch (e) {
      print('❌ Error blocking app: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to block ${app.appName}')));
    }
  }

  Future<void> _unblockApp(String packageName, String appName) async {
    try {
      await FirebaseFirestore.instance
          .collection('blocked_apps')
          .doc(widget.childId)
          .collection('apps')
          .doc(packageName)
          .delete();

      setState(() {
        _blockedAppsCache.remove(packageName);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$appName has been unblocked')));
    } catch (e) {
      print('❌ Error unblocking app: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to unblock $appName')));
    }
  }

  void _showBlockDialog(AppUsageStats app) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Block ${app.appName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose how long to block ${app.appName}:'),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Until Manually Unblocked'),
                  onTap: () {
                    _blockApp(app);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('For 1 Hour'),
                  onTap: () {
                    _blockApp(app, duration: Duration(hours: 1));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('For 24 Hours'),
                  onTap: () {
                    _blockApp(app, duration: Duration(hours: 24));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadDataForDate(DateTime date) async {
    final dateString = _formatDateString(date);
    if (_dailyStatsCache.containsKey(dateString) &&
        _dailyAppsCache.containsKey(dateString)) {
      setState(() {
        _currentDayStats = _dailyStatsCache[dateString];
        _currentAppUsageList = _dailyAppsCache[dateString] ?? [];
        _currentCategoryUsage = _dailyCategoriesCache[dateString] ?? {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([_loadStatsForDate(date), _loadAppsForDate(date)]);
    } catch (e, stackTrace) {
      print('❌ Error loading data for date $dateString: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      if (_isToday(date)) {
        await _loadTodayRealTimeStats(dateString);
      } else {
        await _loadHistoricalStats(dateString);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading stats for date: $e');
    }
  }

  Future<void> _loadTodayRealTimeStats(String dateString) async {
    try {
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
      } else {
        final altDoc =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .doc(dateString)
                .get();
        if (altDoc.exists && altDoc.data() != null) {
          statsData = altDoc.data();
        }
      }
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading today real-time stats: $e');
    }
  }

  Future<void> _loadHistoricalStats(String dateString) async {
    try {
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
      for (var doc in results) {
        if (doc.exists && doc.data() != null) {
          statsData = doc.data() as Map<String, dynamic>?;
          break;
        }
      }
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading historical stats: $e');
    }
  }

  Future<void> _loadAppsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      List<AppUsageStats> appStats = [];
      if (_isToday(date)) {
        appStats = await _loadTodayAppStats(dateString);
      } else {
        appStats = await _loadHistoricalAppStats(dateString);
      }
      final categoryUsage = _calculateCategoryUsage(appStats);
      _dailyAppsCache[dateString] = appStats;
      _dailyCategoriesCache[dateString] = categoryUsage;
      setState(() {
        _currentAppUsageList = appStats;
        _currentCategoryUsage = categoryUsage;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading apps for date: $e');
    }
  }

  Future<List<AppUsageStats>> _loadTodayAppStats(String dateString) async {
    return await _loadAppStatsFromFirebase(dateString);
  }

  Future<List<AppUsageStats>> _loadHistoricalAppStats(String dateString) async {
    return await _loadAppStatsFromFirebase(dateString);
  }

  Future<List<AppUsageStats>> _loadAppStatsFromFirebase(
    String dateString,
  ) async {
    try {
      final collectionPaths = [
        () async =>
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .doc(dateString)
                .collection('apps')
                .get(),
        () async =>
            await FirebaseFirestore.instance
                .collection('usage_tracking')
                .doc(widget.childId)
                .collection('daily_stats')
                .doc(dateString)
                .collection('apps')
                .get(),
        () async {
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
              return _createMockQuerySnapshot(appsData, dateString);
            }
          }
          throw Exception('No apps field found');
        },
      ];

      for (var path in collectionPaths) {
        try {
          final appsQuery = await path();
          if (appsQuery.docs.isNotEmpty) {
            final List<AppUsageStats> firebaseStats = [];
            for (var doc in appsQuery.docs) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data['childId'] = widget.childId;
              if (!data.containsKey('date') || data['date'] == null) {
                data['date'] = dateString;
              }
              final appStat = AppUsageStats.fromJson(data);
              if (appStat.totalTimeInForeground > 0) {
                firebaseStats.add(appStat);
              }
            }
            if (firebaseStats.isNotEmpty) {
              firebaseStats.sort(
                (a, b) =>
                    b.totalTimeInForeground.compareTo(a.totalTimeInForeground),
              );
              return firebaseStats;
            }
          }
        } catch (e) {}
      }
      await _debugFirebaseCollections(dateString);
      return [];
    } catch (e, stackTrace) {
      print('❌ Error loading from Firebase: $e');
      return [];
    }
  }

  Future<void> _debugFirebaseCollections(String dateString) async {
    try {
      final usageStatsDoc =
          await FirebaseFirestore.instance
              .collection('usage_stats')
              .doc(widget.childId)
              .get();
      if (usageStatsDoc.exists) {
        final dailyCollection =
            await FirebaseFirestore.instance
                .collection('usage_stats')
                .doc(widget.childId)
                .collection('daily')
                .get();
        for (var doc in dailyCollection.docs.take(5)) {
          print('  Document: ${doc.id} - ${doc.data().keys.toList()}');
        }
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

  dynamic _createMockQuerySnapshot(List appsData, String dateString) {
    final docs =
        appsData
            .map(
              (appData) =>
                  MockDocumentSnapshot(appData as Map<String, dynamic>),
            )
            .toList();
    return MockQuerySnapshot(docs);
  }

  Map<String, int> _calculateCategoryUsage(List<AppUsageStats> stats) {
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
    }
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

  void _navigateToPreviousDay() {
    final previousDay = _selectedDate.subtract(Duration(days: 1));
    _navigateToDate(previousDay);
  }

  void _navigateToNextDay() {
    final nextDay = _selectedDate.add(Duration(days: 1));
    final now = DateTime.now();
    if (nextDay.isBefore(now) || _isSameDay(nextDay, now)) {
      _navigateToDate(nextDay);
    }
  }

  void _navigateToDate(DateTime date) {
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
              primary: Color(0xFF4C5DF4),
              onPrimary: Colors.white,
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
              final dateString = _formatDateString(_selectedDate);
              _dailyStatsCache.remove(dateString);
              _dailyAppsCache.remove(dateString);
              _dailyCategoriesCache.remove(dateString);
              _blockedAppsCache.clear();
              setState(() {
                _isLoading = true;
              });
              _initializeScreen();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usage by Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24),
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
    final isBlocked = _blockedAppsCache.containsKey(app.packageName);
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBlocked ? Colors.red : Colors.deepPurple,
          child: Text(
            app.appName.isNotEmpty ? app.appName[0].toUpperCase() : 'A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          app.appName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isBlocked ? Colors.red : Colors.black,
          ),
        ),
        subtitle: Text(
          'Package: ${app.packageName}${isBlocked ? '\nBlocked' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: isBlocked ? Colors.red : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
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
            SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isBlocked ? Icons.lock_open : Icons.lock,
                color: isBlocked ? Colors.green : Colors.red,
              ),
              onPressed: () {
                if (isBlocked) {
                  _unblockApp(app.packageName, app.appName);
                } else {
                  _showBlockDialog(app);
                }
              },
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

// Mock classes for QuerySnapshot
class MockDocumentSnapshot {
  final Map<String, dynamic> data;
  MockDocumentSnapshot(this.data);
}

class MockQuerySnapshot {
  final List<MockDocumentSnapshot> docs;
  MockQuerySnapshot(this.docs);
}
