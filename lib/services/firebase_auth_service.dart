import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class FirebaseAuthService extends ChangeNotifier {
  UserModel? _currentUser;
  String? _lastError;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  String? get lastError => _lastError;
  bool get isInitialized => _isInitialized;

  FirebaseAuthService() {
    _restoreCurrentUser();
  }

  Future<void> _restoreCurrentUser() async {
    final authUser = fb.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      _isInitialized = true;
      notifyListeners();
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

    _isInitialized = true;
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

  Future<void> _writeProfile(UserModel profile) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(profile.id)
        .set(profile.toFirestore());
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
    fb.User? createdAuthUser;

    try {
      final credential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      createdAuthUser = credential.user!;
      await createdAuthUser.updateDisplayName(name);

      final profile = UserModel(
        id: createdAuthUser.uid,
        email: email,
        name: name,
        role: UserRole.student,
      );

      await _writeProfile(profile);

      _currentUser = profile;
      notifyListeners();
      return true;
    } on fb.FirebaseAuthException catch (error) {
      await _deleteIncompleteAuthUser(createdAuthUser);
      _lastError = error.message ?? error.code;
      return false;
    } catch (error) {
      await _deleteIncompleteAuthUser(createdAuthUser);
      _lastError = error.toString();
      return false;
    }
  }

  Future<void> _deleteIncompleteAuthUser(fb.User? user) async {
    if (user == null) return;

    try {
      await user.delete();
    } catch (error) {
      debugPrint('Could not delete incomplete auth user: $error');
      await fb.FirebaseAuth.instance.signOut();
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
      );

      await _writeProfile(profile);
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

  void logout() {
    _currentUser = null;
    notifyListeners();
    fb.FirebaseAuth.instance.signOut();
  }
}
