import "package:flutter/foundation.dart";

/// Bumped after a successful upload so the Scans list can reload.
class ScansRefreshNotifier extends ChangeNotifier {
  ScansRefreshNotifier._();
  static final ScansRefreshNotifier instance = ScansRefreshNotifier._();

  int _generation = 0;
  int get generation => _generation;

  void notifyScansChanged() {
    _generation++;
    notifyListeners();
  }
}
