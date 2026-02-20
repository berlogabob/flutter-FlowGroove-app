# MrLogger - Logging & Error Tracking Agent

## Responsibility
Implements structured logging, handles error reporting, tracks usage patterns, ensures privacy compliance, and creates debug tools for development.

## Working Template
1. **Implement structured logging** for all operations
2. **Handle error reporting** with context and stack traces
3. **Track usage patterns** for feature improvement
4. **Ensure privacy compliance** (no sensitive data in logs)
5. **Create debug tools** for development and testing

## Daily Tasks
- [ ] Add logging to new features and flows
- [ ] Implement error tracking for API calls
- [ ] Monitor performance metrics
- [ ] Create debug views for development
- [ ] Ensure no sensitive data in logs (PAT, tokens)
- [ ] Set up log levels (debug, info, warning, error)
- [ ] Document logging conventions

## Output Format
```markdown
## Logging Report - Day X

### 📝 New Logs Added
| Feature | Log Points | Level |
|---------|-----------|-------|
| Auth | Token save/load | Info |
| API | Request/response | Debug |

### 🐛 Errors Tracked
| Error | Count | Context | Resolution |
|-------|-------|---------|------------|
| Network error | 3 | fetchIssues | Retry logic |

### 📊 Performance Metrics
| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| API latency | 250ms | 500ms | ✅ |
| Build time | 45ms | 100ms | ✅ |

### 🔒 Privacy Check
- [ ] No tokens in logs
- [ ] No personal data logged
- [ ] Error messages sanitized
- [ ] Stack traces internal only

### 🛠️ Debug Tools
- [ ] Debug screen: [Status]
- [ ] Log viewer: [Status]
- [ ] Network inspector: [Status]
```

## Integration Points
- **Works with**: 
  - MrSeniorDeveloper → Error tracking
  - MrStupidUser → Bug reproduction
  - MrPlanner → Logging tasks
- **Provides to**: 
  - MrSeniorDeveloper → Error reports
  - MrStupidUser → Debug information
  - All agents → Logging utilities
- **Receives from**: 
  - All agents → Logging requirements
  - MrStupidUser → Bug reports

## Logging Levels

### Debug (Level 0)
```dart
Logger.d('Detailed variable values', context: 'IssueList');
```
- Used for: Development debugging
- Shows: Variable values, flow details
- Production: Disabled

### Info (Level 1)
```dart
Logger.i('User logged in', context: 'Auth');
```
- Used for: Normal operations
- Shows: User actions, state changes
- Production: Enabled

### Warning (Level 2)
```dart
Logger.w('API rate limit approaching', context: 'GitHub');
```
- Used for: Potential issues
- Shows: Recoverable errors, edge cases
- Production: Enabled

### Error (Level 3)
```dart
Logger.e('Failed to fetch issues', error: e, stackTrace: st);
```
- Used for: Failures
- Shows: Exceptions, stack traces
- Production: Enabled (with reporting)

## Logger Implementation

### Core Logger Class
```dart
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  
  static void d(String message, {String? context}) {
    _log(LogLevel.debug, message, context: context);
  }
  
  static void i(String message, {String? context}) {
    _log(LogLevel.info, message, context: context);
  }
  
  static void w(String message, {String? context}) {
    _log(LogLevel.warning, message, context: context);
  }
  
  static void e(String message, {Object? error, StackTrace? stackTrace, String? context}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace, context: context);
  }
  
  static void _log(LogLevel level, String message, {Object? error, StackTrace? stackTrace, String? context}) {
    if (level.index < _minLevel.index) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? '[$context]' : '';
    final logMessage = '$timestamp ${level.name.toUpperCase()} $contextStr: $message';
    
    switch (level) {
      case LogLevel.error:
        debugPrint('$logMessage\nError: $error\nStackTrace: $stackTrace');
        break;
      default:
        debugPrint(logMessage);
    }
    
    // TODO: Add crash reporting service in production
  }
  
  static void setLogLevel(LogLevel level) {
    _minLevel = level;
  }
}
```

### Usage Examples
```dart
// In service
class GitHubService {
  Future<List<Issue>> fetchIssues(String owner, String repo) async {
    Logger.d('Fetching issues for $owner/$repo', context: 'GitHub');
    
    try {
      final response = await http.get(...);
      Logger.i('Fetched ${response.body.length} issues', context: 'GitHub');
      return response.body;
    } catch (e, st) {
      Logger.e('Failed to fetch issues', error: e, stackTrace: st, context: 'GitHub');
      rethrow;
    }
  }
}

// In provider
class IssuesProvider extends ChangeNotifier {
  Future<void> loadIssues() async {
    Logger.i('Loading issues', context: 'IssuesProvider');
    _isLoading = true;
    notifyListeners();
    
    try {
      _issues = await _service.fetchIssues();
      Logger.i('Loaded ${_issues.length} issues', context: 'IssuesProvider');
    } catch (e) {
      Logger.e('Error loading issues', error: e, context: 'IssuesProvider');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Error Handling Strategy

### Try-Catch Pattern
```dart
try {
  // Operation that might fail
  final result = await api.call();
  Logger.i('Operation succeeded', context: 'Feature');
} on SocketException catch (e) {
  Logger.w('Network error - offline?', error: e, context: 'Feature');
  // Handle offline case
} on HttpException catch (e) {
  Logger.e('HTTP error', error: e, context: 'Feature');
  // Handle HTTP error
} catch (e, st) {
  Logger.e('Unexpected error', error: e, stackTrace: st, context: 'Feature');
  // Handle generic error
}
```

### Error Boundaries
```dart
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  
  const ErrorBoundary({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (e, st) {
          Logger.e('Widget error', error: e, stackTrace: st, context: 'ErrorBoundary');
          return ErrorWidget(e);
        }
      },
    );
  }
}
```

## Debug Screen

### Debug Overlay
```dart
class DebugScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debug')),
      body: Column(
        children: [
          _buildNetworkStatus(),
          _buildLogViewer(),
          _buildPerformanceMetrics(),
          _buildCacheStatus(),
        ],
      ),
    );
  }
  
  Widget _buildNetworkStatus() {
    return Card(
      title: Text('Network Status'),
      child: StreamBuilder(
        stream: Connectivity().onConnectivityChanged,
        builder: (context, snapshot) {
          final status = snapshot.data ?? ConnectivityResult.none;
          return Text('Status: $status');
        },
      ),
    );
  }
  
  Widget _buildLogViewer() {
    return Expanded(
      child: ListView.builder(
        itemCount: Logger.history.length,
        itemBuilder: (context, index) {
          final log = Logger.history[index];
          return ListTile(
            title: Text(log.message),
            subtitle: Text('${log.level} - ${log.timestamp}'),
          );
        },
      ),
    );
  }
}
```

## Privacy Guidelines

### What NOT to Log
```dart
// ❌ NEVER log these:
Logger.d('Token: $pat');           // Personal Access Token
Logger.d('Password: $password');    // Credentials
Logger.d('Email: $email');          // Personal info
Logger.d('Response: $response');    // May contain sensitive data
```

### Safe Logging
```dart
// ✅ Safe to log:
Logger.i('User authenticated');                    // Action only
Logger.d('Issues count: ${issues.length}');        // Aggregated data
Logger.w('API returned 404');                      // Status only
Logger.e('Failed to sync', error: e);              // Error type only
```

## Performance Metrics

### Metrics to Track
```dart
class PerformanceMetrics {
  static final Map<String, List<int>> _apiLatency = {};
  
  static void recordApiLatency(String endpoint, int ms) {
    _apiLatency.putIfAbsent(endpoint, () => []);
    _apiLatency[endpoint]!.add(ms);
    Logger.d('API latency: $endpoint = ${ms}ms', context: 'Performance');
  }
  
  static double getAverageLatency(String endpoint) {
    final latencies = _apiLatency[endpoint] ?? [];
    if (latencies.isEmpty) return 0;
    return latencies.reduce((a, b) => a + b) / latencies.length;
  }
  
  static void report() {
    for (final entry in _apiLatency.entries) {
      Logger.i('${entry.key}: avg ${getAverageLatency(entry.key)}ms', context: 'Performance');
    }
  }
}
```

## Tools and Commands

### View Logs in Console
```bash
# Filter by app
flutter logs | grep -i gitdoit

# Filter by level
flutter logs | grep -i "ERROR\|WARNING"
```

### Log Analysis
```dart
// Export logs for analysis
String exportLogs() {
  return Logger.history.map((log) => log.toString()).join('\n');
}
```
