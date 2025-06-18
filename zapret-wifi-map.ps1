# zapret-wifi-map.ps1
$configPath = Join-Path $PSScriptRoot "zapret-wifi-history.txt"

function Load-WifiMap {
    $map = @{}
    if (Test-Path $configPath) {
        Get-Content $configPath | ForEach-Object {
            if ($_ -match '^(.+?)=(.+)$') {
                $map[$matches[1]] = $matches[2]
            }
        }
    }
    return $map
}

function Save-WifiMap($map) {
    $map.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Set-Content $configPath -Encoding UTF8
}

function Get-CurrentSSID {
    $info = netsh wlan show interfaces 2>&1
    $line = $info | Select-String -Pattern '^\s*SSID\s*:\s*(.+)$'
    if ($line -and $line.Matches.Count -gt 0) {
        return $line.Matches[0].Groups[1].Value.Trim()
    } else {
        return $null
    }
}


function Show-Menu {
    Write-Host "`n=== Управление Wi-Fi привязками ==="
    Write-Host "[1] Добавить/обновить привязку"
    Write-Host "[2] Удалить привязку"
    Write-Host "[3] Показать все привязки"
    Write-Host "[0] Выход"
    return Read-Host "Выберите действие"
}

function Select-BatFile($folder) {
    $bats = Get-ChildItem -Path $folder -Filter '*.bat' | Sort-Object Name
    for ($i = 0; $i -lt $bats.Count; $i++) {
        Write-Host "[$i] $($bats[$i].Name)"
    }
    do {
        $input = Read-Host "Введите номер .bat файла"
        $valid = $input -match '^\d+$' -and [int]$input -ge 0 -and [int]$input -lt $bats.Count
    } while (-not $valid)
    return $bats[[int]$input].Name
}

$map = Load-WifiMap
$ssid = Get-CurrentSSID
if (-not $ssid) {
    Write-Warning "Не удалось получить активную сеть wifi. Проверьте подключение"
    $ssid = "unknown"
}

$latestFolder = Get-ChildItem -Path $PSScriptRoot -Directory |
    Where-Object { $_.Name -match '^zapret-(\d+\.\d+\.\d+)$' } |
    Sort-Object { [version]($_.Name -replace '^zapret-', '') } -Descending |
    Select-Object -First 1

if (-not $latestFolder) {
    Write-Warning "❌ Не найдена установленная версия"
    exit
}

$batFolder = $latestFolder.FullName

do {
    $choice = Show-Menu
    switch ($choice) {
        '1' {
            Write-Host "📶 Текущая сеть: $ssid"
            $batName = Select-BatFile $batFolder
            $map[$ssid] = $batName
            Save-WifiMap $map
            Write-Host "✅ Привязка сохранена: $ssid -> $batName"
        }
        '2' {
            if ($map.ContainsKey($ssid)) {
                $map.Remove($ssid)
                Save-WifiMap $map
                Write-Host "❌ Привязка удалена для: $ssid"
            } else {
                Write-Host "ℹ️ Нет привязки для текущей сети"
            }
        }
        '3' {
            Write-Host "`n=== Текущие привязки ==="
            if ($map.Count -eq 0) {
                Write-Host "(пусто)"
            } else {
                $map.GetEnumerator() | Sort-Object Key | ForEach-Object {
                    Write-Host "$($_.Key) -> $($_.Value)"
                }
            }
        }
    }
} while ($choice -ne '0')
