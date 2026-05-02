$targetPaths = @(
    "${env:APPDATA}\אוצריא\אוצריא",
    "${env:APPDATA}\otzaria",
    "${env:LOCALAPPDATA}\otzaria",
    "${env:APPDATA}\com.example"
)

foreach ($targetPath in $targetPaths) {
    if (Test-Path -Path $targetPath) {
        # מחיקת כל התוכן פרט לתיקיית books (שמכילה את מסדי הנתונים)
        Get-ChildItem -Path $targetPath -Force | Where-Object { $_.Name -ine 'books' } | Remove-Item -Force -Recurse
        Write-Host "Erased contents of '$targetPath' (books directory preserved)."
    }
    else {
        Write-Host "Directory '$targetPath' not found. Skipping deletion."
    }
}
