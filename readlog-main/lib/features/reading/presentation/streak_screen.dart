import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/widgets/book_scaffold.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final primaryContainer = colorScheme.primaryContainer;
    final onPrimaryContainer = colorScheme.onPrimaryContainer;
    
    return BookScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.local_fire_department,
                size: 100,
                color: primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Harika!',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bugün ilk okumanı tamamladın!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Okuma serini devam ettir ve her gün oku!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
              ),
              const Spacer(flex: 2),
              Card(
                elevation: 0,
                color: primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: onPrimaryContainer),
                          const SizedBox(width: 12),
                          Text(
                            '1 Gün',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Okuma Serisi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(Routes.home),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}



