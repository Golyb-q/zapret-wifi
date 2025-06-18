# Параметры проекта
$Owner = "Flowseal"
$Repo = "zapret-discord-youtube"
$ApiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-LatestRelease {
    Write-Host "🔄 Получаем информацию о последнем релизе..."
    try {
        $json = Invoke-WebRequest -Uri $ApiUrl -UseBasicParsing | ConvertFrom-Json
        return $json
    } catch {
        Write-Warning "❌ Не удалось получить данные с GitHub: $_"
        return $null
    }
}

function Get-ExtractPath($tag) {
    return Join-Path $PSScriptRoot "zapret-$tag"
}

function Download-Zip($asset, $destinationPath) {
    Write-Host "⬇️  Скачиваем архив: $($asset.name)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destinationPath
    Write-Host "✅ Архив загружен"
}

function Extract-Zip($zipPath, $extractPath) {
    Write-Host "📦 Распаковка архива..."
    $shell = New-Object -ComObject shell.application
    $zip = $shell.NameSpace($zipPath)
    $dest = $shell.NameSpace($extractPath)

    if ($zip -and $dest) {
        $dest.CopyHere($zip.Items(), 0x14)
        Write-Host "📂 Распаковано"
        return $true
    } else {
        Write-Warning "❌ Ошибка при распаковке"
        return $false
    }
}

function Cleanup-Zip($zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "🗑 Архив удалён"
}

function Remove-OldVersions($currentTag) {
    Write-Host "🧹 Удаление старых версий..."
    $pattern = "^zapret-(.+)$"
    $folders = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object {
        $_.Name -match $pattern -and $_.Name -ne "zapret-$currentTag"
    }

    while ($true) {
        $svc1 = Get-Service -Name WinDivert -ErrorAction SilentlyContinue
        $svc2 = Get-Service -Name WinDivert14 -ErrorAction SilentlyContinue
        $service_WinDivert = $svc1 -and $svc1.Status -eq 'Running'
        $service_WinDivert14 = $svc2 -and $svc2.Status -eq 'Running'

        if (-not ($service_WinDivert -or $service_WinDivert14)) {
            break  # сервисов нет — выходим из цикла
        }

        Write-Warning "⚠️ Обнаружены активные службы WinDivert или WinDivert14!"
        Write-Host "ℹ️ Пожалуйста, остановите и удалите их через service.bat (выберите пункт 2)."
        Write-Host "🛑 После завершения нажмите Enter для повторной проверки..."
        Start-Process -FilePath "$($folders)\service.bat"
        Read-Host
    }

    foreach ($folder in $folders) {
        try {
            Remove-Item -Path $folder.FullName -Recurse -Force
            Write-Host "🗑 Удалена старая версия: $($folder.Name)"
        } catch {
            Write-Warning "⚠️ Не удалось удалить $($folder.Name): $_"
        }
    }
}

function Main {
    $release = Get-LatestRelease
    if (-not $release) { return }

    $latestTag = $release.tag_name
    Write-Host "🔖 Последняя доступная версия: $latestTag"

    $extractPath = Get-ExtractPath $latestTag
    if (Test-Path $extractPath) {
        Write-Host "✅ Версия $latestTag уже установлена"
        return
    }

    $asset = $release.assets | Where-Object { $_.name -match "\.zip$" }
    if (-not $asset) {
        Write-Warning "❌ Asset (zip) не найден"
        return
    }

    $zipPath = Join-Path $PSScriptRoot $asset.name

    Download-Zip $asset $zipPath
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    if (Extract-Zip $zipPath $extractPath) {
        Cleanup-Zip $zipPath
        Remove-OldVersions $latestTag
    }
}

Main
