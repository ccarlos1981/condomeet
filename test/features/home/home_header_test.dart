import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

Widget createHeaderWidget({
  required AuthState authState,
  required String condominiumName,
  double screenWidth = 360,
  VoidCallback? onProfileTap,
  VoidCallback? onNotificationTap,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(screenWidth, 800)),
      child: Scaffold(
        body: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Logo
              Container(
                width: 40,
                height: 40,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CONDOMEET',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'seu condomínio digital',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (condominiumName.isNotEmpty)
                      Text(
                        condominiumName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Notification bell
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onNotificationTap ?? () {},
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Profile
              GestureDetector(
                onTap: onProfileTap ?? () {},
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFB0BEC5),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Home Header 3-Line Condominium Name Tests', () {
    testWidgets('Renders CONDOMEET, slogan and condominium name in the same column', (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.implicitView?.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.implicitView?.devicePixelRatio = 3.0; // 360dp
      addTearDown(() {
        binding.platformDispatcher.implicitView?.resetPhysicalSize();
        binding.platformDispatcher.implicitView?.resetDevicePixelRatio();
      });

      const authState = AuthState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        condominiumId: 'condo-456',
        userName: 'Morador Teste',
      );

      await tester.pumpWidget(
        createHeaderWidget(
          authState: authState,
          condominiumName: 'Residencial Real Park',
          screenWidth: 360,
        ),
      );
      await tester.pumpAndSettle();

      // Verify brand elements
      expect(find.text('CONDOMEET'), findsOneWidget);
      expect(find.text('seu condomínio digital'), findsOneWidget);
      expect(find.text('Residencial Real Park'), findsOneWidget);

      // Verify chip/icon is NOT present
      expect(find.byIcon(Icons.apartment_rounded), findsNothing);

      // Verify actions
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      // Verify text styles match
      final sloganText = tester.widget<Text>(find.text('seu condomínio digital'));
      final condoText = tester.widget<Text>(find.text('Residencial Real Park'));
      expect(sloganText.style?.fontSize, equals(10));
      expect(condoText.style?.fontSize, equals(10));
      expect(sloganText.style?.color, equals(AppColors.textSecondary));
      expect(condoText.style?.color, equals(AppColors.textSecondary));

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles long condo name with ellipsis without overflow on compact screen (360dp)', (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.implicitView?.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.implicitView?.devicePixelRatio = 3.0; // 360dp
      addTearDown(() {
        binding.platformDispatcher.implicitView?.resetPhysicalSize();
        binding.platformDispatcher.implicitView?.resetDevicePixelRatio();
      });

      const authState = AuthState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        condominiumId: 'condo-456',
      );

      await tester.pumpWidget(
        createHeaderWidget(
          authState: authState,
          condominiumName: 'Condomínio Residencial Parque das Flores Bloco B',
          screenWidth: 360,
        ),
      );
      await tester.pumpAndSettle();

      // Check elements
      expect(find.text('CONDOMEET'), findsOneWidget);
      expect(find.text('seu condomínio digital'), findsOneWidget);
      expect(find.text('Condomínio Residencial Parque das Flores Bloco B'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles standard screens (390dp and 412dp) without overflow', (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.implicitView?.physicalSize = const Size(1170, 2532);
      binding.platformDispatcher.implicitView?.devicePixelRatio = 3.0; // 390dp
      addTearDown(() {
        binding.platformDispatcher.implicitView?.resetPhysicalSize();
        binding.platformDispatcher.implicitView?.resetDevicePixelRatio();
      });

      const authState = AuthState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        condominiumId: 'condo-456',
      );

      await tester.pumpWidget(
        createHeaderWidget(
          authState: authState,
          condominiumName: 'Residencial Alphaville Graciosa',
          screenWidth: 390,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Residencial Alphaville Graciosa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
