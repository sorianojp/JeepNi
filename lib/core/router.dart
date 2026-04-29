import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/about/about_app_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_create_driver_screen.dart';
import '../screens/admin/admin_map_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_model.dart';

GoRouter createRouter(FirebaseAuthService authService) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authService,
    redirect: (context, state) {
      if (!authService.isInitialized) {
        return null;
      }

      final isAuthenticated = authService.currentUser != null;

      if (!isAuthenticated && state.matchedLocation == '/') {
        return '/login';
      }

      if (!isAuthenticated && state.matchedLocation != '/login') {
        return '/login';
      }

      if (isAuthenticated &&
          (state.matchedLocation == '/' || state.matchedLocation == '/login')) {
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
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutAppScreen(),
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
      GoRoute(
        path: '/admin/map',
        builder: (context, state) => const AdminMapScreen(),
      ),
      GoRoute(
        path: '/admin/drivers',
        builder: (context, state) => const AdminCreateDriverScreen(),
      ),
    ],
  );
}
