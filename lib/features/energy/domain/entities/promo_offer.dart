class PromoOffer {
  const PromoOffer({
    required this.badge,
    required this.title,
    required this.description,
    required this.sponsor,
    required this.ctaLabel,
    required this.ctaUrl,
    this.imageUrl,
  });

  final String badge;
  final String title;
  final String description;
  final String sponsor;
  final String ctaLabel;
  final String ctaUrl;
  final String? imageUrl;
}
