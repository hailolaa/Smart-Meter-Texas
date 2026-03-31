import '../../domain/entities/promo_offer.dart';

class PromoCatalog {
  const PromoCatalog._();

  static const List<PromoOffer> allOffers = [
    PromoOffer(
      badge: 'Sponsored',
      title: 'Save up to 25% on energy',
      description:
          'Compare electricity plans from top Texas providers. Find lower rates that match your usage.',
      sponsor: 'PowerChoice',
      ctaLabel: 'Compare Plans',
      ctaUrl: 'https://powertochoose.org/',
      imageUrl:
          'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=800&q=80',
    ),
    PromoOffer(
      badge: 'Sponsored',
      title: 'Free Solar Panel Estimate',
      description:
          'See how much you could save with rooftop solar in minutes.',
      sponsor: 'Sunrun Solar',
      ctaLabel: 'Get Estimate',
      ctaUrl: 'https://www.sunrun.com/',
      imageUrl:
          'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=800&q=80',
    ),
    PromoOffer(
      badge: 'Savings',
      title: 'Smart Thermostat Discount',
      description:
          'Reduce peak-hour spend with automated cooling schedules.',
      sponsor: 'EcoHome Deals',
      ctaLabel: 'View Offer',
      ctaUrl: 'https://www.energystar.gov/products/thermostats',
      imageUrl:
          'https://images.unsplash.com/photo-1558002038-1055907df827?w=800&q=80',
    ),
    PromoOffer(
      badge: 'Energy Tip',
      title: 'AC Tune-up Rebate Finder',
      description:
          'Find utility rebates for AC servicing in your area.',
      sponsor: 'Home Efficiency',
      ctaLabel: 'Find Rebates',
      ctaUrl: 'https://www.energy.gov/energysaver/home-cooling-systems',
      imageUrl:
          'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800&q=80',
    ),
  ];

  /// First two offers — displayed under "Hourly Breakdown".
  static List<PromoOffer> get firstGroup => allOffers.sublist(0, 2);

  /// Last two offers — displayed under "Usage History".
  static List<PromoOffer> get secondGroup => allOffers.sublist(2);
}
