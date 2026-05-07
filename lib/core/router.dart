import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import '../screens/auth/login_screen.dart';
import '../screens/account/account_settings_screen.dart';
import '../screens/account/delete_account_screen.dart';
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
    initialLocation: AppRoutes.splash,
    refreshListenable: authService,
    redirect: (context, state) {
      if (!authService.isInitialized) {
        return null;
      }

      final isAuthenticated = authService.currentUser != null;

      if (!isAuthenticated && state.matchedLocation == AppRoutes.splash) {
        return AppRoutes.login;
      }

      if (!isAuthenticated && state.matchedLocation != AppRoutes.login) {
        return AppRoutes.login;
      }

      if (isAuthenticated &&
          (state.matchedLocation == AppRoutes.splash ||
              state.matchedLocation == AppRoutes.login)) {
        final role = authService.currentUser!.role;
        switch (role) {
          case UserRole.student:
            return AppRoutes.student;
          case UserRole.driver:
            return AppRoutes.driver;
          case UserRole.admin:
            return AppRoutes.admin;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutAppScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountDelete,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.student,
        builder: (context, state) => const StudentDashboard(),
      ),
      GoRoute(
        path: AppRoutes.driver,
        builder: (context, state) => const DriverDashboard(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: AppRoutes.adminMap,
        builder: (context, state) => const AdminMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDrivers,
        builder: (context, state) => const AdminCreateDriverScreen(),
      ),
    ],
  );
}
