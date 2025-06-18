# Путь к скрипту-инсталлеру
$installerPath = Join-Path $PSScriptRoot "zapret-installer.ps1"

# 1. Запуск инсталляции (обновление)
& $installerPath

# 2. Находим папку с самой новой версией
$latestFolder = Get-ChildItem -Path $PSScriptRoot -Directory |
    Where-Object { $_.Name -match '^zapret-(\d+\.\d+\.\d+)$' } |
    Sort-Object { [version]($_.Name -replace '^zapret-', '') } -Descending |
    Select-Object -First 1

if (-not $latestFolder) {
    Write-Warning "❌ Не найдена папка с установленной версией"
    exit
}
$batFolder = $latestFolder.FullName

# 3. Получаем список всех .bat файлов
$batFiles = Get-ChildItem -Path $batFolder -Filter '*.bat' | Sort-Object Name
if (-not $batFiles) {
    Write-Warning "❌ В папке нет .bat файлов"
    exit
}

# 4. Показываем список на выбор
Write-Host "`n📋 Выберите файл для запуска:"
for ($i = 0; $i -lt $batFiles.Count; $i++) {
    Write-Host "[$i] $($batFiles[$i].Name)"
}

# 5. Чтение выбора
do {
    $input = Read-Host "Введите номер (0-$($batFiles.Count - 1))"
    $isValid = $input -match '^\d+$' -and [int]$input -ge 0 -and [int]$input -lt $batFiles.Count
} while (-not $isValid)

$choice = [int]$input


# 6. Запускаем выбранный .bat
$selectedFile = $batFiles[$choice].FullName
Write-Host "`n🚀 Запускаем: $selectedFile"
Start-Process -FilePath $selectedFile -WorkingDirectory $batFolder
