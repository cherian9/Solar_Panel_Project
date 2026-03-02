import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/mongo_service.dart';

const String cloudControlUrl = String.fromEnvironment(
  'CLOUD_CONTROL_URL',
  defaultValue: 'https://0ezk16r0u1.execute-api.ap-south-1.amazonaws.com/control',
);

/// System Control Page - Controls ESP32 via MongoDB Atlas
///
/// Features:
/// - Direct MongoDB Atlas connection
/// - Toggle ON/OFF with optimistic UI updates
/// - Background polling to ESP32 (80 seconds max)
/// - Real-time connection status
/// - Info cards showing system details
class SystemControlPage extends StatefulWidget {
  const SystemControlPage({super.key});

  @override
  State<SystemControlPage> createState() => _SystemControlPageState();
}

class _SystemControlPageState extends State<SystemControlPage> {
  final MongoService _mongoService = MongoService();

  String _status = 'OFF';
  bool _isLoading = true;
  bool _isPolling = false;
  bool _isConnected = false;
  int _pollingToken = 0;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  /// Initialize MongoDB connection and load current state
  Future<void> _initializeSystem() async {
    setState(() => _isLoading = true);

    debugPrint('🔄 Initializing system...');

    // Connect to MongoDB
    final connected = await _mongoService.connect();
    if (!mounted) return;

    setState(() => _isConnected = connected);

    if (connected) {
      // Load current state from database
      final state = await _mongoService.getSystemState();
      if (!mounted) return;

      setState(() {
        _status = state ?? 'OFF';
        _isLoading = false;
      });

      debugPrint('✅ System initialized - Status: $_status');
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSnackBar('❌ Failed to connect to MongoDB Atlas', isError: true);
    }
  }

  /// Toggle system ON/OFF
  Future<void> _toggleSystem() async {
    if (_isLoading || !_isConnected) {
      _showSnackBar('Cannot toggle - not connected to database', isError: true);
      return;
    }

    final previousState = _status;
    final nextState = previousState == 'ON' ? 'OFF' : 'ON';
    final pollId = DateTime.now().millisecondsSinceEpoch;

    // Cancel any existing polling
    _pollingToken = pollId;

    // 1. Immediately update UI (optimistic update)
    setState(() {
      _status = nextState;
      _isPolling = true;
    });

    debugPrint('🔄 Toggle: $previousState → $nextState');

    try {
      // 2. Update MongoDB database
      final success = await _mongoService.updateSystemState(nextState);

      if (!success) {
        throw Exception('Failed to update MongoDB');
      }

      debugPrint('✅ Database updated to: $nextState');

      // 3. Start background polling to ESP32
      _pollCloudAPI(nextState, pollId);
    } catch (err) {
      debugPrint('❌ Toggle error: $err');

      // Rollback on error
      if (!mounted) return;
      setState(() {
        _status = previousState;
        _isPolling = false;
      });

      _showSnackBar('Toggle failed: $err', isError: true);
    }
  }

  /// Poll ESP32 cloud API for hardware confirmation
  /// Runs in background for up to 80 seconds
  Future<void> _pollCloudAPI(String desiredState, int pollId) async {
    const maxAttempts = 80;
    debugPrint('🔄 [Poll $pollId] Background polling started - Target: $desiredState');

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // Check if polling was cancelled
      if (_pollingToken != pollId) {
        debugPrint('❌ [Poll $pollId] Cancelled - New polling started');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));

      // Double-check after delay
      if (_pollingToken != pollId) return;

      try {
        final response = await http.post(
          Uri.parse(cloudControlUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'state': desiredState.toLowerCase()}),
        );

        if (response.statusCode != 200) {
          debugPrint('📡 [Poll $pollId] [${attempt + 1}s] HTTP ${response.statusCode}');
          continue;
        }

        final decoded = jsonDecode(response.body);
        final espState = decoded is Map<String, dynamic>
            ? decoded['state']?.toString().toUpperCase()
            : 'UNKNOWN';

        debugPrint('📡 [Poll $pollId] [${attempt + 1}s] ESP State: $espState | Target: $desiredState');

        // Check if ESP confirmed the state
        if (espState == desiredState) {
          debugPrint('✅ [Poll $pollId] SUCCESS at ${attempt + 1}s - ESP confirmed $desiredState');

          if (!mounted || _pollingToken != pollId) return;
          setState(() => _isPolling = false);

          _showSnackBar('✓ ESP32 confirmed $desiredState state');
          return;
        }
      } catch (err) {
        debugPrint('❌ [Poll $pollId] [${attempt + 1}s] Cloud API error: $err');
      }
    }

    // Timeout after 80 seconds
    debugPrint('⚠️ [Poll $pollId] Timeout after 80 seconds');

    if (!mounted || _pollingToken != pollId) return;
    setState(() => _isPolling = false);

    _showSnackBar('⚠ ESP32 did not confirm within 80 seconds', isError: true);
  }

  /// Show a snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  void dispose() {
    _mongoService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _status == 'ON';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('System Control'),
        backgroundColor: const Color(0xFF141B3D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Cards Grid
              _buildInfoGrid(),

              const SizedBox(height: 40),

              // Power Button
              Center(child: _buildPowerButton(isOn)),

              const SizedBox(height: 30),

              // Status Display
              _buildStatusDisplay(isOn),

              const SizedBox(height: 30),

              // Refresh Button
              _buildRefreshButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build info cards grid
  Widget _buildInfoGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _InfoCard(
          icon: Icons.location_on,
          label: 'Location',
          value: 'AWS ap-south-1',
          color: Colors.blue,
        ),
        _InfoCard(
          icon: Icons.memory,
          label: 'Mode',
          value: 'Active',
          color: Colors.purple,
        ),
        _InfoCard(
          icon: Icons.wifi,
          label: 'Connection',
          value: _isLoading
              ? 'Loading...'
              : _isPolling
                  ? 'Syncing'
                  : _isConnected
                      ? 'Connected'
                      : 'Disconnected',
          color: _isConnected ? Colors.green : Colors.red,
        ),
        _InfoCard(
          icon: Icons.power_settings_new,
          label: 'Status',
          value: _isLoading ? 'Loading...' : _status,
          color: _status == 'ON' ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  /// Build the power button
  Widget _buildPowerButton(bool isOn) {
    final buttonColor = _isLoading
        ? Colors.grey
        : isOn
            ? Colors.green
            : Colors.red;

    return GestureDetector(
      onTap: _isLoading ? null : _toggleSystem,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor.withOpacity(0.15),
          border: Border.all(
            color: buttonColor,
            width: 6,
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: _isLoading || _isPolling
              ? const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isOn ? Icons.toggle_on : Icons.toggle_off,
                  size: 110,
                  color: buttonColor,
                ),
        ),
      ),
    );
  }

  /// Build status display section
  Widget _buildStatusDisplay(bool isOn) {
    final statusColor = _isLoading
        ? Colors.grey
        : isOn
            ? Colors.green
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF141B3D),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            _getStatusHeadline(isOn),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusSubtext(isOn),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Build refresh button
  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _initializeSystem,
      icon: const Icon(Icons.refresh),
      label: const Text('Refresh State'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getStatusHeadline(bool isOn) {
    if (_isLoading) return 'LOADING...';
    if (_isPolling) return 'SYNCHRONIZING...';
    return isOn ? '✓ SYSTEM OPERATIONAL' : '⚠ SYSTEM OFFLINE';
  }

  String _getStatusSubtext(bool isOn) {
    if (_isLoading) return 'Fetching system status';
    if (_isPolling) return 'Connecting to ESP Device';
    return isOn ? 'All systems running normally' : 'Press button to activate';
  }
}

/// Info Card Widget
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF141B3D),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
