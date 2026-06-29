import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_tokens.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/tabs/about_settings_data.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/widgets/dialogs/ad_popup_dialog.dart';

/// טאב "חכמי לב" — אודות, קהילה, תורמים ומפתחים.
class AboutSettingsTab extends StatelessWidget {
  const AboutSettingsTab({super.key});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'about.team',
      title: 'אודות הצוות',
      subtitle: 'מידע על מפתחי אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['אודות', 'מפתחים', 'צוות'],
    ),
    SettingsSearchEntry(
      id: 'about.donate',
      title: 'תרום לפרויקט',
      subtitle:
          'תרומתך תעזור לנו להמשיך לפתח ולשפר את אוצריא עבור כלל ציבור הלומדים',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['תרומה', 'נדרים', 'תרום', 'donate'],
    ),
    SettingsSearchEntry(
      id: 'about.aid',
      title: 'אוצריא מתגייסת לעזרת לומדי התורה',
      subtitle: 'מרכז המידע על ארגוני סיוע ללומדי התורה',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['סיוע', 'תורה', 'לומדי תורה', 'עזרה'],
    ),
    SettingsSearchEntry(
      id: 'about.editing',
      title: 'הצטרף לצוות העריכה',
      subtitle: 'עזור לנו להוסיף ספרים חדשים לספריית אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['עריכה', 'הצטרף', 'הוספת ספרים'],
    ),
    SettingsSearchEntry(
      id: 'about.dev',
      title: 'הצטרף לפיתוח',
      subtitle: 'מפתחים מוזמנים לתרום לקהילה התורנית',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['פיתוח', 'הצטרף', 'מפתחים', 'דיבלפר', 'developers'],
    ),
    SettingsSearchEntry(
      id: 'about.donors',
      title: 'תורמים',
      subtitle: 'רשימת תורמי אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['תורמים', 'donors'],
    ),
    SettingsSearchEntry(
      id: 'about.developers',
      title: 'מפתחים',
      subtitle: 'רשימת מפתחי אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['מפתחים', 'צוות פיתוח', 'developers'],
    ),
    SettingsSearchEntry(
      id: 'about.libraries',
      title: 'התוכנה נעזרה רבות ב:',
      subtitle: 'ספריות וכלים שאוצריא משתמשת בהם',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['ספריות', 'open source', 'קרדיטים'],
    ),
    SettingsSearchEntry(
      id: 'about.editors',
      title: 'מהדירי ספרים',
      subtitle: 'רשימת מהדירי הספרים בספריית אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['מהדירים', 'עורכים'],
    ),
    SettingsSearchEntry(
      id: 'about.feedback',
      title: 'משוב ותמיכה',
      subtitle: 'פורום התמיכה והמשוב של אוצריא',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['משוב', 'תמיכה', 'פורום', 'באג', 'שאלה'],
    ),
    SettingsSearchEntry(
      id: 'about.sources',
      title: 'מקור הספרים',
      subtitle: 'ספריא, דיקטה, אורייתא ועוד',
      tab: SettingsTab.about,
      cardId: 'about.main',
      keywords: ['מקור', 'ספריא', 'דיקטה', 'sefaria', 'אורייתא'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(16.0),
      child: ToolPanelWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsAnchor(
              cardId: 'about.main',
              child: _buildHeader(context),
            ),

            // ── סיוע ──
            SettingsCard(
              title: 'סיוע ללומדי תורה',
              children: [
                SettingsActionTile.text(
                  icon: FluentIcons.shield_task_24_filled,
                  title: 'אוצריא מתגייסת לעזרת לומדי התורה',
                  subtitle: 'מרכז המידע על ארגוני סיוע ללומדי התורה',
                  actions: [
                    ActionButton.recommended(
                      text: 'למידע נוסף',
                      onPressed: () => _openAdPopup(context),
                    ),
                  ],
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ── תורמים ──
            SettingsCard(
              title: 'תורמים',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _MemorialCardsGrid(
                    onDonationTap: () => _openUrl('https://nedar.im/ezOd'),
                  ),
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ── מפתחים ──
            SettingsCard(
              title: 'אודות פיתוח התוכנה',
              children: [
                _cardTitle(context, 'מפתחים'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _InfoChipWrap(
                    items: aboutDevelopers,
                    icon: FluentIcons.person_24_regular,
                  ),
                ),
                SettingsActionTile.text(
                  icon: FluentIcons.code_24_regular,
                  title: 'הצטרף לפיתוח',
                  subtitle:
                      'מפתחים מוזמנים לתרום לקהילה התורנית ולשדרג את אוצריא',
                  actions: [
                    ActionButton.recommended(
                      text: 'הצטרף עכשיו',
                      onPressed: () =>
                          _openUrl('https://github.com/otzaria/otzaria'),
                    ),
                  ],
                ),
                SettingsActionTile.text(
                  icon: FluentIcons.chat_24_regular,
                  title: 'נתקלת בבאג? יש לך שאלה או משוב?',
                  subtitle: 'מוזמנים לבקר בפורום התמיכה והמשוב של אוצריא',
                  actions: [
                    ActionButton.recommended(
                      text: 'כניסה לפורום',
                      onPressed: () => _openUrl('https://otzaria.org/forum'),
                    ),
                  ],
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ── אנשים חיוניים ──
            SettingsCard(
              title: 'התוכנה נעזרה רבות ב:',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _InfoChipWrap(
                    items: aboutEssentialPeople,
                    icon: FluentIcons.people_24_regular,
                  ),
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ── אודות ספריית אוצריא ──
            SettingsCard(
              title: 'אודות ספריית אוצריא',
              children: [
                _cardTitle(
                  context,
                  'מקור הספרים',
                  subtitle:
                      'הספרים הותאמו במיוחד עבור אוצריא, וכן נוספו ספרים רבים '
                      'נוספים בזכות עבודתם המסורה של מהדירי הספרים.',
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _BookSourcesSection(),
                ),
                _cardTitle(
                  context,
                  'מהדירי ספרים',
                  subtitle:
                      'באם שמכם אינו מופיע ברשימה או שאתם מעוניינים בשינוי, '
                      'אנא פנו למייל המערכת.',
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editorCategory('10 ספרים ומעלה', aboutTopEditors),
                      const SizedBox(height: 20),
                      _editorCategory('בין 5 ל-10 ספרים', aboutRegularEditors),
                    ],
                  ),
                ),
                SettingsActionTile.text(
                  icon: FluentIcons.edit_24_regular,
                  title: 'הצטרף לצוות העריכה ומהדירי הספרים',
                  subtitle: 'עזור לנו להוסיף ספרים חדשים לספריית אוצריא',
                  actions: [
                    ActionButton.recommended(
                      text: 'הצטרף לעריכה',
                      onPressed: () =>
                          _openUrl('https://www.otzaria.org/library'),
                    ),
                  ],
                ),
              ],
            ),

            kSettingsCardSpacing,

            // ── ציטוט סיום ──
            SettingsCard(
              children: [_ClosingQuote()],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Image.asset(
            'assets/icon/iconnew.png',
            width: 60,
            height: 60,
            errorBuilder: (_, __, ___) =>
                const Icon(FluentIcons.library_24_regular, size: 60),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'אוצריא',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'מאגר תורני חינמי, רחב ומהיר לשימוש בכל מקום.',
                  style: kSettingsSubtitleStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// כותרת כרטיס המוצגת בתוך ה-children — ממורכזת, צבע primary, מעט גדולה יותר.
  /// [subtitle] אופציונלי — מוצג ממורכז מתחת לכותרת בעיצוב תת-כותרת רגיל.
  Widget _cardTitle(BuildContext context, String text, {String? subtitle}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: kSettingsSubtitleStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editorCategory(String label, List<Map<String, String>> editors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'מהדירים שההדירו $label',
          style: kSettingsSubtitleStyle,
        ),
        const SizedBox(height: 8),
        _InfoChipWrap(
          items: editors,
          icon: FluentIcons.book_24_regular,
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openAdPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AdPopupDialog(
        title: 'אוצריא מתגייסת לעזרת לומדי התורה',
      ),
    );
  }
}

// ── _InfoChip ─────────────────────────────────────────────────────────────────

/// צ'יפ מידע אחיד לכל סוגי הנתונים בטאב — אייקון אפור + שם (primary כשיש קישור),
/// תיאור אופציונלי בסוגריים, ולחיץ כשקיים url. מאוחד לכל הסקציות.
class _InfoChipWrap extends StatelessWidget {
  final List<Map<String, String>> items;
  final IconData icon;

  const _InfoChipWrap({required this.items, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: items
          .map((c) => _InfoChip(
                name: c['name']!,
                url: c['url'] ?? '',
                description: c['description'],
                icon: icon,
              ))
          .toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String name;
  final String url;
  final String? description;
  final IconData icon;

  const _InfoChip({
    required this.name,
    required this.url,
    this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUrl = url.isNotEmpty;
    final nameStyle = hasUrl
        ? kSettingsTitleStyle.copyWith(color: colorScheme.primary)
        : kSettingsTitleStyle;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RtlIcon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(name, style: nameStyle),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            '(${description!})',
            style: kSettingsSubtitleStyle,
          ),
        ],
      ],
    );

    if (!hasUrl) return content;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      borderRadius: AppTokens.borderRadiusAll,
      child: content,
    );
  }
}

// ── _MemorialCardsGrid ────────────────────────────────────────────────────────

class _MemorialCardsGrid extends StatelessWidget {
  final VoidCallback onDonationTap;
  const _MemorialCardsGrid({required this.onDonationTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 400) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MemorialCard(
              name: "לע\"נ ר' משה בן יהודה ראה ז\"ל",
              description: 'סכום משמעותי לפיתוח התוכנה',
            ),
            const SizedBox(height: 12),
            _DonationMemorialCard(onTap: onDonationTap),
            const SizedBox(height: 12),
            _DonationMemorialCard(onTap: onDonationTap),
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MemorialCard(
                name: "לע\"נ ר' משה בן יהודה ראה ז\"ל",
                description: 'סכום משמעותי לפיתוח התוכנה',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _DonationMemorialCard(onTap: onDonationTap)),
            const SizedBox(width: 12),
            Expanded(child: _DonationMemorialCard(onTap: onDonationTap)),
          ],
        ),
      );
    });
  }
}

class _MemorialCard extends StatelessWidget {
  final String name;
  final String description;
  const _MemorialCard({required this.name, required this.description});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.heart_24_filled,
                color: colorScheme.primary, size: 24),
            const SizedBox(height: 6),
            Text(name,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(description,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _DonationMemorialCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DonationMemorialCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.heart_24_regular,
                color: colorScheme.primary.withValues(alpha: 0.6), size: 24),
            const SizedBox(height: 6),
            Text(
              'מקום זה יכול להיות מונצח לע"נ יקירך',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            ActionButton.recommended(
              icon: FluentIcons.payment_24_regular,
              text: 'נדרים+',
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _BookSourcesSection ───────────────────────────────────────────────────────

class _BookSourcesSection extends StatelessWidget {
  const _BookSourcesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'מקור חלק גדול מהספרים בספריית אוצריא נלקח מהפרויקט המדהים של ספריא ושל עמותת דיקטה, שבאמצעותו נוספו חלק ניכר מהספרים.',
          style: kSettingsSubtitleStyle,
        ),
        const SizedBox(height: 10),
        _InfoChipWrap(
          items: aboutMainSources,
          icon: FluentIcons.library_24_regular,
        ),
        const SizedBox(height: 16),
        Text(
          'כמו כן נוספו ספרים חשובים רבים מהפרויקטים הבאים:',
          style: kSettingsSubtitleStyle,
        ),
        const SizedBox(height: 10),
        _InfoChipWrap(
          items: aboutAdditionalSources,
          icon: FluentIcons.library_24_regular,
        ),
      ],
    );
  }
}

// ── _ClosingQuote ─────────────────────────────────────────────────────────────

class _ClosingQuote extends StatelessWidget {
  const _ClosingQuote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: AppTokens.borderRadiusAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Icon(FluentIcons.book_open_24_regular,
                  size: 32, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'וְצִדְקָתוֹ עֹמֶדֶת לָעַד',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '(תהילים קיב, ג)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.6))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(FluentIcons.sparkle_24_regular,
                          size: 14,
                          color: colorScheme.primary.withValues(alpha: 0.6)),
                    ),
                    Expanded(
                        child: Divider(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Text(
                'זֶה הַכּוֹתֵב סְפָרִים וּמַשְׁאִילָן לַאֲחֵרִים',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '(כתובות נ.)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
