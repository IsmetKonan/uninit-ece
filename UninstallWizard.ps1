#
# Made by Ismet Konan for ece24
# Last Edited 15.10.2026
#

$VERSION     = "1.2.0" 
$DEKO        = "-----------------------------------------------------------------"
$EMPTY_LINE  = "                                                                 "
$Host.UI.RawUI.ForegroundColor = 'Blue'
Write-Host $EMPTY_LINE
Write-Host $DEKO
Write-Host '    ____                    __     __ __'
Write-Host '   /  _/________ ___  ___  / /_   / //_/___  ____  ____ _____'
Write-Host '   / // ___/ __ `__ \/ _ \/ __/  / ,< / __ \/ __ \/ __ `/ __ \ '
Write-Host ' _/ /(__  ) / / / / /  __/ /_   / /| / /_/ / / / / /_/ / / / /'
Write-Host '/___/____/_/ /_/ /_/\___/\__/  /_/ |_\____/_/ /_/\__,_/_/ /_/'
Write-Host $DEKO
Write-Host 'CC Ismet Konan'
Write-Host "$VERSION starting up ..."
Write-Host $DEKO

#
# // check fuer Admin wegen MSIs deinstallieren
# 

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Fehler: Bitte starten sie das Programm als Administrator!" -ForegroundColor Red
    pause
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

## Apps Software targets.
$targets = @(
    @{ Name = 'Firefox'; Pattern = '^Mozilla Firefox'; Kind = 'Registry' }
    @{ Name = 'Google Chrome'; Pattern = '^Google Chrome$'; Kind = 'Registry' }
    @{ Name = '7-Zip'; Pattern = '^7-Zip'; Kind = 'Registry' }
    @{ Name = 'TeamViewer'; Pattern = '^TeamViewer(?:\s|$)'; ExcludePattern = '^TeamViewer Host(?:\s|$)'; Kind = 'Registry' }
    @{ Name = 'PDF-XChange Editor'; Pattern = '^PDF-XChange Editor'; Kind = 'Registry' }
    @{ Name = 'Adobe Reader'; Pattern = '^Adobe Acrobat'; Kind = 'Registry' }
    @{ Name = 'TeamViewer Host'; Pattern = '^TeamViewer Host'; Kind = 'Registry' }
    @{ Name = 'PDF24'; Pattern = '^PDF24'; Kind = 'Registry' }
    @{ Name = 'WireGuard'; Pattern = '^WireGuard'; Kind = 'Registry' }
    @{ Name = 'Nextcloud'; Pattern = '^Nextcloud'; Kind = 'Registry' }
    @{ Name = 'KeePass'; Pattern = '^KeePass 2'; Kind = 'Registry' }
    @{ Name = 'KeePassXC'; Pattern = '^KeePassXC'; Kind = 'Registry' }
    @{ Name = 'DATEV Sicherheitspaket Compact'; Pattern = '^(?:DATEV\s+)?Sicherheitspaket\s+compact(?:\s|$)'; Publisher = '^DATEV(?:\s+eG)?$'; Kind = 'Registry' }
    @{ Name = 'Adobe Express / Photoshop'; Pattern = '^(?:Adobe Express|Adobe Photoshop(?: Express)?)(?:\s|$)'; Kind = 'Registry' }
    @{ Name = 'Adobe Photoshop Express'; PackageName = 'AdobeSystemsIncorporated.AdobePhotoshopExpress'; Kind = 'Appx' }
    @{ Name = 'LibreOffice'; Pattern = '^LibreOffice'; Kind = 'Registry' }
)

$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$installed = @(
    foreach ($path in $registryPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName
            }
    }
)

$items = @(
    foreach ($i in $targets) {
        if ($i.Kind -eq 'Appx') {
            $matchesItem = @(Get-AppxPackage -Name $i.PackageName -ErrorAction Stop)
            foreach ($app in $matchesItem) {
                [PSCustomObject]@{
                    Label    = "$($i.Name) [$($app.Name)]"
                    Name     = $i.Name
                    Target   = $i.Name
                    Entry    = $app
                    Kind     = $i.Kind
                    Selected = $false
                }
            }
            continue
        }

        $matchesItem = @(
            $installed | Where-Object {
                $_.DisplayName -match $i.Pattern -and
                (-not $i.ExcludePattern -or $_.DisplayName -notmatch $i.ExcludePattern) -and
                (-not $i.Publisher -or $_.Publisher -match $i.Publisher)
            }
        )

        if ($i.Name -eq 'DATEV Sicherheitspaket Compact') {
            $preferredDatevUninstallers = @(
                foreach ($entry in $matchesItem) {
                    $uninstallerMatch = [regex]::Match(
                        [string]$entry.QuietUninstallString,
                        '^\s*"([^"]+)"'
                    )
                    if (
                        $uninstallerMatch.Success -and
                        [IO.Path]::GetFileName($uninstallerMatch.Groups[1].Value) -ieq 'SiPacompact.exe' -and
                        (Test-Path -LiteralPath $uninstallerMatch.Groups[1].Value -PathType Leaf)
                    ) {
                        $entry
                    }
                }
            )
            if ($preferredDatevUninstallers.Count -gt 0) {
                $matchesItem = @($preferredDatevUninstallers | Select-Object -First 1)
            }
        }

        foreach ($app in $matchesItem) {
            $hasMsiProductCode = $app.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$'
            $hasKnownUninstallerFallback = $i.Name -in @(
                'Firefox'
                'TeamViewer'
                'TeamViewer Host'
            )

            if (
                -not $app.UninstallString -and
                -not $app.QuietUninstallString -and
                -not $hasMsiProductCode -and
                -not $hasKnownUninstallerFallback
            ) {
                continue
            }

            [PSCustomObject]@{
                Label   = "$($i.Name) [$($app.DisplayName)]"
                Name    = $app.DisplayName
                Target  = $i.Name
                Entry   = $app
                Kind    = $i.Kind
                Selected = $false
            }
        }
    }
)

$publicTeamViewerPath = Join-Path $env:PUBLIC 'Desktop\TeamViewer_ECE.exe'
if (Test-Path -LiteralPath $publicTeamViewerPath -PathType Leaf) {
    $items += [PSCustomObject]@{
        Label    = 'TeamViewer executable [Public Desktop]'
        Name     = 'TeamViewer_ECE.exe (Public Desktop)'
        Target   = 'TeamViewer'
        Entry    = $publicTeamViewerPath
        Kind     = 'DesktopExecutable'
        Selected = $false
    }
}

if ($items.Count -eq 0) {
    Write-Host 'Programme nicht gefunden!' -ForegroundColor Red
    pause > $null
    exit 0
}

#UI
$form = New-Object System.Windows.Forms.Form
$form.Text = 'ece24 - Programme deinstallieren'
$form.Size = New-Object System.Drawing.Size(620, 590)
$form.StartPosition = 'CenterScreen'
$form.MaximizeBox = $false

$list = New-Object System.Windows.Forms.CheckedListBox
$list.Location = New-Object System.Drawing.Point(15, 15)
$list.Size = New-Object System.Drawing.Size(575, 455)
$list.CheckOnClick = $true
$list.HorizontalScrollbar = $true

foreach ($item in $items) {
    [void]$list.Items.Add($item.Label)
}

$form.Controls.Add($list)

$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Location = New-Object System.Drawing.Point(435, 485)
$removeButton.Size = New-Object System.Drawing.Size(155, 32)
$removeButton.Text = 'Deinstallieren'
$removeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($removeButton)

$form.AcceptButton = $removeButton

$result = $form.ShowDialog()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) { # not equal = ok
    exit 0 # stop
    # ui has been closed or been canceled
}

$selected = @(
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($list.GetItemChecked($i)) {
            $items[$i]
        }
    }
)

if ($selected.Count -eq 0) {
    Write-Host 'Nichts ausgewaehlt.' -ForegroundColor Yellow
    pause > $null
    exit 0
}

# Explicit confirmation before making changes
$names = ($selected | ForEach-Object { $_.Name }) -join "`n"
$confirmation = [System.Windows.Forms.MessageBox]::Show(
    "Folgende Programme werden deinstalliert:`n`n$names`n`nFortfahren?",
    'Fortfahren?',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning
)

if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) { # not equal = yes
    exit 0 # stop
}

# uinstall block
foreach ($item in $selected) {
    $app = $item.Entry

    Write-Host $DEKO
    Write-Host "Entferne $($item.Name)..." -ForegroundColor Cyan

    try {
        if ($item.Kind -eq 'Appx') {
            Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
            if (Get-AppxPackage -Name $app.Name -ErrorAction Stop) {
                throw "Adobe-App-Paket $($app.Name) ist nach der Deinstallation noch vorhanden."
            }
            Write-Host "Abgeschlossen: $($app.Name)" -ForegroundColor Green
            continue
        }

        if ($item.Kind -eq 'DesktopExecutable') {
            Remove-Item -LiteralPath $app -Force -ErrorAction Stop
            if (Test-Path -LiteralPath $app) {
                throw "TeamViewer-Datei $app ist nach dem Entfernen noch vorhanden."
            }
            Write-Host "Entfernt: $app" -ForegroundColor Green
            continue
        }

        $command = $app.QuietUninstallString
        if (-not $command) {
            $command = $app.UninstallString
        }

        if (
            $command -match '(?i)\bmsiexec(?:\.exe)?\b' -or
            (-not $command -and $app.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$')
        ) {
            $guid = [regex]::Match(
                $command,
                '\{[0-9A-Fa-f-]{36}\}'
            ).Value

            if (-not $guid) {
                $guid = [regex]::Match(
                    $app.PSChildName,
                    '^\{[0-9A-Fa-f-]{36}\}$'
                ).Value
            }

            if (-not $guid) {
                throw 'MSI-Produktcode nicht gefunden.'
            }

            $proc = Start-Process -FilePath 'msiexec.exe' `
                -ArgumentList "/x $guid /qn /norestart" `
                -Wait -PassThru

        } elseif ($item.Target -eq 'Firefox' -and -not $app.QuietUninstallString) {
            $installLocation = [Environment]::ExpandEnvironmentVariables(
                [string]$app.InstallLocation
            ).Trim('"')
            $candidatePaths = @()

            if ($installLocation) {
                $candidatePaths += Join-Path $installLocation 'uninstall\helper.exe'
            }

            if ($command -match '^\s*"([^"]+helper\.exe)"') {
                $candidatePaths += $Matches[1]
            } elseif ($command -match '^\s*(.+?helper\.exe)(?:\s|$)') {
                $candidatePaths += $Matches[1]
            }

            $knownInstallRoots = @(
                $env:ProgramFiles
                ${env:ProgramFiles(x86)}
                $env:LOCALAPPDATA
            ) | Where-Object { $_ }
            foreach ($root in $knownInstallRoots) {
                $candidatePaths += Join-Path $root 'Mozilla Firefox\uninstall\helper.exe'
            }

            $uninstaller = $candidatePaths |
                Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
                Select-Object -First 1

            if (-not $uninstaller) {
                throw "Firefox helper.exe wurde nicht im Installationsverzeichnis gefunden."
            }

            $proc = Start-Process -FilePath $uninstaller `
                -ArgumentList '/S' -Wait -PassThru

        } elseif ($item.Target -in @('TeamViewer', 'TeamViewer Host') -and -not $app.QuietUninstallString) {
            $installLocation = [Environment]::ExpandEnvironmentVariables(
                [string]$app.InstallLocation
            ).Trim('"')
            $candidatePaths = @()

            if ($command -match '^\s*"([^"]+\.exe)"') {
                $candidatePaths += $Matches[1]
            } elseif ($command -match '^\s*(.+?\.exe)(?:\s|$)') {
                $candidatePaths += $Matches[1]
            }

            if ($installLocation) {
                $candidatePaths += Join-Path $installLocation 'uninstall.exe'
            }

            $programFilesRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
                Where-Object { $_ }
            foreach ($root in $programFilesRoots) {
                if ($item.Target -eq 'TeamViewer Host') {
                    $candidatePaths += Join-Path $root 'TeamViewer Host\uninstall.exe'
                } else {
                    $candidatePaths += Join-Path $root 'TeamViewer\uninstall.exe'
                }
            }

            $uninstaller = $candidatePaths |
                Where-Object {
                    $_ -and
                    (Test-Path -LiteralPath $_ -PathType Leaf) -and
                    [IO.Path]::GetFileName($_) -match '^(?:uninstall|unins\d*)\.exe$'
                } |
                Select-Object -First 1

            if (-not $uninstaller) {
                throw "TeamViewer-Uninstaller wurde im Installationsverzeichnis nicht gefunden."
            }

            $proc = Start-Process -FilePath $uninstaller `
                -ArgumentList '/S' -Wait -PassThru

        } else {
            if (-not $app.QuietUninstallString) {
                throw "Kein verifizierter Silent-Uninstall-Befehl fuer $($app.DisplayName)."
            }

            if ($command -match '^\s*"([^"]+)"\s*(.*)$') {
                $exe = $Matches[1]
                $Arguments = $Matches[2]
            } elseif ($command -match '^\s*(\S+)\s*(.*)$') {
                $exe = $Matches[1]
                $Arguments = $Matches[2]
            } else {
                throw 'Uninstall-Befehl ist nicht Valid.'
            }

            $proc = Start-Process -FilePath $exe `
                -ArgumentList $Arguments -Wait -PassThru
        }

        if ($proc.ExitCode -in @(0, 3010, 1641)) {
            Write-Host "Abgeschlossen: $($app.DisplayName) (ExitCode $($proc.ExitCode))" `
                -ForegroundColor Green
        } else {
            Write-Host "Fehler: $($app.DisplayName), ExitCode $($proc.ExitCode)" `
                -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Fehler bei $($app.DisplayName): $($_.Exception.Message)" `
            -ForegroundColor Red
    }
}

if ($selected | Where-Object { $_.Target -eq 'TeamViewer' }) {
    $desktopPaths = @(
        (Join-Path $env:PUBLIC 'Desktop\TeamViewer_ECE.exe')
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'TeamViewer_ECE.exe')
    ) | Select-Object -Unique

    foreach ($desktopPath in $desktopPaths) {
        if (-not (Test-Path -LiteralPath $desktopPath -PathType Leaf)) {
            continue
        }

        try {
            Remove-Item -LiteralPath $desktopPath -Force -ErrorAction Stop
            Write-Host "Entfernt: $desktopPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler beim Entfernen von $desktopPath`: $($_.Exception.Message)" `
                -ForegroundColor Red
        }
    }
}

if ($selected | Where-Object {
    $_.Target -in @('Adobe Express / Photoshop', 'Adobe Photoshop Express')
}) {
    $desktopPath = Join-Path ([Environment]::GetFolderPath('Desktop')) `
        'Adobe Express Photos.lnk'
    if (Test-Path -LiteralPath $desktopPath -PathType Leaf) {
        try {
            Remove-Item -LiteralPath $desktopPath -Force -ErrorAction Stop
            Write-Host "Entfernt: $desktopPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler beim Entfernen von $desktopPath`: $($_.Exception.Message)" `
                -ForegroundColor Red
        }
    }
}

Write-Host $DEKO
Write-Host 'All Done!' -ForegroundColor Green
Write-Host $DEKO
Write-Host $DEKO
pause > $null