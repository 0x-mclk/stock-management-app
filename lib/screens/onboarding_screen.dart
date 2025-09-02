import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Stok Yönetimi Artık Kolay',
      description:
          'Ürünlerinizi ekleyin, stoklarınızı takip edin ve satışlarınızı kaydedin. Tüm işlemleriniz tek uygulamada!',
      image: Icons.inventory_2_outlined,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Akıllı Raporlama',
      description:
          'Satış raporlarınızı görüntüleyin, karlılık analizlerinizi yapın ve işinizi büyütün.',
      image: Icons.analytics_outlined,
      color: Colors.green,
    ),
    OnboardingPage(
      title: 'Tedarikçi Yönetimi',
      description:
          'Tedarikçilerinizi yönetin, borç takibinizi yapın ve stok girişlerinizi kolaylaştırın.',
      image: Icons.people_outline,
      color: Colors.orange,
    ),
    OnboardingPage(
      title: 'Online mı Offline mı?',
      description:
          'Online: Bulut senkronizasyon, çoklu cihaz desteği, veri güvenliği\n\nOffline: İnternet gerektirmez, hızlı başlangıç, basit kullanım',
      image: Icons.wifi_outlined,
      color: Colors.teal,
    ),
    OnboardingPage(
      title: 'Bulut Senkronizasyon',
      description:
          'Verileriniz güvende! Birden fazla cihazdan erişin ve takımınızla çalışın.',
      image: Icons.cloud_sync_outlined,
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _pages[_currentPage].color.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Remove skip button completely
              const SizedBox(height: 20),

              // Pages
              Expanded(
                flex: 3,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Page indicator
              _buildPageIndicator(),

              const SizedBox(height: 40),

              // Bottom buttons
              _buildBottomSection(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                page.image,
                size: 50,
                color: page.color,
              ),
            ),

            const SizedBox(height: 30),

            // Title
            Text(
              page.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              page.description,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? _pages[_currentPage].color
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          if (isLastPage) ...[
            // Final page - show action buttons
            const Text(
              'Başlamaya Hazır mısınız?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Primary Auth buttons (Login and Register)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _goToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _goToRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Kayıt Ol',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Hesabın varsa giriş yap, ürünlerini hızlıca entegre et!\nHesabın yoksa kaydol, bulut entegrasyonlu çoklu cihazlarda çalış!',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'veya',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 12),

            // Secondary option - Quick Start
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: _quickStart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Hızlı Başlangıç (Offline)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Bunlarla uğraşmak istemiyorsan, hemen başla!',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // Navigation buttons for non-final pages
            Row(
              mainAxisAlignment: _currentPage == 0
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: Text(
                      'Geri',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  child: Text(_currentPage == 0 ? 'Başlayalım' : 'İleri'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _quickStart() {
    Navigator.of(context).pushReplacementNamed('/quick-start');
  }

  void _goToLogin() {
    // For now, redirect to quick start until login screen is implemented
    Navigator.of(context).pushReplacementNamed('/quick-start');
  }

  void _goToRegister() {
    // For now, redirect to quick start until register screen is implemented
    Navigator.of(context).pushReplacementNamed('/quick-start');
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData image;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
}




