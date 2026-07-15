import "dart:io" show Platform;

import "package:flutter/foundation.dart" show kIsWeb;

/// True when running on a real iOS device/simulator (RoomPlan is iOS-only).
bool get isIOSDevice => !kIsWeb && Platform.isIOS;
