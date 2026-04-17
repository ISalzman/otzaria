$targetPaths = @(
    "${env:APPDATA}\אוצריא\אוצריא",
    "${env:APPDATA}\otzaria",
    "${env:LOCALAPPDATA}\otzaria",
    "${env:ProgramData}\otzaria",
    "${env:APPDATA}\com.example"
)

foreach ($targetPath in $targetPaths) {
    if (Test-Path -Path $targetPath) {
        Remove-Item -Path $targetPath -Force -Recurse
        Write-Host "Successfully erased contents of '$targetPath'."
    }
    else {
        Write-Host "Directory '$targetPath' not found. Skipping deletion."
    }
}
