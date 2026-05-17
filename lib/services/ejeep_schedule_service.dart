import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/ejeep_schedule.dart';

class EJeepScheduleService extends ChangeNotifier {
  final List<EJeepSchedule> _schedules = <EJeepSchedule>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<fb.User?>? _authSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  List<EJeepSchedule> get schedules => List.unmodifiable(_schedules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  EJeepScheduleService() {
    _authSubscription = fb.FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user == null) {
        _stopListening();
        return;
      }

      _startListening();
    });
  }

  void _startListening() {
    if (_subscription != null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('schedules')
        .snapshots()
        .listen(
          _handleSnapshot,
          onError: (Object error) {
            debugPrint('Schedule listener failed: $error');
            _isLoading = false;
            _errorMessage = 'Could not load eJeep schedules.';
            notifyListeners();
          },
        );
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _schedules.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _schedules
      ..clear()
      ..addAll(
        snapshot.docs.map(
          (doc) => EJeepSchedule.fromFirestore(doc.id, doc.data()),
        ),
      )
      ..sort(_compareSchedules);
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  int _compareSchedules(EJeepSchedule a, EJeepSchedule b) {
    final dayCompare = a.dayRange.toLowerCase().compareTo(
      b.dayRange.toLowerCase(),
    );
    if (dayCompare != 0) return dayCompare;
    return a.startTime.toLowerCase().compareTo(b.startTime.toLowerCase());
  }

  Future<void> addSchedule({
    required String ejeepName,
    required String route,
    required String dayRange,
    required String startTime,
    required String endTime,
    String notes = '',
  }) async {
    final schedule = EJeepSchedule(
      id: '',
      ejeepName: ejeepName,
      route: route,
      dayRange: dayRange,
      startTime: startTime,
      endTime: endTime,
      isActive: true,
      notes: notes,
    );

    final data = schedule.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance.collection('schedules').add(data);
  }

  Future<void> setScheduleActive(String scheduleId, bool isActive) async {
    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(scheduleId)
        .update({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
