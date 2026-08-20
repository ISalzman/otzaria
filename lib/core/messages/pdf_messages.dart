/// ריכוז הודעות המערכת (UiSnack) של צפיין ה-PDF וההדפסה.
abstract class PdfMessages {
  static const String noCommentariesToPrint = 'אין מפרשים להדפסה';
  static const String directLinkUnavailableForBook =
      'קישור ישיר אינו זמין לספר זה';
  static const String perBookSettingsReset = 'ההגדרות הפר-ספריות אופסו בהצלחה';
  static const String textLocationNotFoundOpeningAtStart =
      'לא נמצא מיקום תואם בטקסט — הספר נפתח מתחילתו';
  static const String searchError = 'שגיאה בחיפוש';
  static const String bookNotInSearchIndex =
      'הספר אינו נמצא באינדקס החיפוש, ולכן חיפוש מתקדם אינו זמין בו. עדכון האינדקס מתבצע בהגדרות הספרייה.';
  static const String pageRangeRenderFailed = 'עיבוד טווח העמודים שנבחר נכשל';
  static const String multiPageSheetRenderFailed =
      'עיבוד עמודים מרובים בגיליון נכשל';
  static const String wordFileSaved = 'קובץ Word נשמר בהצלחה';
  static const String pdfFileSaved = 'קובץ PDF נשמר בהצלחה';
  static const String fileLockedByAnotherApp =
      'לא ניתן לשמור את הקובץ כי הוא פתוח בתוכנה אחרת. יש לסגור אותו ולנסות שוב.';

  static String fileExportFailed(Object error) => 'ייצוא הקובץ נכשל: $error';
}
