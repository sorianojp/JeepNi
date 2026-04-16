import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_defaults.dart';
import '../models/user_model.dart';

class FirebaseAuthService extends ChangeNotifier {
  UserModel? _currentUser;
  String? _lastError;

  UserModel? get currentUser => _currentUser;
  String? get lastError => _lastError;

  FirebaseAuthService() {
    _restoreCurrentUser();
  }

  Future<String?> _firstDriverId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: UserRole.driver.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first.id;
  }

  Future<void> _restoreCurrentUser() async {
    final authUser = fb.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      await _loadProfile(authUser);
    } on FirebaseException catch (error) {
      _lastError = error.message ?? error.code;
      _currentUser = null;
      await fb.FirebaseAuth.instance.signOut();
    } catch (error) {
      _lastError = error.toString();
      _currentUser = null;
      await fb.FirebaseAuth.instance.signOut();
    }

    notifyListeners();
  }

  Future<void> _loadProfile(fb.User authUser) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .get();
    final data = doc.data();

    if (data != null) {
      _currentUser = UserModel.fromFirestore(doc.id, data);
      return;
    }

    _currentUser = UserModel(
      id: authUser.uid,
      email: authUser.email ?? '',
      name: authUser.displayName ?? authUser.email ?? 'User',
      role: UserRole.student,
    );
  }

  LatLng _defaultLocationForRole(UserRole role) {
    return AppDefaults.roleLocations[role] ??
        AppDefaults.roleLocations[UserRole.admin]!;
  }

  Future<void> _writeProfile(
    UserModel profile, {
    bool writeLocationDoc = true,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(profile.id)
        .set(profile.toFirestore());

    final location = profile.location;
    if (writeLocationDoc && location != null) {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(profile.id)
          .set({
            'latitude': location.latitude,
            'longitude': location.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
  }

  Future<FirebaseApp> _createTemporaryAuthApp() {
    final defaultApp = Firebase.app();
    final name =
        'driver-account-creation-${DateTime.now().microsecondsSinceEpoch}';

    return Firebase.initializeApp(name: name, options: defaultApp.options);
  }

  Future<bool> login(String email, String password) async {
    _lastError = null;
    try {
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _loadProfile(credential.user!);
      notifyListeners();
      return true;
    } on fb.FirebaseAuthException catch (error) {
      _lastError = error.message ?? error.code;
      await fb.FirebaseAuth.instance.signOut();
      return false;
    } catch (error) {
      _lastError = error.toString();
      await fb.FirebaseAuth.instance.signOut();
      return false;
    }
  }

  Future<bool> registerStudent({
    required String email,
    required String password,
    required String name,
  }) async {
    _lastError = null;
    try {
      final credential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final authUser = credential.user!;
      await authUser.updateDisplayName(name);

      final profile = UserModel(
        id: authUser.uid,
        email: email,
        name: name,
        role: UserRole.student,
        location: _defaultLocationForRole(UserRole.student),
      );

      await _writeProfile(profile);
      final linkedProfile = await _linkProfile(profile);

      _currentUser = linkedProfile;
      notifyListeners();
      return true;
    } on fb.FirebaseAuthException catch (error) {
      _lastError = error.message ?? error.code;
      return false;
    } catch (error) {
      _lastError = error.toString();
      return false;
    }
  }

  Future<bool> createDriverAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    _lastError = null;

    if (_currentUser?.role != UserRole.admin) {
      _lastError = 'Only admins can create driver accounts.';
      return false;
    }

    FirebaseApp? temporaryApp;
    fb.User? createdAuthUser;

    try {
      temporaryApp = await _createTemporaryAuthApp();
      final temporaryAuth = fb.FirebaseAuth.instanceFor(app: temporaryApp);
      final credential = await temporaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      createdAuthUser = credential.user!;
      await createdAuthUser.updateDisplayName(name);

      final profile = UserModel(
        id: createdAuthUser.uid,
        email: email,
        name: name,
        role: UserRole.driver,
        location: _defaultLocationForRole(UserRole.driver),
        routeId: AppDefaults.defaultRouteId,
      );

      await _writeProfile(profile, writeLocationDoc: false);
      await _linkProfile(profile);
      await temporaryAuth.signOut();
      return true;
    } on fb.FirebaseAuthException catch (error) {
      _lastError = error.message ?? error.code;
      return false;
    } catch (error) {
      if (createdAuthUser != null) {
        try {
          await createdAuthUser.delete();
        } catch (deleteError) {
          debugPrint(
            'Could not delete incomplete driver auth user: $deleteError',
          );
        }
      }

      _lastError = error.toString();
      return false;
    } finally {
      if (temporaryApp != null) {
        try {
          await fb.FirebaseAuth.instanceFor(app: temporaryApp).signOut();
          await temporaryApp.delete();
        } catch (error) {
          debugPrint('Could not clean up temporary Firebase app: $error');
        }
      }
    }
  }

  Future<UserModel> _linkProfile(UserModel profile) async {
    if (profile.role == UserRole.student) {
      try {
        final assignedDriverId = await _firstDriverId();
        if (assignedDriverId == null) {
          return profile;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(profile.id)
            .set({
              'assignedDriverId': assignedDriverId,
            }, SetOptions(merge: true));

        return profile.copyWith(assignedDriverId: assignedDriverId);
      } catch (error) {
        debugPrint('Student driver linking skipped: $error');
        return profile;
      }
    }

    if (profile.role == UserRole.driver && profile.routeId != null) {
      try {
        final routeRef = FirebaseFirestore.instance
            .collection('routes')
            .doc(profile.routeId);
        final routeDoc = await routeRef.get();

        if (!routeDoc.exists) {
          await routeRef.set({
            'name': AppDefaults.defaultRouteName,
            'description': AppDefaults.defaultRouteDescription,
            'driverId': profile.id,
          });
        } else {
          await routeRef.set({'driverId': profile.id}, SetOptions(merge: true));
        }
      } catch (error) {
        debugPrint('Driver route linking skipped: $error');
      }
    }

    return profile;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
    fb.FirebaseAuth.instance.signOut();
  }
}
