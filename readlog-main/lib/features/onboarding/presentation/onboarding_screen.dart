import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/services/local_storage_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _pulseController;

  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'ReadLog\'a Hoş Geldiniz',
      description: 'Kitap okuma alışkanlığınızı takip edin, hedeflerinize ulaşın.',
      icon: Icons.menu_book_rounded,
    ),
    _OnboardingPageData(
      title: 'İstatistiklerinizi Görün',
      description: 'Okuma sürenizi, sayfa ilerlemenizi ve okuma serinizi takvim ve haftalık grafiklerle takip edin.',
      icon: Icons.bar_chart_rounded,
    ),
    _OnboardingPageData(
      title: 'Sesli Okuma Modu',
      description: 'Okuma oturumunuzu sesli modda başlatın ve düşüncelerinizi anında kaydedin. Kaydı daha sonra dinleyerek tekrar gözden geçirebilirsiniz.',
      icon: Icons.mic_rounded,
      highlightColor: Colors.red,
    ),
    _OnboardingPageData(
      title: 'Notlar ve Fotoğraflar',
      description: 'Okuma oturumunuzu bitirirken düşüncelerinizi yazılı not olarak ekleyin veya kitap sayfalarının fotoğrafını kaydedin.',
      icon: Icons.edit_note_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Onboarding tamamlandı
      final storage = ref.read(localStorageServiceProvider);
      await storage.setIsFirstLaunch(false);
      
      if (mounted) {
        context.go(Routes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final isHighlighted = page.highlightColor != null && _currentPage == index;
                            final scale = isHighlighted
                                ? 1.0 + (_pulseController.value * 0.1)
                                : 1.0;
                            final opacity = isHighlighted
                                ? 0.3 + (_pulseController.value * 0.2)
                                : 0.3;
                            
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (page.highlightColor ?? Theme.of(context).primaryColor).withValues(alpha:
                                    isHighlighted ? opacity : 0.15,
                                  ),
                                  border: page.highlightColor != null
                                      ? Border.all(
                                          color: page.highlightColor!.withValues(alpha:
                                            isHighlighted ? opacity + 0.2 : 0.3,
                                          ),
                                          width: 3,
                                        )
                                      : null,
                                  boxShadow: isHighlighted
                                      ? [
                                          BoxShadow(
                                            color: page.highlightColor!.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      page.icon,
                                      size: 80,
                                      color: page.highlightColor ?? Theme.of(context).primaryColor,
                                    ),
                                    if (page.highlightColor != null)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: page.highlightColor,
                                            boxShadow: [
                                              BoxShadow(
                                                color: page.highlightColor!.withValues(alpha: 0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.fiber_new_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: page.highlightColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: page.highlightColor != null
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              : null,
                          decoration: page.highlightColor != null
                              ? BoxDecoration(
                                  color: page.highlightColor!.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: page.highlightColor!.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                )
                              : null,
                          child: Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: page.highlightColor != null
                                  ? page.highlightColor!.withValues(alpha: 0.9)
                                  : Colors.grey[600],
                              fontWeight: page.highlightColor != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Button
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Başla' : 'İleri',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color? highlightColor;

  _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    this.highlightColor,
  });
}
