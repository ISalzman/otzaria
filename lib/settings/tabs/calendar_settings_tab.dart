import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/navigation/calendar_cubit.dart';
import 'package:otzaria/settings/settings_repository.dart';
import 'package:otzaria/widgets/rtl_text_field.dart';

/// טאב הגדרות לוח שנה
class CalendarSettingsTab extends StatefulWidget {
  const CalendarSettingsTab({super.key});

  @override
  State<CalendarSettingsTab> createState() => _CalendarSettingsTabState();
}

class _CalendarSettingsTabState extends State<CalendarSettingsTab> {
  CalendarCubit? _localCubit;
  bool _showCitySearch = false;

  @override
  void initState() {
    super.initState();
    _initCubit();
  }

  void _initCubit() {
    try {
      // ננסה לקרוא מה-context
      _localCubit = context.read<CalendarCubit>();
    } catch (e) {
      // אם אין CalendarCubit זמין, ניצור חדש
      final settingsRepository = SettingsRepository();
      _localCubit = CalendarCubit(settingsRepository: settingsRepository);
    }
  }

  @override
  void dispose() {
    // נסגור רק אם יצרנו את ה-cubit בעצמנו
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ננסה לקבל את ה-cubit מה-context, אם לא קיים נשתמש בלוקלי
    CalendarCubit cubit;
    try {
      cubit = context.read<CalendarCubit>();
    } catch (e) {
      cubit = _localCubit!;
    }

    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<CalendarCubit, CalendarState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // סוג לוח
                _buildSectionCard(
                  context: context,
                  title: 'סוג לוח',
                  children: [
                    RadioListTile<CalendarType>(
                      title: const Text('לוח עברי', style: TextStyle(fontSize: 16)),
                      value: CalendarType.hebrew,
                      groupValue: state.calendarType,
                      onChanged: (value) {
                        if (value != null) {
                          cubit.changeCalendarType(value);
                        }
                      },
                    ),
                    RadioListTile<CalendarType>(
                      title: const Text('לוח לועזי', style: TextStyle(fontSize: 16)),
                      value: CalendarType.gregorian,
                      groupValue: state.calendarType,
                      onChanged: (value) {
                        if (value != null) {
                          cubit.changeCalendarType(value);
                        }
                      },
                    ),
                    RadioListTile<CalendarType>(
                      title: const Text('לוח משולב', style: TextStyle(fontSize: 16)),
                      value: CalendarType.combined,
                      groupValue: state.calendarType,
                      onChanged: (value) {
                        if (value != null) {
                          cubit.changeCalendarType(value);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // בחירת עיר
                _buildSectionCard(
                  context: context,
                  title: 'עיר',
                  children: [
                    ListTile(
                      leading: const Icon(FluentIcons.location_24_regular),
                      title: const Text('עיר נבחרת', style: TextStyle(fontSize: 16)),
                      subtitle: Text(state.selectedCity, style: const TextStyle(fontSize: 13)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showCitySearch = !_showCitySearch;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('שנה'),
                            const SizedBox(width: 8),
                            Icon(
                              _showCitySearch
                                  ? FluentIcons.chevron_up_24_regular
                                  : FluentIcons.chevron_down_24_regular,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showCitySearch
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _CitySearchWidget(
                                currentCity: state.selectedCity,
                                onCitySelected: (city) {
                                  cubit.changeCity(city);
                                  setState(() {
                                    _showCitySearch = false;
                                  });
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // התראות
                _buildSectionCard(
                  context: context,
                  title: 'התראות',
                  children: [
                    SwitchListTile(
                      secondary:
                          const Icon(FluentIcons.alert_24_regular),
                      title: const Text('הפעל התראות על אירועים', style: TextStyle(fontSize: 16)),
                      value: state.calendarNotificationsEnabled,
                      onChanged: (value) {
                        cubit.changeCalendarNotificationsEnabled(value);
                      },
                    ),
                    if (state.calendarNotificationsEnabled) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, left: 16.0),
                        child: SwitchListTile(
                          title: const Text('השמע צליל בהתראה', style: TextStyle(fontSize: 16)),
                          value: state.calendarNotificationSound,
                          onChanged: (value) {
                            cubit.changeCalendarNotificationSound(value);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'זמן תזכורת לפני האירוע',
                            border: OutlineInputBorder(),
                          ),
                          value: state.calendarNotificationTime,
                          items: const [
                            DropdownMenuItem(value: 60, child: Text('שעה')),
                            DropdownMenuItem(
                                value: 720, child: Text('12 שעות')),
                            DropdownMenuItem(value: 1440, child: Text('יום')),
                            DropdownMenuItem(
                                value: 2880, child: Text('יומיים')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              cubit.changeCalendarNotificationTime(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Widget לחיפוש ובחירת עיר
class _CitySearchWidget extends StatefulWidget {
  final String currentCity;
  final ValueChanged<String> onCitySelected;

  const _CitySearchWidget({
    required this.currentCity,
    required this.onCitySelected,
  });

  @override
  State<_CitySearchWidget> createState() => _CitySearchWidgetState();
}

class _CitySearchWidgetState extends State<_CitySearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  late Map<String, Map<String, Map<String, dynamic>>> _filteredCities;

  @override
  void initState() {
    super.initState();
    _filteredCities = cityCoordinates;
    _searchController.addListener(_filterCities);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCities);
    _searchController.dispose();
    super.dispose();
  }

  void _filterCities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCities = cityCoordinates;
      } else {
        _filteredCities = {};
        cityCoordinates.forEach((country, cities) {
          final matchingCities = Map.fromEntries(cities.entries.where(
              (cityEntry) => cityEntry.key.toLowerCase().contains(query)));
          if (matchingCities.isNotEmpty) {
            _filteredCities[country] = matchingCities;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];
    _filteredCities.forEach((country, cities) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            country,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 16,
            ),
          ),
        ),
      );
      cities.forEach((city, data) {
        items.add(
          ListTile(
            title: Text(city),
            onTap: () => widget.onCitySelected(city),
            dense: true,
          ),
        );
      });
      items.add(const Divider());
    });
    if (items.isNotEmpty) {
      items.removeLast();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RtlTextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'הקלד שם עיר...',
                prefixIcon: Icon(FluentIcons.search_24_regular),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            child: _filteredCities.isEmpty
                ? const Center(child: Text('לא נמצאו ערים'))
                : ListView(children: items),
          ),
        ],
      ),
    );
  }
}
