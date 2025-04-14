import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// This class helps us mock Firebase Auth for testing
class MockFirebaseAuthProvider {
  static firebase_auth.FirebaseAuth? _mockInstance;
  static final firebase_auth.FirebaseAuth _originalInstance =
      firebase_auth.FirebaseAuth.instance;

  // Setup mock for testing
  static void setupMock(firebase_auth.FirebaseAuth mockAuth) {
    _mockInstance = mockAuth;
  }

  // Cleanup after tests
  static void resetToOriginal() {
    _mockInstance = null;
  }

  // This will be used to replace FirebaseAuth.instance
  static firebase_auth.FirebaseAuth get instance {
    return _mockInstance ?? _originalInstance;
  }
}

// This extension will allow us to override the FirebaseAuth.instance property
extension FirebaseAuthTestExtension on firebase_auth.FirebaseAuth {
  static void useEmulator() {
    // Could be used to point to a Firebase emulator for testing
  }
}
