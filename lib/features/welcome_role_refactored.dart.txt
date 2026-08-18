import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_core.dart';

class WelcomeRoleScreen extends ConsumerStatefulWidget {
  const WelcomeRoleScreen({super.key});

  @override
  ConsumerState<WelcomeRoleScreen> createState() => _WelcomeRoleScreenState();
}

class _WelcomeRoleScreenState extends ConsumerState<WelcomeRoleScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('role_choice_made', true);
      await prefs.setString('user_role', role);

      if (!mounted) return;

      // Navigate back to home
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.bgPrimary, colors.bgSecondary],
                ),
              ),
            ),
            // Top-right glow blob
            Positioned(
              top: -90,
              right: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentStart.withOpacity(0.20),
                ),
              ),
            ),
            // Bottom-left glow blob
            Positioned(
              bottom: -110,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentEnd.withOpacity(0.14),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Welcome to Zetra Store',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose how you\'d like to use the app',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 56),
                  _RoleCard(
                    role: 'Developer',
                    description: 'Publish and manage your apps',
                    icon: Icons.code_rounded,
                    isSelected: _selectedRole == 'Developer',
                    onTap: _isLoading
                        ? null
                        : () => _selectRole('Developer'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    role: 'Tester',
                    description: 'Discover and test beta apps',
                    icon: Icons.bug_report_rounded,
                    isSelected: _selectedRole == 'Tester',
                    onTap: _isLoading
                        ? null
                        : () => _selectRole('Tester'),
                  ),
                  const SizedBox(height: 56),
                  if (_isLoading)
                    SizedBox(
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colors.accentEnd,
                        ),
                      ),
                    )
                  else
                    Text(
                      'You can change this anytime in your profile settings',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String role;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colors.accentEnd
                : colors.cardBorder,
            width: isSelected ? 2 : 1.5,
          ),
          color: isSelected
              ? colors.accentEnd.withOpacity(0.12)
              : colors.card,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.accentEnd.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.accentStart,
                          colors.accentEnd,
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.accentStart.withOpacity(0.3),
                          colors.accentEnd.withOpacity(0.3),
                        ],
                      ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? Colors.white
                      : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? colors.accentEnd
                              : colors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.accentStart,
                      colors.accentEnd,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
