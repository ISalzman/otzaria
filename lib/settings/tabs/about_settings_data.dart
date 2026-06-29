// נתונים סטטיים לטאב "אודות" — מפתחים, תורמים, מהדירים ומקורות ספרים.
// מופרד מ-about_settings_tab.dart כדי לשמור על קובץ התצוגה נקי.
// כל פריט: 'name' (חובה), 'url' ו-'description' (אופציונליים).

const aboutDevelopers = <Map<String, String>>[
  {'name': 'sivan22', 'url': 'https://github.com/Sivan22'},
  {
    'name': 'ר. נבון',
    'url': 'https://github.com/rachelGrayover',
    'description': 'השקעה עצומה במעבר ל-SQLite',
  },
  {'name': 'Y.PL.', 'url': 'https://github.com/Y-PLONI'},
  {'name': 'palmoni', 'url': 'https://github.com/palmoni5'},
  {'name': 'YOSEFTT', 'url': 'https://github.com/YOSEFTT'},
  {'name': 'zevisvei', 'url': 'https://github.com/zevisvei'},
  {'name': 'evel-avalim', 'url': 'https://github.com/evel-avalim'},
  {'name': 'userbot', 'url': 'https://github.com/userbot000'},
  {'name': 'shlomo', 'url': 'https://github.com/DeveShlomo'},
  {'name': 'mosh-dvd', 'url': 'https://github.com/mosh-dvd'},
  {
    'name': 'NHLOCAL',
    'url': 'https://github.com/NHLOCAL/Shamor-Zachor',
    'description': "מפתח 'שמור וזכור'",
  },
  {'name': 'michaelush', 'url': 'https://github.com/mmichaelush'},
];

const aboutEssentialPeople = <Map<String, String>>[
  {'name': 'דוד אריאל', 'url': ''},
  {'name': 'רפאל א.', 'url': ''},
  {'name': 'יעקב מ. פינס', 'url': 'https://github.com/ymp112'},
];

// מהדירים שההדירו 10 ספרים ומעלה
const aboutTopEditors = <Map<String, String>>[
  {
    'name': 'י. פל',
    'url': 'https://forum.otzaria.org/user/%D7%99.-%D7%A4%D7%9C.',
  },
  {
    'name': 'האדם החושב', // האדם החושב
    'url':
        'https://forum.otzaria.org/user/%D7%94%D7%90%D7%93%D7%9D-%D7%94%D7%97%D7%95%D7%A9%D7%91',
  },
  {
    'name': 'י. ח. מ.', // יום חדש מתחיל
    'url':
        'https://forum.otzaria.org/user/%D7%99%D7%95%D7%9D-%D7%97%D%93%D7%A9-%D7%9E%D7%AA%D7%97%D7%99%D7%9C',
  },
  {
    'name': 'ס. כב.', // sivan22
    'url': 'https://mitmachim.top/user/sivan22'
  },
  {
    'name': 'י. צ.', // יהודי צעיר
    'url':
        'https://forum.otzaria.org/user/%D7%99%D7%94%D7%95%D7%93%D7%99-%D7%A6%D7%A2%D7%99%D7%A8',
  },
  // {
  //   'name': 'דורש טוב',  // כרגע לא רוצה
  //   'url':
  //       'https://forum.otzaria.org/user/%D7%93%D7%95%D7%A8%D7%A9-%D7%98%D7%95%D7%91',
  // },
  // {
  //   'name': 'מ. פינק', // כרגע לא רוצה
  // },
  // {
  //   'name': 'זקצ',
  // },
  {
    'name': 'קטנטן', // ד. בנדל
    'url': 'https://forum.otzaria.org/user/%D7%A7%D7%98%D7%A0%D7%98%D7%9F',
  },
  {
    'name': 'ד.', // דאנציג
    'url':
        'https://forum.otzaria.org/user/%D7%93%D7%90%D7%A0%D7%A6%D7%99%D7%92',
  },
  {
    'name': 'י. א.', // ישי אשכנזי
  },
  {
    'name': '333',
    'url': 'https://forum.otzaria.org/user/333',
  },
  {
    'name': "ט. ג.", // "טכנולוגי גו'ניור", // י. אייזנשטיין
    'url':
        'https://forum.otzaria.org/user/%D7%98%D7%9B%D7%A0%D7%95%D7%9C%D7%95%D7%92%D7%99-%D7%92%D7%95-%D7%A0%D7%99%D7%95%D7%A8',
  },
  {
    'name': 'ה. ה.', // גאון גדול - הבל הבלים
    'url':
        'https://forum.otzaria.org/user/%D7%94%D7%91%D7%9C-%D7%94%D7%91%D7%9C%D7%99%D7%9D',
  },
  {
    'name': 'י. א. ח.', // U88
    'url': 'https://otzaria.org/forum/user/u88',
  },
  {
    'name': 'מיכאלוש', // מיכאלוש
    'url':
        'https://otzaria.org/forum/user/%D7%9E%D7%99%D7%9B%D7%90%D7%9C%D7%95%D7%A9',
  },
];

// מהדירים שההדירו בין 5 ל-10 ספרים
const aboutRegularEditors = <Map<String, String>>[
  {
    'name': 'מויטיו',
    'url': 'https://mitmachim.top/user/%D7%9E%D7%95%D7%99%D7%98%D7%99%D7%95',
  },
  {
    'name': 'ד. מ. א.', // דוד משה 1
    'url':
        'https://forum.otzaria.org/user/%D7%93%D7%95%D7%93-%D7%9E%D7%A9%D7%94-1',
  },
  {
    'name': 'א. צ. מ.', // איש צדיק מידי
    'url':
        'https://forum.otzaria.org/user/%D7%90%D7%99%D7%A9-%D7%A6%D7%93%D7%99%D7%A7-%D7%9E%D7%99%D7%93%D7%99',
  },
  {
    'name': 'שני אנשים',
    'url':
        'https://forum.otzaria.org/user/%D7%A9%D7%A0%D7%99-%D7%90%D7%A0%D7%A9%D7%99%D7%9D',
  },
  {
    'name': 'י. ד.', // יאיר דניאל
    'url':
        'https://forum.otzaria.org/user/%D7%99%D7%90%D7%99%D7%A8-%D7%93%D7%A0%D7%99%D7%90%D7%9C',
  },
  {
    'name': 'ש. נ.', // שילה נוי
  },
];

const aboutMainSources = <Map<String, String>>[
  {'name': 'ספריא', 'url': 'https://www.sefaria.org/texts'},
  {
    'name': 'דיקטה',
    'url':
        'https://github.com/Dicta-Israel-Center-for-Text-Analysis/Dicta-Library-Download'
  },
];

const aboutAdditionalSources = <Map<String, String>>[
  {'name': 'אורייתא', 'url': 'https://github.com/MosheWagner/Orayta-Books'},
  {'name': 'ובלכתך בדרך', 'url': 'http://mobile.tora.ws'},
  {
    'name': 'תורת אמת',
    'url': 'http://www.toratemetfreeware.com/index.html?downloads;1;'
  },
  {
    'name': 'אוצר הספרים היהודי',
    'url':
        'https://wiki.jewishbooks.org.il/mediawiki/wiki/%D7%A2%D7%9E%D7%95%D7%93_%D7%A8%D7%90%D7%A9%D7%99'
  },
  {'name': 'ויקיטקסט', 'url': 'https://he.wikisource.org/wiki'},
  {'name': 'תא שמע', 'url': 'https://tashma.co.il/'},
  {'name': 'פנינים', 'url': 'https://pninim.org/'},
  {'name': 'הספרייה הלאומית', 'url': 'https://www.nli.org.il/'},
  {'name': 'פרויקט פרידברג', 'url': 'https://fjms.genizah.org/'},
  {
    'name': 'פרויקט בן יהודה',
    'url': 'https://github.com/projectbenyehuda/public_domain_dump'
  },
];
