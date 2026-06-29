#ifndef RUNNER_JUMP_LIST_MANAGER_H_
#define RUNNER_JUMP_LIST_MANAGER_H_

#include <string>
#include <vector>

namespace jump_list {

// בונה מחדש את קטגוריית "טאבים פתוחים" ב-Jump List של שורת המשימות מתוך
// רשימת כותרות (UTF-8) לפי הסדר. כל פריט מריץ את אוצריא עם
// `otzaria://open/tab/<index>` (0-based). רשימה ריקה מנקה את הקטגוריה.
//
// חובה לקרוא מה-thread של ה-STA — אותו thread שאיתחל COM (ה-UI thread).
// מחזיר true בהצלחה.
bool UpdateOpenTabs(const std::vector<std::string>& titles_utf8);

}  // namespace jump_list

#endif  // RUNNER_JUMP_LIST_MANAGER_H_
