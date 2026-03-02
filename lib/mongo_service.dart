import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// MongoDB Service for ESP32 System State Management
///
/// This service handles direct connection to MongoDB Atlas and manages
/// the system state (ON/OFF) in the database.
///
/// Usage:
/// ```dart
/// final mongoService = MongoService();
/// await mongoService.connect();
/// final state = await mongoService.getSystemState();
/// await mongoService.updateSystemState('ON');
/// ```
class MongoService {
  /// MongoDB Atlas connection string
  ///
  /// Replace this with your own MongoDB connection string, or keep it
  /// to share the same database with other users.
  static const String _mongoUrl =
      'mongodb+srv://solarpanelsjcet_db_user:07VfGjqRiZRJ6dP8@cluster0.a3sl4rk.mongodb.net/test?retryWrites=true&w=majority';

  Db? _db;
  DbCollection? _collection;
  bool _isConnected = false;

  /// Connect to MongoDB Atlas
  ///
  /// Returns `true` if connection succeeds, `false` otherwise.
  /// Safe to call multiple times - will reuse existing connection.
  Future<bool> connect() async {
    if (_isConnected && _db != null) {
      debugPrint('✅ Already connected to MongoDB');
      return true;
    }

    try {
      debugPrint('🔄 Connecting to MongoDB Atlas...');
      _db = await Db.create(_mongoUrl);
      await _db!.open();
      _collection = _db!.collection('systemstates');
      _isConnected = true;
      debugPrint('✅ Connected to MongoDB Atlas successfully');
      return true;
    } catch (e) {
      debugPrint('❌ MongoDB connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Get current system state from MongoDB
  ///
  /// Returns 'ON', 'OFF', or null if error occurs.
  /// Automatically connects if not already connected.
  Future<String?> getSystemState() async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return null;
    }

    try {
      final result = await _collection!.findOne(where.eq('key', 'system'));

      if (result == null) {
        debugPrint('⚠️ No system state found in database, defaulting to OFF');
        return 'OFF';
      }

      final state = result['state'];
      final updatedAt = result['updatedAt'];
      debugPrint('📖 Read state from MongoDB: $state (updated: $updatedAt)');
      return state?.toString().toUpperCase();
    } catch (e) {
      debugPrint('❌ Error reading state from MongoDB: $e');
      return null;
    }
  }

  /// Update system state in MongoDB
  ///
  /// [state] should be 'ON' or 'OFF' (case-insensitive).
  /// Returns `true` if update succeeds, `false` otherwise.
  /// Automatically creates the document if it doesn't exist (upsert).
  Future<bool> updateSystemState(String state) async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return false;
    }

    try {
      final normalizedState = state.toUpperCase();

      if (normalizedState != 'ON' && normalizedState != 'OFF') {
        debugPrint('❌ Invalid state: $state (must be ON or OFF)');
        return false;
      }

      debugPrint('💾 Updating state to: $normalizedState');

      await _collection!.updateOne(
        where.eq('key', 'system'),
        modify
            .set('state', normalizedState)
            .set('updatedAt', DateTime.now()),
        upsert: true,
      );

      debugPrint('✅ State updated to $normalizedState in MongoDB');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating state in MongoDB: $e');
      return false;
    }
  }

  /// Close the MongoDB connection
  ///
  /// Call this when you're done using the service, typically in dispose().
  Future<void> close() async {
    if (_isConnected && _db != null) {
      await _db!.close();
      _isConnected = false;
      debugPrint('🔌 MongoDB connection closed');
    }
  }

  /// Check if currently connected to MongoDB
  bool get isConnected => _isConnected;

  /// Get the MongoDB database instance (for advanced usage)
  Db? get database => _db;

  /// Get the systemstates collection (for advanced usage)
  DbCollection? get collection => _collection;
}
