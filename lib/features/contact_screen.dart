import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_core.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Contact us'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Have a question, found a bug, or just want to reach out? '
            'Pick whichever works best for you.',
            style: TextStyle(color: colors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          _ContactTile(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: '+234 805 660 4409',
            onTap: () => _launch(
              context,
              Uri.parse('https://wa.me/2348056604409'),
            ),
          ),
          _ContactTile(
            icon: Icons.call_rounded,
            iconColor: colors.accentEnd,
            title: 'Support line',
            subtitle: '0806 542 5732',
            onTap: () => _launch(
              context,
              Uri.parse('tel:08065425732'),
            ),
          ),
          _ContactTile(
            icon: Icons.mail_rounded,
            iconColor: colors.accentEnd,
            title: 'General inquiries',
            subtitle: 'zetraworld0@gmail.com',
            onTap: () => _launch(
              context,
              Uri.parse('mailto:zetraworld0@gmail.com'),
            ),
          ),
          _ContactTile(
            icon: Icons.mail_outline_rounded,
            iconColor: colors.textSecondary,
            title: 'Founder\'s email',
            subtitle: 'coderinnovator@gmail.com',
            onTap: () => _launch(
              context,
              Uri.parse('mailto:coderinnovator@gmail.com'),
            ),
          ),
          _ContactTile(
            icon: Icons.alternate_email_rounded,
            iconColor: colors.textSecondary,
            title: 'ZetraMail',
            subtitle: 'toluwaconnect@zetramail.ng',
            onTap: () => _launch(
              context,
              Uri.parse('mailto:toluwaconnect@zetramail.ng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
