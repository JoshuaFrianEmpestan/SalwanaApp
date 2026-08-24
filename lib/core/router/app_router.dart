import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/enums.dart';
import '../../core/providers/app_prefs_providers.dart';
import '../../core/providers/firebase_providers.dart';
import '../../core/widgets/coming_soon_screen.dart';
import '../../core/widgets/role_scaffold.dart';
import '../../features/admin/presentation/admin_settings_screen.dart';
import '../../features/auth/presentation/account_blocked_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/pending_verification_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/consumer/presentation/consumer_profile_screen.dart';
import '../../features/merchant/presentation/inventory_list_screen.dart';
import '../../features/merchant/presentation/merchant_profile_screen.dart';
import '../../features/merchant/presentation/product_detail_screen.dart';
import '../../features/merchant/presentation/product_form_screen.dart';
import '../../features/merchant/presentation/stock_adjustment_screen.dart';
import '../../features/merchant/presentation/stock_movement_history_screen.dart';
import '../../features/merchant/presentation/store_profile_screen.dart';
import '../../features/supplier/presentation/supplier_profile_screen.dart';
import 'router_refresh_notifier.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

const _preAuthLocations = {
  '/splash',
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
  '/verify-email',
  '/pending-verification',
  '/account-blocked',
};

String _roleHome(UserRole role) => switch (role) {
      UserRole.consumer => '/consumer/home',
      UserRole.merchant => '/merchant/dashboard',
      UserRole.supplier => '/supplier/dashboard',
      UserRole.admin => '/admin/dashboard',
    };

final routerProvider = Provider<GoRouter>((ref) {
  // A plain ChangeNotifier pinged via ref.listen — this deliberately avoids
  // `ref.watch(provider)` (which would rebuild/recreate the whole GoRouter,
  // resetting navigation) and the deprecated `.stream` modifier. Only
  // `redirect` re-runs on each ping; the router instance itself is stable.
  final refreshNotifier = RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);
  ref.listen(authStateProvider, (_, __) => refreshNotifier.ping());
  ref.listen(appUserProvider, (_, __) => refreshNotifier.ping());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final authAsync = ref.read(authStateProvider);

      if (authAsync.isLoading && !authAsync.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }

      final fbUser = authAsync.valueOrNull;

      if (fbUser == null) {
        if (!ref.read(onboardingSeenProvider) && loc != '/onboarding') return '/onboarding';
        if (_preAuthLocations.contains(loc)) return null;
        return '/login';
      }

      if (!fbUser.emailVerified) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      final appUserAsync = ref.read(appUserProvider);
      if (appUserAsync.isLoading && !appUserAsync.hasValue) return null;

      final appUser = appUserAsync.valueOrNull;
      if (appUser == null) return null;

      if (appUser.status == AccountStatus.suspended || appUser.status == AccountStatus.deactivated) {
        return loc == '/account-blocked' ? null : '/account-blocked';
      }

      if ((appUser.role == UserRole.merchant || appUser.role == UserRole.supplier) &&
          (appUser.status == AccountStatus.pendingVerification || appUser.status == AccountStatus.rejected)) {
        return loc == '/pending-verification' ? null : '/pending-verification';
      }

      final home = _roleHome(appUser.role);

      if (_preAuthLocations.contains(loc)) return home;

      // Role route protection — a user may never view another role's tree.
      for (final role in UserRole.values) {
        final prefix = '/${role.name}';
        if (loc.startsWith(prefix) && appUser.role != role) return home;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: '/pending-verification', builder: (context, state) => const PendingVerificationScreen()),
      GoRoute(path: '/account-blocked', builder: (context, state) => const AccountBlockedScreen()),

      // ---------------- Consumer ----------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleScaffold(
          navigationShell: shell,
          destinations: const [
            NavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
            NavDestination(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Stores'),
            NavDestination(icon: Icons.shopping_cart_outlined, selectedIcon: Icons.shopping_cart_rounded, label: 'Cart'),
            NavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Orders'),
            NavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/consumer/home',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Home',
                moduleNote: 'Consumer catalog & search (module 5) builds this next.',
                icon: Icons.home_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/consumer/stores',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Stores',
                moduleNote: 'Browse merchant stores (module 5).',
                icon: Icons.storefront_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/consumer/cart',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Cart',
                moduleNote: 'Cart, reservation & checkout (module 6).',
                icon: Icons.shopping_cart_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/consumer/orders',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Orders',
                moduleNote: 'Order management (module 8).',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/consumer/profile', builder: (context, state) => const ConsumerProfileScreen()),
          ]),
        ],
      ),

      // ---------------- Merchant ----------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleScaffold(
          navigationShell: shell,
          destinations: const [
            NavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
            NavDestination(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Inventory'),
            NavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Orders'),
            NavDestination(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Finance'),
            NavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/merchant/dashboard',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Dashboard',
                moduleNote: 'Merchant store & product management (module 3) builds this next.',
                icon: Icons.dashboard_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/merchant/inventory', builder: (context, state) => const InventoryListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/merchant/orders',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Orders',
                moduleNote: 'Order management (module 8).',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/merchant/finance',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Finance',
                moduleNote: 'Merchant finance & loan tracking (module 10).',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/merchant/profile', builder: (context, state) => const MerchantProfileScreen()),
          ]),
        ],
      ),

      // ---------------- Supplier ----------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleScaffold(
          navigationShell: shell,
          destinations: const [
            NavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
            NavDestination(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment_rounded, label: 'Requests'),
            NavDestination(icon: Icons.inventory_outlined, selectedIcon: Icons.inventory_rounded, label: 'Products'),
            NavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Transactions'),
            NavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/supplier/dashboard',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Dashboard',
                moduleNote: 'Supplier & restocking workflow (module 9) builds this next.',
                icon: Icons.dashboard_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/supplier/requests',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Requests',
                moduleNote: 'Restocking requests from merchants (module 9).',
                icon: Icons.assignment_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/supplier/products',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Products',
                moduleNote: 'Manage supplies you offer to merchants (module 9).',
                icon: Icons.inventory_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/supplier/transactions',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Transactions',
                moduleNote: 'Supply transaction & payment history (module 9).',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/supplier/profile', builder: (context, state) => const SupplierProfileScreen()),
          ]),
        ],
      ),

      // ---------------- Admin ----------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleScaffold(
          navigationShell: shell,
          destinations: const [
            NavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
            NavDestination(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Users'),
            NavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Transactions'),
            NavDestination(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Reports'),
            NavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Dashboard',
                moduleNote: 'Admin panel (module 16) builds this next.',
                icon: Icons.dashboard_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Users',
                moduleNote: 'Manage & verify consumer, merchant, and supplier accounts (module 16).',
                icon: Icons.people_outline_rounded,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/transactions',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Transactions',
                moduleNote: 'Platform-wide orders, payments & subscriptions (module 16).',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/reports',
              builder: (context, state) => const ComingSoonScreen(
                title: 'Reports',
                moduleNote: 'Administrative analytics & PDF/Excel reports (module 15).',
                icon: Icons.bar_chart_outlined,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/settings', builder: (context, state) => const AdminSettingsScreen()),
          ]),
        ],
      ),

      // ---------------- Merchant product detail / form ----------------
      GoRoute(path: '/merchant/products/new', builder: (context, state) => const ProductFormScreen()),
      GoRoute(
        path: '/merchant/products/:id',
        builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/merchant/products/:id/edit',
        builder: (context, state) => ProductFormScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/merchant/products/:id/adjust-stock',
        builder: (context, state) => StockAdjustmentScreen(productId: state.pathParameters['id']!),
      ),

      // ---------------- Cross-linked detail / secondary screens ----------------
      // Registered as top-level pushes so the bottom nav bar (from the
      // shell that pushed them) stays visible underneath. Filled in module
      // by module; each currently honestly marks itself as pending.
      GoRoute(path: '/merchant/store', builder: (context, state) => const StoreProfileScreen()),
      GoRoute(
        path: '/merchant/inventory/movements/:productId',
        builder: (context, state) => StockMovementHistoryScreen(productId: state.pathParameters['productId']!),
      ),
      ..._pendingDetailRoutes,
    ],
  );
});

final _pendingDetailRoutes = <RouteBase>[
  for (final entry in <(String, String, String)>[
    ('/consumer/profile/edit', 'Edit Profile', 'Profile editing (module 1 follow-up).'),
    ('/consumer/addresses', 'Saved Addresses', 'Address book (module 6).'),
    ('/consumer/credit', 'Store Credit', 'Consumer loan / store credit tracking (module 8).'),
    ('/consumer/followed', 'Followed Products', 'Back-in-stock following (module 9).'),
    ('/consumer/notification-settings', 'Notification Preferences', 'Notification center (module 12).'),
    ('/consumer/security', 'Security', 'Security settings (module 1 follow-up).'),
    ('/merchant/suppliers', 'Suppliers', 'Supplier directory (module 9).'),
    ('/merchant/barcode-settings', 'Barcode / QR Settings', 'Optional barcode/QR module (module 11).'),
    ('/merchant/reviews', 'Store Reviews', 'Store reviews & responses (module 11).'),
    ('/merchant/subscription', 'Subscription Plan', 'Subscription plans (module 14).'),
    ('/merchant/reports', 'Reports', 'Sales/inventory/financial reports (module 15).'),
    ('/merchant/notification-settings', 'Notification Preferences', 'Notification center (module 12).'),
    ('/merchant/security', 'Security', 'Security settings (module 1 follow-up).'),
    ('/supplier/company', 'Company Profile', 'Supplier profile management (module 9).'),
    ('/supplier/notification-settings', 'Notification Settings', 'Notification center (module 12).'),
    ('/supplier/security', 'Security', 'Security settings (module 1 follow-up).'),
    ('/admin/categories', 'Product Categories', 'Category management (module 16).'),
    ('/admin/subscription-plans', 'Subscription Plans', 'Plan configuration (module 14).'),
    ('/admin/payment-settings', 'Payment Options & Fees', 'Platform settings (module 16).'),
    ('/admin/reservation-rules', 'Reservation Rules', 'Platform settings (module 16).'),
    ('/admin/reports-moderation', 'Reported Stores & Reviews', 'Moderation (module 16).'),
    ('/admin/audit-log', 'Audit Log', 'Audit log viewer (module 16).'),
    ('/admin/security', 'Security', 'Security settings (module 1 follow-up).'),
  ])
    GoRoute(
      path: entry.$1,
      builder: (context, state) => ComingSoonScreen(title: entry.$2, moduleNote: entry.$3),
    ),
];
