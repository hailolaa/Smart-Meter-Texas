import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/promo_offer.dart';

class PromoCarousel extends StatefulWidget {
  final List<PromoOffer> offers;
  final Duration autoScrollInterval;

  const PromoCarousel({
    super.key,
    required this.offers,
    this.autoScrollInterval = const Duration(seconds: 5),
  });

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.offers.length <= 1) return;
    _autoScrollTimer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.offers.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetAutoScroll() {
    _autoScrollTimer?.cancel();
    _startAutoScroll();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.offers.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _resetAutoScroll();
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildCard(widget.offers[index]),
              );
            },
          ),
        ),
        if (widget.offers.length > 1) ...[
          const SizedBox(height: 12),
          _buildDots(),
        ],
      ],
    );
  }

  Widget _buildCard(PromoOffer offer) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image header
          SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (offer.imageUrl != null)
                  Image.network(
                    offer.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF334155),
                    ),
                  )
                else
                  Container(color: const Color(0xFF334155)),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      offer.badge.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Title
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      offer.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMain.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign_outlined, color: Colors.grey[400], size: 18),
                          const SizedBox(width: 6),
                          Text(
                            offer.sponsor.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[500],
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: () => _openUrl(offer.ctaUrl),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: Text(
                            offer.ctaLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.offers.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
