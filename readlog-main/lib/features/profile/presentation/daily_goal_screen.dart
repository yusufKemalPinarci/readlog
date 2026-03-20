import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/profile_providers.dart';
import '../../../shared/widgets/book_scaffold.dart';

class DailyGoalScreen extends ConsumerStatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  ConsumerState<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends ConsumerState<DailyGoalScreen> {
  int _selectedMinutes = 45;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profileAsync = ref.read(profileProvider);
    profileAsync.whenData((profile) {
      _selectedMinutes = profile.dailyGoalMinutes;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final profileAsync = ref.read(profileProvider);
    await profileAsync.when(
      data: (current) async {
        final updated = current.copyWith(dailyGoalMinutes: _selectedMinutes);
        await ref.read(profileRepositoryProvider).update(updated);
        ref.invalidate(profileProvider);
      },
      loading: () async {},
      error: (_, __) async {},
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return BookScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Günlük Hedef'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (_selectedMinutes == 45 && profile.dailyGoalMinutes != 45) {
            _selectedMinutes = profile.dailyGoalMinutes;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Günde kaç dakika okumayı hedefliyorsunuz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '$_selectedMinutes dk',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '5 dk',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Expanded(
                        child: Slider(
                          value: _selectedMinutes.toDouble(),
                          min: 5,
                          max: 180,
                          divisions: 35,
                          label: '$_selectedMinutes dk',
                          onChanged: (value) {
                            setState(() {
                              _selectedMinutes = value.round();
                            });
                          },
                        ),
                      ),
                      const Text(
                        '180 dk',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _PresetButton(
                        minutes: 20,
                        selected: _selectedMinutes == 20,
                        onTap: () => setState(() => _selectedMinutes = 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PresetButton(
                        minutes: 45,
                        selected: _selectedMinutes == 45,
                        onTap: () => setState(() => _selectedMinutes = 45),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PresetButton(
                        minutes: 60,
                        selected: _selectedMinutes == 60,
                        onTap: () => setState(() => _selectedMinutes = 60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Kaydet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
        foregroundColor: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text('$minutes dk'),
    );
  }
}

