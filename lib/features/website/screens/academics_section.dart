import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_card.dart';
import '../data/website_labels.dart';
import '../widgets/website_cards.dart';
import '../widgets/website_common.dart';

class AcademicsSection extends ConsumerWidget {
  const AcademicsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WebPage(
      title: 'Akademik',
      children: [
        ResponsiveGrid(
          minItemWidth: 240,
          gap: 16,
          children: [
            for (final (title, pageKey) in WebsiteLabels.akademikInfo)
              CustomCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.webH3),
                    const SizedBox(height: 8),
                    PageText(pageKey),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 40, bottom: 16),
          child: Text('Kalender Akademik', style: context.webH2),
        ),
        const CustomCard(margin: EdgeInsets.zero, child: PageText('akademik-kalender')),
        Padding(
          padding: const EdgeInsets.only(top: 40, bottom: 16),
          child: Text('Informasi Kelas', style: context.webH2),
        ),
        ResponsiveGrid(
          minItemWidth: 240,
          gap: 16,
          children: [
            for (var k = 1; k <= 6; k++)
              CustomCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kelas $k', style: context.webBody.copyWith(fontWeight: FontWeight.w700)),
                    PageText('kelas-$k', style: context.webCap),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 40),
        DarkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informasi untuk Orang Tua',
                style: context.webH2.copyWith(color: AppColors.onDarkCard),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'Pantau perkembangan belajar anak melalui Portal Orang Tua. Orang tua hanya dapat melihat data anak sendiri.',
                  style: context.webBody.copyWith(color: AppColors.onDarkCardMuted),
                ),
              ),
              ButtonRow(
                children: [
                  CustomButton(
                    label: 'Login Orang Tua',
                    onDark: true,
                    onPressed: () => openParentLogin(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
