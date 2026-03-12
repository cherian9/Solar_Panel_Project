import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'mongo_service.dart';

// Camera view widget for live panel monitoring with quadrants
class CameraView extends StatefulWidget {
  final Map<String, dynamic>? inspectionData;

  const CameraView({Key? key, this.inspectionData}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late Timer timer;
  int urlIndex = 0;
  bool manualRefresh = false;
  String? _currentImageUrl;
  String? _displayImageUrl;

  // Camera URL - only actual camera footage, no fallback
  final List<String> cameraUrls = [
    "https://esp32-solarimg.s3.ap-south-1.amazonaws.com/current-panel.jpg",
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with first image
    _currentImageUrl = "${cameraUrls[urlIndex]}?${DateTime.now().millisecondsSinceEpoch}";
    _displayImageUrl = _currentImageUrl;

    timer = Timer.periodic(Duration(seconds: 3), (_) {
      if (!manualRefresh) {
        _loadNextImage();
      }
    });
  }

  void _loadNextImage() {
    setState(() {
      _currentImageUrl = "${cameraUrls[urlIndex]}?${DateTime.now().millisecondsSinceEpoch}";
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void _manualRefresh() {
    setState(() {
      manualRefresh = true;
      // Try next URL if current one fails
      urlIndex = (urlIndex + 1) % cameraUrls.length;
    });
    _loadNextImage();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          manualRefresh = false;
        });
      }
    });
  }

  String get currentUrl => _currentImageUrl ?? _displayImageUrl ?? "";

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Display the current cached image - this stays visible
                if (_displayImageUrl != null)
                  Image.network(
                    _displayImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    key: ValueKey(_displayImageUrl),
                  ),
                // Preload the next image invisibly
                if (_currentImageUrl != null && _currentImageUrl != _displayImageUrl)
                  Opacity(
                    opacity: 0.0, // Invisible while loading
                    child: Image.network(
                      _currentImageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame != null) {
                          // Once loaded, update the display URL
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _currentImageUrl != _displayImageUrl) {
                              setState(() {
                                _displayImageUrl = _currentImageUrl;
                              });
                            }
                          });
                        }
                        return child;
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Camera image error: $error');
                        return SizedBox.shrink();
                      },
                    ),
                  ),
                // Show error only if we have no cached image at all
                if (_displayImageUrl == null)
                  Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey[500]),
                          SizedBox(height: 8),
                          Text('Camera offline', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text('Tap refresh to retry', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Quadrant overlay with dividing lines and labels
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: QuadrantPainter(),
                child: Stack(
                  children: [
                    // Left Upper (LU) - swapped with RD
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildQuadrantLabel('LU', widget.inspectionData?['rd']),
                    ),
                    // Right Upper (RU) - swapped with LD
                    Positioned(
                      top: 8,
                      right: 48,
                      child: _buildQuadrantLabel('RU', widget.inspectionData?['ld']),
                    ),
                    // Left Down (LD) - swapped with RU
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: _buildQuadrantLabel('LD', widget.inspectionData?['ru']),
                    ),
                    // Right Down (RD) - swapped with LU
                    Positioned(
                      bottom: 8,
                      right: 48,
                      child: _buildQuadrantLabel('RD', widget.inspectionData?['lu']),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Manual refresh button
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: _manualRefresh,
                tooltip: 'Refresh camera',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantLabel(String position, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (value != null) ...[
            SizedBox(height: 2),
            Text(
              value.toString(),
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Custom painter to draw quadrant dividing lines
class QuadrantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical line (center)
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Draw horizontal line (center)
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Top-level model for a solar panel
class SolarPanel {
  final String name;
  final double efficiency; // 0.0 - 1.0
  final double waterConsumptionLPerDay; // liters per panel per day (cleaning)
  final double areaM2; // area in square meters

  const SolarPanel({
    required this.name,
    required this.efficiency,
    required this.waterConsumptionLPerDay,
    required this.areaM2,
  });

  // Estimate daily energy in kWh for given irradiance (kWh/m²/day)
  double estimatedDailyKWh(double irradianceKWhPerM2) {
    return areaM2 * efficiency * irradianceKWhPerM2;
  }
}

// UI card for a single panel feature summary
class PanelFeatureCard extends StatelessWidget {
  final SolarPanel panel;
  final double dailyPerPanelKWh;
  final double totalDailyKWh;
  final int panelCount;

  const PanelFeatureCard({
    super.key,
    required this.panel,
    required this.dailyPerPanelKWh,
    required this.totalDailyKWh,
    required this.panelCount,
  });

  @override
  Widget build(BuildContext context) {
    final efficiencyPct = (panel.efficiency * 100).toStringAsFixed(1);
    final water = panel.waterConsumptionLPerDay.toStringAsFixed(2);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(panel.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Efficiency: $efficiencyPct%'),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: panel.efficiency, minHeight: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Water: ${water} L/day'),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: (panel.waterConsumptionLPerDay / 2.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        // use valueColor for wide compatibility
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        // avoid deprecated withOpacity; use withAlpha for similar transparency
                        backgroundColor: Colors.blueAccent.withAlpha(51),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Per panel: ${dailyPerPanelKWh.toStringAsFixed(2)} kWh/day'),
            Text('Total (${panelCount}): ${totalDailyKWh.toStringAsFixed(2)} kWh/day',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Panel Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading screen while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If user is logged in, show home page
          if (snapshot.hasData) {
            return const MyHomePage(title: 'Solar Panel Features');
          }

          // Otherwise show login screen
          return const LoginScreen();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double irradiance = 5.0; // kWh/m²/day (typical average)
  int panelCount = 1;

  // New: ambient temperature (°C) used in Status tab and to show temp-adjusted generation
  double temperature = 25.0;

  // New: index for bottom navigation (0: Status, 1: Energy, 2: Menu)
  int _selectedIndex = 1;


  // API data for inspection results
  Timer? _apiTimer;
  Map<String, dynamic>? inspectionData;
  String apiStatus = "Loading...";

  // Telemetry API data
  Timer? _telemetryTimer;
  Map<String, dynamic>? telemetryData;
  String telemetryStatus = "Loading...";
  double? voltageValue;
  double? currentValue;
  double? temperatureValue;
  double? powerValue;

  // Weather API data for solar irradiance
  Timer? _weatherTimer;
  Map<String, dynamic>? weatherData;
  String weatherStatus = "Loading...";
  double? solarIrradiance; // W/m² (short_rad)
  String? locationName;
  String? weatherCondition;

  // Panel physical dimensions
  static const double panelWidthCm = 30.0;
  static const double panelHeightCm = 22.0;
  static const double panelAreaM2 = (panelWidthCm * panelHeightCm) / 10000; // Convert cm² to m²

  // Control API for system on/off with MongoDB
  final MongoService _mongoService = MongoService();
  bool isSystemOn = false;
  bool isTogglingSystem = false;
  bool isPollingESP = false;
  bool isMongoConnected = false;
  String controlStatus = "Unknown";
  int _pollingToken = 0;

  // Mist control state
  bool isMistOn = false;
  bool isTogglingMist = false;
  String mistStatus = "Unknown";

  // Mist control advanced settings
  TimeOfDay mistTimerOn = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay mistTimerOff = TimeOfDay(hour: 18, minute: 0);
  bool mistTimerEnabled = true;
  double mistTempThreshold = 32.0;
  bool isUpdatingMistSettings = false;

  // Calculate theoretical max power based on irradiance and area
  double? get theoreticalMaxPower {
    if (solarIrradiance == null) return null;
    return solarIrradiance! * panelAreaM2; // Watts
  }

  // Calculate actual efficiency percentage
  double? get actualEfficiency {
    if (powerValue == null || theoreticalMaxPower == null || theoreticalMaxPower == 0) return null;
    return (powerValue! / theoreticalMaxPower!) * 100; // Percentage
  }

  // New: handle bottom nav taps
  void _onItemTapped(int index) => setState(() { _selectedIndex = index; });

  @override
  void initState() {
    super.initState();

    // Initialize MongoDB and fetch system state
    _initializeMongoSystem();

    // Start fetching API data
    fetchInspectionData();
    _apiTimer = Timer.periodic(const Duration(seconds: 3), (_) => fetchInspectionData());

    // Start fetching telemetry data
    fetchTelemetryData();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) => fetchTelemetryData());

    // Start fetching weather data (solar irradiance)
    fetchWeatherData();
    _weatherTimer = Timer.periodic(const Duration(minutes: 5), (_) => fetchWeatherData());
  }

  @override
  void dispose() {
    _apiTimer?.cancel();
    _telemetryTimer?.cancel();
    _weatherTimer?.cancel();
    _mongoService.close();
    super.dispose();
  }

  Future<void> fetchInspectionData() async {
    try {
      final response = await http.get(
        Uri.parse("https://esp32-solarimg.s3.ap-south-1.amazonaws.com/inspection-result.json"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          inspectionData = data;
          apiStatus = "Connected";
        });
      } else {
        setState(() {
          apiStatus = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        apiStatus = "Offline: $e";
      });
    }
  }

  Future<void> fetchTelemetryData() async {
    try {
      final response = await http.get(
        Uri.parse("https://ri97neft0k.execute-api.ap-south-1.amazonaws.com/telemetry"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final telemetryInfo = data['data'];
          setState(() {
            telemetryData = telemetryInfo;
            voltageValue = (telemetryInfo['voltage'] as num?)?.toDouble();
            currentValue = (telemetryInfo['current_mA'] as num?)?.toDouble();
            temperatureValue = (telemetryInfo['temperature'] as num?)?.toDouble();
            powerValue = (telemetryInfo['power_W'] as num?)?.toDouble();
            telemetryStatus = "Connected";
          });
        }
      } else {
        setState(() {
          telemetryStatus = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        telemetryStatus = "Offline: $e";
      });
    }
  }

  Future<void> fetchWeatherData() async {
    try {
      final response = await http.get(
        Uri.parse("https://api.weatherapi.com/v1/forecast.json?key=b2d83ed259c043e5b88185208261702&q=Kochi&days=1&aqi=no&alerts=no"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          weatherData = data;
          locationName = data['location']?['name'];
          solarIrradiance = (data['current']?['short_rad'] as num?)?.toDouble();
          weatherCondition = data['current']?['condition']?['text'];
          weatherStatus = "Connected";
        });
      } else {
        setState(() {
          weatherStatus = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        weatherStatus = "Offline: $e";
      });
    }
  }

  // Initialize MongoDB connection and load current state
  Future<void> _initializeMongoSystem() async {
    debugPrint('🔄 Initializing MongoDB system...');

    // Connect to MongoDB
    final connected = await _mongoService.connect();
    if (!mounted) return;

    setState(() {
      isMongoConnected = connected;
      controlStatus = connected ? "Connected" : "Disconnected";
    });

    if (connected) {
      // Load current state from database
      final state = await _mongoService.getSystemState();
      if (!mounted) return;

      setState(() {
        isSystemOn = state == 'ON';
        controlStatus = "Connected";
      });

      debugPrint('✅ MongoDB system initialized - Status: $state');
    } else {
      if (!mounted) return;
      setState(() {
        controlStatus = "MongoDB Offline";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to connect to MongoDB Atlas'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle system ON/OFF using MongoDB
  Future<void> toggleSystem(bool turnOn) async {
    if (isTogglingSystem || !isMongoConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot toggle - not connected to database'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final previousState = isSystemOn;
    final nextState = turnOn;
    final nextStateStr = turnOn ? 'ON' : 'OFF';
    final pollId = DateTime.now().millisecondsSinceEpoch;

    // Cancel any existing polling
    _pollingToken = pollId;

    // 1. Immediately update UI (optimistic update)
    setState(() {
      isSystemOn = nextState;
      isTogglingSystem = true;
      isPollingESP = true;

      // Automatically navigate to Energy page when system turns ON
      if (!previousState && nextState) {
        _selectedIndex = 1; // Switch to Energy page (index 1)
      }
    });

    debugPrint('🔄 Toggle: ${previousState ? "ON" : "OFF"} → $nextStateStr');

    try {
      // 2. Update MongoDB database
      final success = await _mongoService.updateSystemState(nextStateStr);

      if (!success) {
        throw Exception('Failed to update MongoDB');
      }

      debugPrint('✅ Database updated to: $nextStateStr');

      // 3. Start background polling to ESP32
      _pollCloudAPI(nextStateStr, pollId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('System state updated to $nextStateStr in database'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (err) {
      debugPrint('❌ Toggle error: $err');

      // Rollback on error
      if (!mounted) return;
      setState(() {
        isSystemOn = previousState;
        isTogglingSystem = false;
        isPollingESP = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toggle failed: $err'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Poll ESP32 cloud API for hardware confirmation
  // Runs in background for up to 30 seconds
  Future<void> _pollCloudAPI(String desiredState, int pollId) async {
    const maxAttempts = 30;
    const cloudControlUrl = 'https://0ezk16r0u1.execute-api.ap-south-1.amazonaws.com/control';

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

        // Debug: print full response body
        debugPrint('📡 [Poll $pollId] [${attempt + 1}s] Response body: ${response.body}');

        final decoded = jsonDecode(response.body);

        // Try multiple possible response formats
        String? espState;
        if (decoded is Map<String, dynamic>) {
          // Try different possible keys
          espState = decoded['state']?.toString().toUpperCase() ??
                    decoded['current_state']?.toString().toUpperCase() ??
                    decoded['system_state']?.toString().toUpperCase() ??
                    decoded['status']?.toString().toUpperCase();
        }

        debugPrint('📡 [Poll $pollId] [${attempt + 1}s] ESP State: $espState | Target: $desiredState');

        // Check if ESP confirmed the state
        if (espState != null && espState == desiredState) {
          debugPrint('✅ [Poll $pollId] SUCCESS at ${attempt + 1}s - ESP confirmed $desiredState');

          if (!mounted || _pollingToken != pollId) return;
          setState(() {
            isTogglingSystem = false;
            isPollingESP = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ESP32 confirmed $desiredState state'),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }
      } catch (err) {
        debugPrint('❌ [Poll $pollId] [${attempt + 1}s] Cloud API error: $err');
      }
    }

    // Timeout after 30 seconds
    debugPrint('⚠️ [Poll $pollId] Timeout after 30 seconds');

    if (!mounted || _pollingToken != pollId) return;
    setState(() {
      isTogglingSystem = false;
      isPollingESP = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠ ESP32 did not confirm within 30 seconds'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // Toggle mist system ON/OFF
  Future<void> toggleMist(bool turnOn) async {
    if (isTogglingMist) return;

    setState(() {
      isTogglingMist = true;
    });

    final mistState = turnOn ? 'on' : 'off';
    debugPrint('🌫️ Toggling mist: ${isMistOn ? "ON" : "OFF"} → ${turnOn ? "ON" : "OFF"}');

    try {
      final response = await http.post(
        Uri.parse('https://czqc08r3n3.execute-api.ap-south-1.amazonaws.com/default/MistControl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mist': mistState}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Mist control response: $data');

        if (!mounted) return;
        setState(() {
          isMistOn = turnOn;
          mistStatus = 'Connected';
          isTogglingMist = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Mist system turned ${turnOn ? "ON" : "OFF"}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('❌ Mist toggle error: $err');

      if (!mounted) return;
      setState(() {
        isTogglingMist = false;
        mistStatus = 'Error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle mist: $err'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> updateMistSettings() async {
    if (isUpdatingMistSettings) return;

    setState(() {
      isUpdatingMistSettings = true;
    });

    debugPrint('⚙️ Updating mist settings...');

    try {
      final response = await http.post(
        Uri.parse('https://czqc08r3n3.execute-api.ap-south-1.amazonaws.com/default/MistControl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mist': isMistOn ? 'on' : 'off',
          'timerOn': '${mistTimerOn.hour.toString().padLeft(2, '0')}:${mistTimerOn.minute.toString().padLeft(2, '0')}',
          'timerOff': '${mistTimerOff.hour.toString().padLeft(2, '0')}:${mistTimerOff.minute.toString().padLeft(2, '0')}',
          'timerEnabled': mistTimerEnabled,
          'tempThreshold': mistTempThreshold,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Mist settings updated: $data');

        if (!mounted) return;
        setState(() {
          isUpdatingMistSettings = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Mist settings updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('❌ Mist settings update error: $err');

      if (!mounted) return;
      setState(() {
        isUpdatingMistSettings = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update mist settings: $err'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // New: build different body content per tab
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Status

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // System Control Card
              Card(
                elevation: 4,
                color: isSystemOn ? Colors.green[50] : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSystemOn ? Icons.power_settings_new : Icons.power_off,
                                    color: isSystemOn ? Colors.green[700] : Colors.grey[600],
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'System Status',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isSystemOn ? Colors.green : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            isSystemOn ? 'ONLINE' : 'OFFLINE',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSystemOn ? Colors.green[700] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Toggle Switch
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: isSystemOn,
                              onChanged: isTogglingSystem ? null : (value) {
                                toggleSystem(value);
                              },
                              activeThumbColor: Colors.green[700],
                              inactiveThumbColor: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (isTogglingSystem || isPollingESP) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              isPollingESP ? 'Syncing with ESP32...' : 'Updating database...',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Live camera view
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Live Panel View',
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.orange, // Indicates trying to connect
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text('Connecting...',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CameraView(inspectionData: inspectionData),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Auto-updates every 3s',
                                 style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                 overflow: TextOverflow.ellipsis),
                          ),
                          Text('Tap refresh to reload',
                               style: TextStyle(color: Colors.grey[500], fontSize: 10),
                               overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Inspection Data Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Inspection Results',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: apiStatus == "Connected" ? Colors.green : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(apiStatus, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (inspectionData != null) ...[
                        // Visual solar panel representation
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[900]!, Colors.blue[700]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Panel title
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.solar_power, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Solar Panel Quadrants',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Solar panel grid
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[700]!, width: 2),
                                ),
                                child: Column(
                                  children: [
                                    // Top row (LU, RU)
                                    Row(
                                      children: [
                                        // Left Upper quadrant - swapped with RD
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800]?.withValues(alpha: 0.5),
                                              border: Border.all(color: Colors.cyan[700]!, width: 1.5),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(6),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Left Upper',
                                                  style: TextStyle(
                                                    color: Colors.cyan[300],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${inspectionData!['rd'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Right Upper quadrant - swapped with LD
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800]?.withValues(alpha: 0.5),
                                              border: Border.all(color: Colors.cyan[700]!, width: 1.5),
                                              borderRadius: BorderRadius.only(
                                                topRight: Radius.circular(6),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Right Upper',
                                                  style: TextStyle(
                                                    color: Colors.cyan[300],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${inspectionData!['ld'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Bottom row (LD, RD)
                                    Row(
                                      children: [
                                        // Left Down quadrant - swapped with RU
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800]?.withValues(alpha: 0.5),
                                              border: Border.all(color: Colors.cyan[700]!, width: 1.5),
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(6),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Left Down',
                                                  style: TextStyle(
                                                    color: Colors.cyan[300],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${inspectionData!['ru'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Right Down quadrant - swapped with LU
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800]?.withValues(alpha: 0.5),
                                              border: Border.all(color: Colors.cyan[700]!, width: 1.5),
                                              borderRadius: BorderRadius.only(
                                                bottomRight: Radius.circular(6),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Right Down',
                                                  style: TextStyle(
                                                    color: Colors.cyan[300],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${inspectionData!['lu'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
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
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(height: 8),
                                Text('Fetching inspection data...',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Solar Irradiance Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Solar Irradiance', style: Theme.of(context).textTheme.titleMedium),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: weatherStatus == "Connected" ? Colors.green : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(weatherStatus, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (weatherData != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: Colors.orange[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wb_sunny, size: 40, color: Colors.orange[700]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Solar Radiation',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        solarIrradiance != null ? '${solarIrradiance!.toStringAsFixed(1)} W/m²' : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                  locationName ?? 'Unknown',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            if (weatherCondition != null)
                              Text(
                                weatherCondition!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Updates every 5 minutes',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(height: 8),
                                Text('Fetching weather data...',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 2: // Menu
        final user = FirebaseAuth.instance.currentUser;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // User Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue[700],
                        child: Text(
                          user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.email ?? 'Not logged in',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solar Panel User',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About'),
                        content: const Text(
                          'Solar Panel Monitor v1.0.0\n\n'
                          'Track your solar panel efficiency, '
                          'water consumption, and energy production.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
              // Logout Button
              Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red[700]),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Logout',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await AuthService().signOut();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      case 1: // Energy (default) - original UI moved here
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // System Control Card
              Card(
                elevation: 4,
                color: isSystemOn ? Colors.green[50] : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSystemOn ? Icons.power_settings_new : Icons.power_off,
                                    color: isSystemOn ? Colors.green[700] : Colors.grey[600],
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'System Status',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isSystemOn ? Colors.green : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            isSystemOn ? 'ONLINE' : 'OFFLINE',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSystemOn ? Colors.green[700] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Toggle Switch
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: isSystemOn,
                              onChanged: isTogglingSystem ? null : (value) {
                                toggleSystem(value);
                              },
                              activeThumbColor: Colors.green[700],
                              inactiveThumbColor: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (isTogglingSystem || isPollingESP) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              isPollingESP ? 'Syncing with ESP32...' : 'Updating database...',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Show content only when system is ON
              if (isSystemOn) ...[
                // Telemetry Data Card
                Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Panel Readings', style: Theme.of(context).textTheme.titleMedium),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: telemetryStatus == "Connected" ? Colors.green : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(telemetryStatus, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (telemetryData != null) ...[
                        Row(
                          children: [
                            // Voltage card
                            Expanded(
                              child: Card(
                                color: Colors.amber[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.electric_bolt, size: 16, color: Colors.amber[700]),
                                          SizedBox(width: 4),
                                          Text('Voltage', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        voltageValue != null ? '${voltageValue!.toStringAsFixed(3)} V' : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                color: Colors.blue[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.electrical_services, size: 16, color: Colors.blue[700]),
                                          SizedBox(width: 4),
                                          Text('Current', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentValue != null ? '${currentValue!.toStringAsFixed(2)} mA' : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: Colors.red[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.thermostat, size: 16, color: Colors.red[700]),
                                          SizedBox(width: 4),
                                          Text('Temperature', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        temperatureValue != null ? '${temperatureValue!.toStringAsFixed(1)} °C' : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                color: Colors.green[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.power, size: 16, color: Colors.green[700]),
                                          SizedBox(width: 4),
                                          Text('Power', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        powerValue != null ? '${powerValue!.toStringAsFixed(2)} W' : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: ${telemetryData!['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(telemetryData!['timestamp']).toString().substring(0, 19) : 'N/A'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(height: 8),
                                Text('Fetching telemetry data...',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Panel Efficiency Analysis Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_outlined, size: 20, color: Colors.purple[700]),
                          SizedBox(width: 8),
                          Text('Efficiency Analysis', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Panel specifications
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.solar_power, size: 16, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              'Panel Size: ${panelWidthCm.toInt()}cm × ${panelHeightCm.toInt()}cm',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Area: ${panelAreaM2.toStringAsFixed(4)} m²',
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (solarIrradiance != null && powerValue != null) ...[
                        // Efficiency metrics
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: Colors.blue[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.wb_sunny, size: 14, color: Colors.orange[700]),
                                          SizedBox(width: 4),
                                          Text(
                                            'Solar Irradiance',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${solarIrradiance!.toStringAsFixed(1)} W/m²',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                color: Colors.indigo[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.science, size: 14, color: Colors.indigo[700]),
                                          SizedBox(width: 4),
                                          Text(
                                            'Theoretical Max',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        theoreticalMaxPower != null
                                          ? '${theoreticalMaxPower!.toStringAsFixed(3)} W'
                                          : 'N/A',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: Colors.green[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.power, size: 14, color: Colors.green[700]),
                                          SizedBox(width: 4),
                                          Text(
                                            'Actual Power',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${powerValue!.toStringAsFixed(3)} W',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                color: actualEfficiency != null && actualEfficiency! > 15
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.speed,
                                            size: 14,
                                            color: actualEfficiency != null && actualEfficiency! > 15
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Efficiency',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        actualEfficiency != null
                                          ? '${actualEfficiency!.toStringAsFixed(2)}%'
                                          : 'N/A',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: actualEfficiency != null && actualEfficiency! > 15
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Visual efficiency bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Performance',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  actualEfficiency != null && actualEfficiency! > 15
                                    ? 'Good'
                                    : actualEfficiency != null && actualEfficiency! > 10
                                      ? 'Fair'
                                      : 'Low',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: actualEfficiency != null && actualEfficiency! > 15
                                      ? Colors.green[700]
                                      : actualEfficiency != null && actualEfficiency! > 10
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: actualEfficiency != null
                                  ? (actualEfficiency! / 100).clamp(0.0, 1.0)
                                  : 0.0,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  actualEfficiency != null && actualEfficiency! > 15
                                    ? Colors.green
                                    : actualEfficiency != null && actualEfficiency! > 10
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Efficiency = (Actual Power / Theoretical Max Power) × 100',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 32, color: Colors.orange[300]),
                              const SizedBox(height: 8),
                              Text(
                                'Waiting for data...',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Need both solar irradiance and power readings',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Mist Control Card
              Card(
                elevation: 4,
                color: isMistOn ? Colors.blue[50] : Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.water_drop,
                                    color: isMistOn ? Colors.blue[700] : Colors.grey[600],
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mist Control',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isMistOn ? Colors.blue : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            isMistOn ? 'ACTIVE' : 'INACTIVE',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isMistOn ? Colors.blue[700] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Toggle Switch
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: isMistOn,
                              onChanged: isTogglingMist ? null : (value) {
                                toggleMist(value);
                              },
                              activeThumbColor: Colors.blue[700],
                              inactiveThumbColor: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (isTogglingMist) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Updating mist system...',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Controls the misting system for panel cooling and cleaning',
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Advanced Settings
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        'Schedule & Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12),
                      // Timer Enable Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 18, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Enable Timer',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Switch(
                            value: mistTimerEnabled,
                            onChanged: (value) {
                              setState(() {
                                mistTimerEnabled = value;
                              });
                            },
                            activeThumbColor: Colors.blue[700],
                          ),
                        ],
                      ),
                      // Timer On
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: mistTimerOn,
                                );
                                if (picked != null) {
                                  setState(() {
                                    mistTimerOn = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.wb_sunny, size: 14, color: Colors.orange[700]),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Start',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${mistTimerOn.hour.toString().padLeft(2, '0')}:${mistTimerOn.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: mistTimerOff,
                                );
                                if (picked != null) {
                                  setState(() {
                                    mistTimerOff = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.nightlight, size: 14, color: Colors.indigo[700]),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'End',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${mistTimerOff.hour.toString().padLeft(2, '0')}:${mistTimerOff.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Temperature Threshold
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.thermostat, size: 18, color: Colors.red[700]),
                                    SizedBox(width: 8),
                                    Text(
                                      'Temperature Threshold',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${mistTempThreshold.toStringAsFixed(1)}°C',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Slider(
                              value: mistTempThreshold,
                              min: 20.0,
                              max: 50.0,
                              divisions: 30,
                              activeColor: Colors.red[600],
                              inactiveColor: Colors.red[200],
                              onChanged: (value) {
                                setState(() {
                                  mistTempThreshold = value;
                                });
                              },
                            ),
                            Text(
                              'Mist activates automatically when panel exceeds this temperature',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Apply Settings Button
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isUpdatingMistSettings ? null : updateMistSettings,
                          icon: isUpdatingMistSettings
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.save),
                          label: Text(isUpdatingMistSettings ? 'Applying...' : 'Apply Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ] else ...[
                // Show message when system is OFF
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'System is Offline',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Turn on the system to view energy data',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: const Color(0xFF0277BD),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0277BD), Color(0xFF01579B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            // Solar Panel Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.solar_power,
                color: Color(0xFFFFC107),
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Solar Monitor',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getPageSubtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // MongoDB Connection Status Badge
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMongoConnected
                ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                : const Color(0xFFF44336).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMongoConnected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF44336),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isMongoConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                    shape: BoxShape.circle,
                    boxShadow: isMongoConnected ? [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isMongoConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMongoConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            onPressed: () async {
              await AuthService().signOut();
            },
            tooltip: 'Sign Out',
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0277BD),
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt_outlined),
            activeIcon: Icon(Icons.bolt),
            label: 'Energy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _getPageSubtitle() {
    switch (_selectedIndex) {
      case 0:
        return 'System Overview & Live Monitoring';
      case 1:
        return 'Performance & Energy Analytics';
      case 2:
        return 'Configuration & Management';
      default:
        return 'Solar Panel Management System';
    }
  }
}
