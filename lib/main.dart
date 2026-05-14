import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentiment_analyzer/auth_page.dart';
import 'package:sentiment_analyzer/database_helper.dart';
import 'mood_graph.dart';

void main() {
  runApp(const MoodDiaryApp());
}

class MoodDiaryApp extends StatefulWidget {
  const MoodDiaryApp({super.key});

  @override
  State<MoodDiaryApp> createState() => _MoodDiaryAppState();
}

class _MoodDiaryAppState extends State<MoodDiaryApp> {
  int? _currentUserId;
  bool _isCheckingAuth = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _isDarkMode = isDark;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    
    setState(() {
      _currentUserId = userId;
      _isCheckingAuth = false;
    });
  }

  void _handleLogin(int userId) {
    setState(() {
      _currentUserId = userId;
    });
    
    // Save userId to persistent storage
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('userId', userId);
    });
  }

  void _handleLogout() {
    setState(() {
      _currentUserId = null;
    });
    
    // Clear userId from persistent storage
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('userId');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Diary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _isCheckingAuth
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _currentUserId == null
              ? AuthPage(onLoginSuccess: _handleLogin)
              : HomePage(
                  userId: _currentUserId!,
                  onLogout: _handleLogout,
                  onThemeToggle: _toggleTheme,
                ),
    );
  }
}

class HomePage extends StatefulWidget {
  final int userId;
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;

  const HomePage({
    super.key,
    required this.userId,
    required this.onLogout,
    required this.onThemeToggle,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dbHelper = DatabaseHelper();
  List<Mood> _moods = [];
  bool _isAnalyzing = false;
  bool _isLoadingMoods = true;

  @override
  void initState() {
    super.initState();
    _loadMoods();
  }

  Future<void> _loadMoods() async {
    setState(() {
      _isLoadingMoods = true;
    });
    
    final moods = await _dbHelper.getUserMoods(widget.userId);
    
    setState(() {
      _moods = moods;
      _isLoadingMoods = false;
    });
  }

  Future<void> _addNote(String note) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final sentimentScore = await _analyzeSentiment(note);

      // Create mood object
      final mood = Mood(
        userId: widget.userId,
        content: note,
        sentimentScore: sentimentScore,
        date: DateTime.now().toString().substring(0, 16),
        createdAt: DateTime.now().toString(),
      );

      // Save to database
      await _dbHelper.insertMood(mood);

      // Reload moods
      await _loadMoods();
    } catch (e) {
      developer.log('ERROR analyzing sentiment: $e', level: 800);
      
      // Save with neutral score if analysis fails
      final mood = Mood(
        userId: widget.userId,
        content: note,
        sentimentScore: 0.5,
        date: DateTime.now().toString().substring(0, 16),
        createdAt: DateTime.now().toString(),
      );

      await _dbHelper.insertMood(mood);
      await _loadMoods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saved, but sentiment analysis failed: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<double> _analyzeSentiment(String note) async {
    developer.log('Analyzing sentiment for: $note');
    
    final apiUrl = _getSentimentApiUrl();
    final uri = Uri.parse('$apiUrl/analyze');
    
    developer.log('Request URI: $uri');
    
    final requestBody = {'text': note};
    
    developer.log('Request body: ${jsonEncode(requestBody)}');
    
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      developer.log('Response Status: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final score = responseData['score'] as double;
        developer.log('Parsed Score: $score');
        return score.clamp(0.0, 1.0);
      } else {
        final errorMsg = 'API Error ${response.statusCode}: ${response.body}';
        developer.log(errorMsg, level: 800);
        throw Exception(errorMsg);
      }
    } on TimeoutException {
      throw Exception('Sentiment API timeout - is the Python server running on localhost:5000?');
    } catch (e) {
      throw Exception('Failed to analyze sentiment: $e');
    }
  }

  String _getSentimentApiUrl() {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    if (Platform.isAndroid) {
      return 'http://192.168.1.183:5000';
    }
    
    return 'http://localhost:5000';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Mood Diary',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.show_chart,
                    color: _moods.isEmpty
                        ? Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.5)
                        : Theme.of(context).colorScheme.onInverseSurface,
                  ),
                  onPressed: _moods.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MoodGraphPage(notesWithScores: _moods),
                            ),
                          );
                        },
                  tooltip: 'View Mood Graph',
                  iconSize: 28,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      widget.onLogout();
                    } else if (value == 'theme') {
                      widget.onThemeToggle();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'theme',
                      child: Row(
                        children: [
                          Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Theme.of(context).brightness == Brightness.dark
                                ? 'Light Mode'
                                : 'Dark Mode',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          const SizedBox(width: 12),
                          const Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.menu,
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingMoods
          ? const Center(child: CircularProgressIndicator())
          : _moods.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                Theme.of(context).colorScheme.primary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.note_add,
                            size: 100,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Welcome to Your Mood Diary',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onBackground,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Track your daily moods and emotions. Tap the + button below to share how you\'re feeling today!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Recent Moods',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniStatCard(
                                    context,
                                    'Total',
                                    '${_moods.length}',
                                    '📊',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniStatCard(
                                    context,
                                    'Average',
                                    '${(_moods.isEmpty ? 0 : (_moods.fold<double>(0, (sum, mood) => sum + mood.sentimentScore) / _moods.length) * 100).toStringAsFixed(0)}%',
                                    _getMoodEmojiFromScore(_moods.isEmpty ? 0.5 : _moods.fold<double>(0, (sum, mood) => sum + mood.sentimentScore) / _moods.length),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) {
                            final mood = _moods[index];
                            final sentimentPercent = ((mood.sentimentScore) * 100).toInt();
                            return _buildNoteCard(context, mood, sentimentPercent);
                          },
                          childCount: _moods.length,
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 8,
        onPressed: _isAnalyzing
            ? null
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddNotePage()),
                );
                if (result != null && result is String) {
                  _addNote(result);
                }
              },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add, size: 28),
        label: _isAnalyzing ? const Text('Analyzing...') : const Text('Add Mood'),
      ),
    );
  }

  Widget _buildMiniStatCard(BuildContext context, String label, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Mood mood, int sentimentPercent) {
    final moodColor = _getMoodColor(mood.sentimentScore);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: moodColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: moodColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getMoodEmojiFromScore(mood.sentimentScore),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mood.content.length > 50
                            ? '${mood.content.substring(0, 50)}...'
                            : mood.content,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mood.date,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: mood.sentimentScore,
                backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(moodColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$sentimentPercent% happiness',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: moodColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getMoodLabel(mood.sentimentScore),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: moodColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return Colors.green;
    } else if (sentimentScore >= 0.4) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }

  String _getMoodEmojiFromScore(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return '😊';
    } else if (sentimentScore >= 0.4) {
      return '😐';
    } else {
      return '😞';
    }
  }

  String _getMoodLabel(double sentimentScore) {
    if (sentimentScore >= 0.7) {
      return 'Happy';
    } else if (sentimentScore >= 0.4) {
      return 'Neutral';
    } else {
      return 'Sad';
    }
  }
}

class AddNotePage extends StatefulWidget {
  const AddNotePage({super.key});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  void _save() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _isSaving = true;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context, _controller.text.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'How Are You Feeling?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving || _controller.text.trim().isEmpty ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 24),
              label: _isSaving ? const Text('Saving...') : const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share your thoughts and feelings:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind today?\n\nShare anything you\'d like to remember...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
                            fontSize: 15,
                            height: 1.6,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onBackground,
                          height: 1.6,
                        ),
                        cursorColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving || _controller.text.trim().isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Analyzing Mood...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 22, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Save Mood Entry',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
