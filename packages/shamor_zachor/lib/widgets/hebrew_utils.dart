/// Utility class for Hebrew text formatting and conversions
class HebrewUtils {
  /// Convert integer to Hebrew gematria
  static String intToGematria(int number) {
    if (number <= 0) return '';
    
    const Map<int, String> gematriaMap = {
      1: 'א', 2: 'ב', 3: 'ג', 4: 'ד', 5: 'ה', 6: 'ו', 7: 'ז', 8: 'ח', 9: 'ט',
      10: 'י', 20: 'כ', 30: 'ל', 40: 'מ', 50: 'נ', 60: 'ס', 70: 'ע', 80: 'פ', 90: 'צ',
      100: 'ק', 200: 'ר', 300: 'ש', 400: 'ת'
    };
    
    if (number <= 400 && gematriaMap.containsKey(number)) {
      return gematriaMap[number]!;
    }
    
    String result = '';
    int remaining = number;
    
    // Handle hundreds
    while (remaining >= 100) {
      if (remaining >= 400) {
        result += 'ת';
        remaining -= 400;
      } else if (remaining >= 300) {
        result += 'ש';
        remaining -= 300;
      } else if (remaining >= 200) {
        result += 'ר';
        remaining -= 200;
      } else {
        result += 'ק';
        remaining -= 100;
      }
    }
    
    // Handle tens
    while (remaining >= 10) {
      if (remaining >= 90) {
        result += 'צ';
        remaining -= 90;
      } else if (remaining >= 80) {
        result += 'פ';
        remaining -= 80;
      } else if (remaining >= 70) {
        result += 'ע';
        remaining -= 70;
      } else if (remaining >= 60) {
        result += 'ס';
        remaining -= 60;
      } else if (remaining >= 50) {
        result += 'נ';
        remaining -= 50;
      } else if (remaining >= 40) {
        result += 'מ';
        remaining -= 40;
      } else if (remaining >= 30) {
        result += 'ל';
        remaining -= 30;
      } else if (remaining >= 20) {
        result += 'כ';
        remaining -= 20;
      } else {
        result += 'י';
        remaining -= 10;
      }
    }
    
    // Handle units
    if (remaining > 0 && gematriaMap.containsKey(remaining)) {
      result += gematriaMap[remaining]!;
    }
    
    return result;
  }
  
  /// Format Hebrew date
  static String formatHebrewDate(DateTime date) {
    // Simple Hebrew date formatting - can be enhanced with proper Hebrew calendar
    const months = [
      'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
      'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}