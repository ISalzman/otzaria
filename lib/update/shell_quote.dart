/// עוטף ערך בגרשיים בודדים עבור bash, כולל טיפול בגרש בודד בתוך הערך.
/// משמש את סקריפטי העדכון של macOS ו-Linux לציטוט בטוח של נתיבים.
String shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
