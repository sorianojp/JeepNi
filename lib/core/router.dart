import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/admin/admin_dashboard.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final isAuthenticated = authService.currentUser != null;
    
    if (!isAuthenticated && state.matchedLocation != '/login') {
      return '/login';
    }
    
    if (isAuthenticated && state.matchedLocation == '/login') {
      final role = authService.currentUser!.role;
      switch (role) {
        case UserRole.student:
          return '/student';
        case UserRole.driver:
          return '/driver';
        case UserRole.admin:
          return '/admin';
      }
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/driver',
      builder: (context, state) => const DriverDashboard(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
  ],
);
