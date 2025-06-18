# zapret-run-auto.ps1
$installerPath = Join-Path $PSScriptRoot "zapret-installer.ps1"
$configPath = Join-Path $PSScriptRoot "zapret-wifi-history.txt"

& $installerPath

$latestFolder = Get-ChildItem -Path $PSScriptRoot -Directory |
    Where-Object { $_.Name -match '^zapret-(\d+\.\d+\.\d+)$' } |
    Sort-Object { [version]($_.Name -replace '^zapret-', '') } -Descending |
    Select-Object -First 1

if (-not $latestFolder) {
    Write-Warning "❌ Не найдена папка с установленной версией"
    exit
}

$batFolder = $latestFolder.FullName
$batFiles = Get-ChildItem -Path $batFolder -Filter '*.bat' | Sort-Object Name

if (-not $batFiles) {
    Write-Warning "❌ В папке нет .bat файлов"
    exit
}

$wifiInfo = netsh wlan show interfaces 2>&1
$ssidLine = $wifiInfo | Select-String -Pattern '^\s*SSID\s*:\s*(.+)$'
$ssid = $ssidLine.Matches.Groups[1].Value.Trim()

if (-not $ssid) {
    Write-Warning "⚠️ Не удалось определить Wi-Fi сеть. Запрашиваю выбор вручную."
    $ssid = "unknown"
} else {
    Write-Host "📶 Текущая Wi-Fi сеть: $ssid"
}

# Читаем только, не сохраняем
$wifiMap = @{}
if (Test-Path $configPath) {
    Get-Content $configPath | ForEach-Object {
        if ($_ -match '^(.+?)=(.+)$') {
            $wifiMap[$matches[1]] = $matches[2]
        }
    }
}

if ($wifiMap.ContainsKey($ssid)) {
    $batName = $wifiMap[$ssid]
    $batToRun = $batFiles | Where-Object { $_.Name -eq $batName }

    if ($batToRun) {
        Write-Host "🚀 Автоматический запуск: $($batToRun.Name)"
        Start-Process -FilePath $batToRun.FullName -WorkingDirectory $batFolder
        exit
    } else {
        Write-Warning "⚠️ Ассоциированный файл '$batName' не найден. Запрашиваю выбор..."
    }
}

# Запрос вручную
Write-Host "`n📋 Выберите файл для запуска:"
for ($i = 0; $i -lt $batFiles.Count; $i++) {
    Write-Host "[$i] $($batFiles[$i].Name)"
}

do {
    $input = Read-Host "Введите номер (0-$($batFiles.Count - 1))"
    $isValid = $input -match '^\d+$' -and [int]$input -ge 0 -and [int]$input -lt $batFiles.Count
} while (-not $isValid)

$selectedFile = $batFiles[[int]$input]
Write-Host "`n🚀 Запускаем: $($selectedFile.Name)"
Start-Process -FilePath $selectedFile.FullName -WorkingDirectory $batFolder
