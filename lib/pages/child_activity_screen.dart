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
    return AppUsageStats(
      appName: json['appName'] ?? '',
      packageName: json['packageName'] ?? '',
      totalTimeInForeground: json['totalTimeInForeground'] ?? 0,
      launchCount: json['launchCount'] ?? 0,
      lastTimeUsed: json['lastTimeUsed'] ?? 0,
      childId: json['childId'] ?? '',
      date:
          json['date'] is String
              ? DateTime.tryParse(json['date']) ?? DateTime.now()
              : DateTime.now(),
    );
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
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = DateTime.now();
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadDataForDate(_selectedDate);
    } catch (e) {
      print('Error initializing screen: $e');
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

    // Check cache first
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
      // Load stats and apps for the specific date
      await Future.wait([_loadStatsForDate(date), _loadAppsForDate(date)]);
    } catch (e) {
      print('Error loading data for date $dateString: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      print('Loading stats for date: $dateString, childId: ${widget.childId}');

      // Check if it's today - use real-time data
      if (_isToday(date)) {
        await _loadTodayRealTimeStats(dateString);
      } else {
        await _loadHistoricalStats(dateString);
      }
    } catch (e) {
      print('Error loading stats for date: $e');
    }
  }

  Future<void> _loadTodayRealTimeStats(String dateString) async {
    try {
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
        print('Found today stats: $statsData');
      } else {
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
          print('Found stats in alternative collection');
        }
      }

      // Cache and update current stats
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });
    } catch (e) {
      print('Error loading today real-time stats: $e');
    }
  }

  Future<void> _loadHistoricalStats(String dateString) async {
    try {
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

      for (final doc in results) {
        if (doc.exists && doc.data() != null) {
          statsData = doc.data() as Map<String, dynamic>?;
          print('Found historical stats for $dateString: $statsData');
          break;
        }
      }

      // Cache and update current stats
      _dailyStatsCache[dateString] = statsData;
      setState(() {
        _currentDayStats = statsData;
      });
    } catch (e) {
      print('Error loading historical stats: $e');
    }
  }

  Future<void> _loadAppsForDate(DateTime date) async {
    try {
      final dateString = _formatDateString(date);
      print('Loading apps for date: $dateString');

      List<AppUsageStats> appStats = [];

      // Try both today and historical data approaches
      appStats = await _loadAppStatsFromFirebase(dateString);

      // Calculate category usage
      final categoryUsage = _calculateCategoryUsage(appStats);

      // Cache the results
      _dailyAppsCache[dateString] = appStats;
      _dailyCategoriesCache[dateString] = categoryUsage;

      setState(() {
        _currentAppUsageList = appStats;
        _currentCategoryUsage = categoryUsage;
      });

      print('Loaded ${appStats.length} apps for $dateString');
    } catch (e) {
      print('Error loading apps for date: $e');
    }
  }

  Future<List<AppUsageStats>> _loadAppStatsFromFirebase(
    String dateString,
  ) async {
    try {
      print('Loading app usage from Firebase for date: $dateString');

      // Try to get data from the original approach first (from the first screen)
      DateTime startDate;
      DateTime endDate = DateTime.now();

      // Use the same date logic as the original screen
      startDate = DateTime.parse(dateString);
      endDate = startDate.add(Duration(days: 1));

      // Query usage stats from Firestore (original approach)
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

      List<AppUsageStats> stats = [];

      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          data['childId'] = widget.childId;

          // Handle date field
          if (!data.containsKey('date') || data['date'] == null) {
            data['date'] = dateString;
          }

          final appStat = AppUsageStats.fromJson(data);
          if (appStat.totalTimeInForeground > 0) {
            stats.add(appStat);
          }
        } catch (e) {
          print('Error parsing app stat from Firebase: $e');
        }
      }

      if (stats.isNotEmpty) {
        stats.sort(
          (a, b) => b.totalTimeInForeground.compareTo(a.totalTimeInForeground),
        );
        return stats;
      }

      // Fallback to the new collection structure
      final futures = [
        // Try main collection
        FirebaseFirestore.instance
            .collection('usage_stats')
            .doc(widget.childId)
            .collection('daily')
            .doc(dateString)
            .collection('apps')
            .get(),
        // Try alternative collection
        FirebaseFirestore.instance
            .collection('usage_tracking')
            .doc(widget.childId)
            .collection('daily_stats')
            .doc(dateString)
            .collection('apps')
            .get(),
      ];

      final results = await Future.wait(futures);

      for (final appsQuery in results) {
        if (appsQuery.docs.isNotEmpty) {
          print('Found ${appsQuery.docs.length} apps in Firebase');

          final List<AppUsageStats> firebaseStats = [];
          for (final doc in appsQuery.docs) {
            try {
              final data = doc.data();
              data['childId'] = widget.childId;

              // Handle date field
              if (!data.containsKey('date') || data['date'] == null) {
                data['date'] = dateString;
              }

              final appStat = AppUsageStats.fromJson(data);
              if (appStat.totalTimeInForeground > 0) {
                firebaseStats.add(appStat);
              }
            } catch (e) {
              print('Error parsing app stat from Firebase: $e');
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
      }

      return [];
    } catch (e) {
      print('Error loading from Firebase: $e');
      return [];
    }
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
            colorScheme: ColorScheme.light(primary: const Color(0xFF4C5DF4)),
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
        backgroundColor: const Color(0xFF4C5DF4),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showDatePicker,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
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
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF4C5DF4),
                  ),
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
        _calculateTotalScreenTimeFromApps();
    final appCount =
        _currentDayStats?['appCount'] ?? _currentAppUsageList.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Icon(
                    Icons.phone_android,
                    size: 48,
                    color: const Color(0xFF4C5DF4),
                  ),
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
                    _formatDuration(
                      totalScreenTime is int
                          ? totalScreenTime
                          : (totalScreenTime * 60000).round(),
                    ),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4C5DF4),
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
                  '${appCount > 0 ? _formatDuration((totalScreenTime is int ? totalScreenTime : (totalScreenTime * 60000).round()) ~/ appCount) : "0m"}',
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
          backgroundColor: const Color.fromARGB(255, 2, 214, 30),
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
                color: const Color.fromARGB(255, 2, 214, 30),
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
            color: const Color.fromARGB(255, 2, 214, 30),
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

  int _calculateTotalScreenTimeFromApps() {
    return _currentAppUsageList.fold(
      0,
      (total, app) => total + app.totalTimeInForeground,
    );
  }
}
