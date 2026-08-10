[CmdletBinding()]
param(
    [switch]$SelfTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = 'ReelArrange'
$script:AppDataDirectory = Join-Path $env:LOCALAPPDATA $script:AppName
$script:SettingsPath = Join-Path $script:AppDataDirectory 'settings.json'
$script:LogPath = Join-Path $script:AppDataDirectory 'activity.log'
$script:VideoExtensions = @('.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.ts', '.m2ts', '.webm', '.mpg', '.mpeg')
$script:SidecarExtensions = @('.srt', '.ass', '.ssa', '.sub', '.idx', '.vtt', '.nfo', '.jpg', '.jpeg', '.png', '.webp')

function Show-ErrorMessage {
    param([string]$Message)
    [void][System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Error')
}

function Show-InfoMessage {
    param([string]$Message)
    [void][System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Information')
}

function Write-ActivityLog {
    param([string]$Message)
    if (-not (Test-Path -LiteralPath $script:AppDataDirectory)) {
        New-Item -ItemType Directory -Path $script:AppDataDirectory -Force | Out-Null
    }
    $line = '{0:u} {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
}

function Get-Settings {
    if (-not (Test-Path -LiteralPath $script:SettingsPath)) {
        return [pscustomobject]@{
            EncryptedTmdbCredential = ''
            MovieRoot = ''
            ShowRoot = ''
        }
    }

    try {
        $settings = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not ($settings.PSObject.Properties.Name -contains 'EncryptedTmdbCredential')) {
            $settings | Add-Member -NotePropertyName EncryptedTmdbCredential -NotePropertyValue ''
        }
        if (-not ($settings.PSObject.Properties.Name -contains 'MovieRoot')) {
            $settings | Add-Member -NotePropertyName MovieRoot -NotePropertyValue ''
        }
        if (-not ($settings.PSObject.Properties.Name -contains 'ShowRoot')) {
            $settings | Add-Member -NotePropertyName ShowRoot -NotePropertyValue ''
        }
        return $settings
    }
    catch {
        throw "The settings file is damaged: $($script:SettingsPath)`r`n`r`n$($_.Exception.Message)"
    }
}

function Save-Settings {
    param([object]$Settings)
    if (-not (Test-Path -LiteralPath $script:AppDataDirectory)) {
        New-Item -ItemType Directory -Path $script:AppDataDirectory -Force | Out-Null
    }
    $Settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}

function Protect-Credential {
    param([string]$Credential)
    $secure = ConvertTo-SecureString -String $Credential -AsPlainText -Force
    return ConvertFrom-SecureString -SecureString $secure
}

function Unprotect-Credential {
    param([string]$EncryptedCredential)
    if ([string]::IsNullOrWhiteSpace($EncryptedCredential)) { return '' }
    $secure = ConvertTo-SecureString -String $EncryptedCredential
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Invoke-TmdbRequest {
    param(
        [string]$Path,
        [hashtable]$Query = @{},
        [string]$Credential
    )

    $queryParts = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $Query.GetEnumerator()) {
        $queryParts.Add(('{0}={1}' -f [uri]::EscapeDataString([string]$entry.Key), [uri]::EscapeDataString([string]$entry.Value)))
    }

    $headers = @{ Accept = 'application/json' }
    if ($Credential -match '^[A-Fa-f0-9]{32}$') {
        $queryParts.Add(('api_key={0}' -f [uri]::EscapeDataString($Credential)))
    }
    else {
        $headers.Authorization = "Bearer $Credential"
    }

    $uri = "https://api.themoviedb.org/3$Path"
    if ($queryParts.Count -gt 0) {
        $uri += '?' + ($queryParts -join '&')
    }

    return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -TimeoutSec 30
}

function Show-CredentialDialog {
    param([object]$Settings)

    while ($true) {
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'TMDB setup'
        $form.Size = New-Object Drawing.Size(610, 265)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false

        $intro = New-Object System.Windows.Forms.Label
        $intro.Location = New-Object Drawing.Point(18, 16)
        $intro.Size = New-Object Drawing.Size(560, 56)
        $intro.Text = "Paste your TMDB API Read Access Token (recommended) or v3 API key.`r`nIt is encrypted for your Windows account and stored only on this PC."
        $form.Controls.Add($intro)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object Drawing.Point(20, 78)
        $textBox.Size = New-Object Drawing.Size(555, 25)
        $textBox.UseSystemPasswordChar = $true
        $form.Controls.Add($textBox)

        $showCheck = New-Object System.Windows.Forms.CheckBox
        $showCheck.Location = New-Object Drawing.Point(20, 108)
        $showCheck.Size = New-Object Drawing.Size(135, 22)
        $showCheck.Text = 'Show credential'
        $showCheck.Add_CheckedChanged({ $textBox.UseSystemPasswordChar = -not $showCheck.Checked })
        $form.Controls.Add($showCheck)

        $link = New-Object System.Windows.Forms.LinkLabel
        $link.Location = New-Object Drawing.Point(355, 109)
        $link.Size = New-Object Drawing.Size(220, 22)
        $link.Text = 'Open TMDB API settings'
        $link.TextAlign = 'TopRight'
        $link.Add_LinkClicked({ Start-Process 'https://www.themoviedb.org/settings/api' })
        $form.Controls.Add($link)

        $saveButton = New-Object System.Windows.Forms.Button
        $saveButton.Location = New-Object Drawing.Point(382, 165)
        $saveButton.Size = New-Object Drawing.Size(92, 30)
        $saveButton.Text = 'Save'
        $saveButton.Add_Click({
            if ([string]::IsNullOrWhiteSpace($textBox.Text)) {
                [void][System.Windows.Forms.MessageBox]::Show('Paste a TMDB token or API key first.', 'TMDB setup', 'OK', 'Warning')
                return
            }
            $form.Tag = $textBox.Text.Trim()
            $form.DialogResult = 'OK'
            $form.Close()
        })
        $form.Controls.Add($saveButton)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object Drawing.Point(483, 165)
        $cancelButton.Size = New-Object Drawing.Size(92, 30)
        $cancelButton.Text = 'Cancel'
        $cancelButton.DialogResult = 'Cancel'
        $form.Controls.Add($cancelButton)
        $form.CancelButton = $cancelButton
        $form.AcceptButton = $saveButton

        $result = $form.ShowDialog()
        if ($result -ne 'OK') { return '' }
        $credential = [string]$form.Tag

        try {
            [void](Invoke-TmdbRequest -Path '/configuration' -Credential $credential)
            $Settings.EncryptedTmdbCredential = Protect-Credential $credential
            Save-Settings $Settings
            return $credential
        }
        catch {
            [void][System.Windows.Forms.MessageBox]::Show("TMDB rejected that credential or could not be reached.`r`n`r`n$($_.Exception.Message)", 'TMDB setup', 'OK', 'Error')
        }
    }
}

function Get-TmdbCredential {
    param([object]$Settings)
    try {
        $credential = Unprotect-Credential $Settings.EncryptedTmdbCredential
    }
    catch {
        $credential = ''
    }

    if (-not [string]::IsNullOrWhiteSpace($credential)) {
        try {
            [void](Invoke-TmdbRequest -Path '/configuration' -Credential $credential)
            return $credential
        }
        catch {
            $answer = [System.Windows.Forms.MessageBox]::Show("The saved TMDB credential no longer works. Replace it now?", 'TMDB setup', 'YesNo', 'Warning')
            if ($answer -ne 'Yes') { return '' }
        }
    }

    return Show-CredentialDialog $Settings
}

function Get-SafeName {
    param([string]$Name)
    $safe = $Name -replace '[<>:"/\\|?*]', '-'
    $safe = $safe -replace '\s+', ' '
    $safe = $safe.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'Untitled' }
    return $safe
}

function Get-SearchSeed {
    param([string]$Name, [ValidateSet('movie', 'tv')][string]$MediaType)
    $leafName = [IO.Path]::GetFileName($Name)
    $extension = [IO.Path]::GetExtension($leafName).ToLowerInvariant()
    $seed = if ($script:VideoExtensions -contains $extension) { [IO.Path]::GetFileNameWithoutExtension($leafName) } else { $leafName }
    $yearMatch = [regex]::Match($seed, '(?<!\d)((?:19|20)\d{2})(?!\d)')
    $year = ''
    if ($yearMatch.Success) { $year = $yearMatch.Value }
    $seed = $seed -replace '\[[^\]]+\]|\{[^}]+\}', ' '
    if ($MediaType -eq 'tv') {
        $seed = $seed -replace '(?i)\bS\d{1,2}[ ._-]*E\d{1,3}.*$', ' '
        $seed = $seed -replace '(?i)\b\d{1,2}x\d{1,3}.*$', ' '
    }
    $seed = $seed -replace '(?i)\b(2160p|1080p|720p|480p|4k|uhd|hdr10\+?|dv|dolby[ ._-]*vision|bluray|blu-ray|bdrip|brrip|webrip|web-dl|webdl|hdtv|remux|x264|x265|h[ ._-]*264|h[ ._-]*265|hevc|av1|aac|dts|atmos|proper|repack)\b.*$', ' '
    $seed = $seed -replace '(?<!\d)((?:19|20)\d{2})(?!\d).*$', ' '
    $seed = $seed -replace '[._-]+', ' '
    $seed = $seed -replace '\s+', ' '
    return [pscustomobject]@{ Query = $seed.Trim(); Year = $year }
}

function Show-MediaTypeDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $script:AppName
    $form.Size = New-Object Drawing.Size(440, 205)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(22, 20)
    $label.Size = New-Object Drawing.Size(380, 35)
    $label.Text = 'What are you preparing for Jellyfin?'
    $label.Font = New-Object Drawing.Font($label.Font, [Drawing.FontStyle]::Bold)
    $form.Controls.Add($label)

    $movie = New-Object System.Windows.Forms.Button
    $movie.Location = New-Object Drawing.Point(25, 70)
    $movie.Size = New-Object Drawing.Size(175, 48)
    $movie.Text = 'Movie'
    $movie.Add_Click({ $form.Tag = 'movie'; $form.DialogResult = 'OK'; $form.Close() })
    $form.Controls.Add($movie)

    $show = New-Object System.Windows.Forms.Button
    $show.Location = New-Object Drawing.Point(220, 70)
    $show.Size = New-Object Drawing.Size(175, 48)
    $show.Text = 'TV show'
    $show.Add_Click({ $form.Tag = 'tv'; $form.DialogResult = 'OK'; $form.Close() })
    $form.Controls.Add($show)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Location = New-Object Drawing.Point(305, 130)
    $cancel.Size = New-Object Drawing.Size(90, 28)
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne 'OK') { return '' }
    return [string]$form.Tag
}

function Get-CanonicalExtraFolder {
    param([string]$Name)
    $key = ($Name.ToLowerInvariant() -replace '[^a-z0-9]', '')
    switch ($key) {
        'behindthescenes' { return 'behind the scenes' }
        'deletedscenes'   { return 'deleted scenes' }
        'interviews'      { return 'interviews' }
        'scenes'          { return 'scenes' }
        'samples'         { return 'samples' }
        'shorts'          { return 'shorts' }
        'featurettes'     { return 'featurettes' }
        'clips'           { return 'clips' }
        'other'           { return 'other' }
        'extras'          { return 'extras' }
        'trailers'        { return 'trailers' }
        'thememusic'      { return 'theme-music' }
        'backdrops'       { return 'backdrops' }
        default           { return '' }
    }
}

function Test-IsLooseExtra {
    param([IO.FileInfo]$File)
    return $File.BaseName -match '(?i)([-._ ](?:trailer|sample|scene|clip|interview|behindthescenes|deleted|deletedscene|featurette|short|other|extra))$'
}

function Test-IsInExtraFolder {
    param([IO.FileInfo]$File, [string]$SourceRoot)
    $current = $File.Directory
    $rootFull = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    while ($null -ne $current -and $current.FullName.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        if (-not [string]::IsNullOrWhiteSpace((Get-CanonicalExtraFolder $current.Name))) { return $true }
        if ($current.FullName.TrimEnd('\') -eq $rootFull) { break }
        $current = $current.Parent
    }
    return $false
}

function Select-MediaSource {
    param([ValidateSet('movie', 'tv')][string]$MediaType)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = if ($MediaType -eq 'movie') { 'Select movie source' } else { 'Select TV source' }
    $form.Size = New-Object Drawing.Size(455, 220)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(20, 18)
    $label.Size = New-Object Drawing.Size(400, 45)
    $label.Text = if ($MediaType -eq 'movie') {
        'Choose a movie file, or its complete folder to include extras, artwork, and sidecars.'
    } else {
        'Choose one or more episode files, or a complete show/season folder including extras.'
    }
    $form.Controls.Add($label)

    $filesButton = New-Object System.Windows.Forms.Button
    $filesButton.Location = New-Object Drawing.Point(25, 78)
    $filesButton.Size = New-Object Drawing.Size(185, 48)
    $filesButton.Text = if ($MediaType -eq 'movie') { 'Choose movie file' } else { 'Choose episode files' }
    $filesButton.Add_Click({ $form.Tag = 'files'; $form.DialogResult = 'OK'; $form.Close() })
    $form.Controls.Add($filesButton)

    $folderButton = New-Object System.Windows.Forms.Button
    $folderButton.Location = New-Object Drawing.Point(230, 78)
    $folderButton.Size = New-Object Drawing.Size(185, 48)
    $folderButton.Text = if ($MediaType -eq 'movie') { 'Choose movie folder' } else { 'Choose show folder' }
    $folderButton.Add_Click({ $form.Tag = 'folder'; $form.DialogResult = 'OK'; $form.Close() })
    $form.Controls.Add($folderButton)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Location = New-Object Drawing.Point(325, 140)
    $cancel.Size = New-Object Drawing.Size(90, 28)
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne 'OK') { return $null }
    if ([string]$form.Tag -eq 'files') {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = if ($MediaType -eq 'movie') { 'Select the movie video file' } else { 'Select TV episode files' }
        $dialog.Filter = 'Video files|*.mkv;*.mp4;*.avi;*.m4v;*.mov;*.wmv;*.ts;*.m2ts;*.webm;*.mpg;*.mpeg|All files|*.*'
        $dialog.Multiselect = ($MediaType -eq 'tv')
        if ($dialog.ShowDialog() -ne 'OK') { return $null }
        $selectedFiles = @($dialog.FileNames | ForEach-Object { Get-Item -LiteralPath $_ })
        $includeFolderContent = $false
        if ($MediaType -eq 'movie') {
            $movieParent = $selectedFiles[0].DirectoryName
            $extraFolders = @(Get-ChildItem -LiteralPath $movieParent -Directory | Where-Object {
                -not [string]::IsNullOrWhiteSpace((Get-CanonicalExtraFolder $_.Name))
            })
            $looseExtras = @(Get-ChildItem -LiteralPath $movieParent -File | Where-Object { Test-IsLooseExtra $_ })
            if ($extraFolders.Count -gt 0 -or $looseExtras.Count -gt 0) {
                $extraNames = @($extraFolders | ForEach-Object { Get-CanonicalExtraFolder $_.Name } | Sort-Object -Unique)
                if ($looseExtras.Count -gt 0) { $extraNames += 'loose extra files' }
                $answer = [System.Windows.Forms.MessageBox]::Show(
                    "Recognized Jellyfin extras were found beside this movie:`r`n`r`n$($extraNames -join ', ')`r`n`r`nInclude them with the movie?",
                    'Include movie extras',
                    'YesNo',
                    'Question'
                )
                $includeFolderContent = ($answer -eq 'Yes')
            }
        }
        return [pscustomobject]@{
            Videos = $selectedFiles
            SourceRoot = $selectedFiles[0].DirectoryName
            IsFolder = $includeFolderContent
            SearchName = $selectedFiles[0].Name
        }
    }

    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = if ($MediaType -eq 'movie') { 'Select the downloaded movie folder' } else { 'Select the downloaded TV show or season folder' }
    $folderDialog.ShowNewFolderButton = $false
    if ($folderDialog.ShowDialog() -ne 'OK') { return $null }
    $sourceRoot = $folderDialog.SelectedPath
    if ($MediaType -eq 'movie') {
        $selectedFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object {
            ($script:VideoExtensions -contains $_.Extension.ToLowerInvariant()) -and -not (Test-IsLooseExtra $_)
        })
        if ($selectedFiles.Count -eq 0) {
            $candidateFolders = @(Get-ChildItem -LiteralPath $sourceRoot -Directory | Where-Object {
                [string]::IsNullOrWhiteSpace((Get-CanonicalExtraFolder $_.Name))
            } | ForEach-Object {
                $candidateVideos = @(Get-ChildItem -LiteralPath $_.FullName -File | Where-Object {
                    ($script:VideoExtensions -contains $_.Extension.ToLowerInvariant()) -and -not (Test-IsLooseExtra $_)
                })
                if ($candidateVideos.Count -gt 0) {
                    [pscustomobject]@{ Folder = $_.FullName; Videos = $candidateVideos }
                }
            })
            if ($candidateFolders.Count -eq 1) {
                $sourceRoot = $candidateFolders[0].Folder
                $selectedFiles = @($candidateFolders[0].Videos)
            }
        }
    }
    else {
        $selectedFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | Where-Object {
            ($script:VideoExtensions -contains $_.Extension.ToLowerInvariant()) -and
            -not (Test-IsInExtraFolder -File $_ -SourceRoot $sourceRoot) -and
            -not (Test-IsLooseExtra $_)
        })
    }
    $searchName = Split-Path -Leaf $sourceRoot
    if ($MediaType -eq 'tv' -and $searchName -match '(?i)^(?:Season[ ._-]*|S)\d{1,2}$') {
        $searchName = Split-Path -Leaf (Split-Path -Parent $sourceRoot)
    }
    return [pscustomobject]@{
        Videos = $selectedFiles
        SourceRoot = $sourceRoot
        IsFolder = $true
        SearchName = $searchName
    }
}

function Select-TmdbMatch {
    param(
        [ValidateSet('movie', 'tv')][string]$MediaType,
        [string]$InitialQuery,
        [string]$InitialYear,
        [string]$Credential
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Choose the TMDB match'
    $form.Size = New-Object Drawing.Size(780, 535)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object Drawing.Size(650, 450)

    $queryLabel = New-Object System.Windows.Forms.Label
    $queryLabel.Location = New-Object Drawing.Point(15, 17)
    $queryLabel.Size = New-Object Drawing.Size(60, 22)
    $queryLabel.Text = 'Search:'
    $form.Controls.Add($queryLabel)

    $queryBox = New-Object System.Windows.Forms.TextBox
    $queryBox.Location = New-Object Drawing.Point(75, 14)
    $queryBox.Size = New-Object Drawing.Size(485, 25)
    $queryBox.Text = $InitialQuery
    $form.Controls.Add($queryBox)

    $yearBox = New-Object System.Windows.Forms.TextBox
    $yearBox.Location = New-Object Drawing.Point(568, 14)
    $yearBox.Size = New-Object Drawing.Size(72, 25)
    $yearBox.Text = $InitialYear
    $form.Controls.Add($yearBox)

    $searchButton = New-Object System.Windows.Forms.Button
    $searchButton.Location = New-Object Drawing.Point(650, 12)
    $searchButton.Size = New-Object Drawing.Size(95, 29)
    $searchButton.Text = 'Search'
    $form.Controls.Add($searchButton)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(15, 53)
    $list.Size = New-Object Drawing.Size(730, 335)
    $list.Anchor = 'Top, Bottom, Left, Right'
    $list.HorizontalScrollbar = $true
    $list.DisplayMember = 'Display'
    $form.Controls.Add($list)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Location = New-Object Drawing.Point(15, 400)
    $hint.Size = New-Object Drawing.Size(510, 52)
    $hint.Anchor = 'Bottom, Left, Right'
    $hint.Text = 'Check the title, year, and description. Double-click a result to select it.'
    $form.Controls.Add($hint)

    $selectButton = New-Object System.Windows.Forms.Button
    $selectButton.Location = New-Object Drawing.Point(545, 430)
    $selectButton.Size = New-Object Drawing.Size(95, 32)
    $selectButton.Anchor = 'Bottom, Right'
    $selectButton.Text = 'Use match'
    $form.Controls.Add($selectButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object Drawing.Point(650, 430)
    $cancelButton.Size = New-Object Drawing.Size(95, 32)
    $cancelButton.Anchor = 'Bottom, Right'
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = 'Cancel'
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $performSearch = {
        if ([string]::IsNullOrWhiteSpace($queryBox.Text)) { return }
        try {
            $searchButton.Enabled = $false
            $list.Items.Clear()
            $query = @{ query = $queryBox.Text.Trim(); include_adult = 'false'; language = 'en-US'; page = '1' }
            if ($yearBox.Text -match '^\d{4}$') {
                if ($MediaType -eq 'movie') { $query.year = $yearBox.Text } else { $query.first_air_date_year = $yearBox.Text }
            }
            $response = Invoke-TmdbRequest -Path "/search/$MediaType" -Query $query -Credential $Credential
            foreach ($item in @($response.results | Select-Object -First 15)) {
                if ($MediaType -eq 'movie') {
                    $title = [string]$item.title
                    $date = [string]$item.release_date
                }
                else {
                    $title = [string]$item.name
                    $date = [string]$item.first_air_date
                }
                $year = if ($date -match '^\d{4}') { $date.Substring(0, 4) } else { 'year unknown' }
                $overview = ([string]$item.overview -replace '\s+', ' ').Trim()
                if ($overview.Length -gt 145) { $overview = $overview.Substring(0, 142) + '...' }
                $display = '{0} ({1})  [TMDB {2}]' -f $title, $year, $item.id
                if (-not [string]::IsNullOrWhiteSpace($overview)) { $display += " - $overview" }
                [void]$list.Items.Add([pscustomobject]@{ Display = $display; Item = $item; Title = $title; Year = $year })
            }
            if ($list.Items.Count -eq 0) {
                [void][System.Windows.Forms.MessageBox]::Show('No matches found. Change the search text or remove the year.', 'TMDB search', 'OK', 'Information')
            }
            else {
                $list.SelectedIndex = 0
            }
        }
        catch {
            [void][System.Windows.Forms.MessageBox]::Show("TMDB search failed.`r`n`r`n$($_.Exception.Message)", 'TMDB search', 'OK', 'Error')
        }
        finally {
            $searchButton.Enabled = $true
        }
    }

    $choose = {
        if ($null -eq $list.SelectedItem) { return }
        $form.Tag = $list.SelectedItem
        $form.DialogResult = 'OK'
        $form.Close()
    }
    $searchButton.Add_Click($performSearch)
    $queryBox.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { & $performSearch; $_.SuppressKeyPress = $true } })
    $list.Add_DoubleClick($choose)
    $selectButton.Add_Click($choose)
    $form.Add_Shown($performSearch)

    if ($form.ShowDialog() -ne 'OK') { return $null }
    return $form.Tag
}

function Get-EpisodeInfo {
    param([string]$FileName)
    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $match = [regex]::Match($base, '(?i)(?:^|[^A-Z0-9])S(?<season>\d{1,2})[ ._-]*E(?<episode>\d{1,3})(?:[ ._-]*(?:E|-E?)(?<episode2>\d{1,3}))?')
    if (-not $match.Success) {
        $match = [regex]::Match($base, '(?i)(?:^|[^A-Z0-9])(?<season>\d{1,2})x(?<episode>\d{1,3})(?:-(?<episode2>\d{1,3}))?')
    }
    if (-not $match.Success) { return $null }
    $last = [int]$match.Groups['episode'].Value
    if ($match.Groups['episode2'].Success) { $last = [int]$match.Groups['episode2'].Value }
    return [pscustomobject]@{
        Season = [int]$match.Groups['season'].Value
        Episode = [int]$match.Groups['episode'].Value
        LastEpisode = $last
    }
}

function Show-EpisodeNumberDialog {
    param([string]$FileName)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Episode number needed'
    $form.Size = New-Object Drawing.Size(475, 245)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(18, 15)
    $label.Size = New-Object Drawing.Size(420, 55)
    $label.Text = "I could not find SxxEyy in:`r`n$FileName`r`nEnter the season and episode."
    $form.Controls.Add($label)

    $seasonLabel = New-Object System.Windows.Forms.Label
    $seasonLabel.Location = New-Object Drawing.Point(22, 83)
    $seasonLabel.Size = New-Object Drawing.Size(65, 22)
    $seasonLabel.Text = 'Season:'
    $form.Controls.Add($seasonLabel)
    $season = New-Object System.Windows.Forms.NumericUpDown
    $season.Location = New-Object Drawing.Point(90, 80)
    $season.Size = New-Object Drawing.Size(75, 25)
    $season.Minimum = 0
    $season.Maximum = 99
    $season.Value = 1
    $form.Controls.Add($season)

    $episodeLabel = New-Object System.Windows.Forms.Label
    $episodeLabel.Location = New-Object Drawing.Point(205, 83)
    $episodeLabel.Size = New-Object Drawing.Size(68, 22)
    $episodeLabel.Text = 'Episode:'
    $form.Controls.Add($episodeLabel)
    $episode = New-Object System.Windows.Forms.NumericUpDown
    $episode.Location = New-Object Drawing.Point(278, 80)
    $episode.Size = New-Object Drawing.Size(75, 25)
    $episode.Minimum = 1
    $episode.Maximum = 999
    $episode.Value = 1
    $form.Controls.Add($episode)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Location = New-Object Drawing.Point(260, 140)
    $ok.Size = New-Object Drawing.Size(85, 30)
    $ok.Text = 'Continue'
    $ok.Add_Click({
        $form.Tag = [pscustomobject]@{ Season = [int]$season.Value; Episode = [int]$episode.Value; LastEpisode = [int]$episode.Value }
        $form.DialogResult = 'OK'
        $form.Close()
    })
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Location = New-Object Drawing.Point(353, 140)
    $cancel.Size = New-Object Drawing.Size(85, 30)
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne 'OK') { return $null }
    return $form.Tag
}

function Select-Operation {
    param(
        [string]$SuggestedRoot,
        [string]$Preview,
        [ValidateSet('movie', 'tv')][string]$MediaType
    )
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Confirm Jellyfin destination'
    $form.Size = New-Object Drawing.Size(720, 535)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $rootLabel = New-Object System.Windows.Forms.Label
    $rootLabel.Location = New-Object Drawing.Point(18, 18)
    $rootLabel.Size = New-Object Drawing.Size(650, 22)
    $rootLabel.Text = if ($MediaType -eq 'movie') { 'Jellyfin Movies library folder:' } else { 'Jellyfin Shows library folder:' }
    $form.Controls.Add($rootLabel)

    $rootBox = New-Object System.Windows.Forms.TextBox
    $rootBox.Location = New-Object Drawing.Point(20, 43)
    $rootBox.Size = New-Object Drawing.Size(560, 25)
    $rootBox.Text = $SuggestedRoot
    $form.Controls.Add($rootBox)

    $browse = New-Object System.Windows.Forms.Button
    $browse.Location = New-Object Drawing.Point(590, 41)
    $browse.Size = New-Object Drawing.Size(95, 29)
    $browse.Text = 'Browse...'
    $browse.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $rootLabel.Text
        if (-not [string]::IsNullOrWhiteSpace($rootBox.Text) -and (Test-Path -LiteralPath $rootBox.Text -PathType Container)) {
            $dialog.SelectedPath = $rootBox.Text
        }
        if ($dialog.ShowDialog() -eq 'OK') { $rootBox.Text = $dialog.SelectedPath }
    })
    $form.Controls.Add($browse)

    $operationLabel = New-Object System.Windows.Forms.Label
    $operationLabel.Location = New-Object Drawing.Point(18, 84)
    $operationLabel.Size = New-Object Drawing.Size(95, 22)
    $operationLabel.Text = 'Operation:'
    $form.Controls.Add($operationLabel)

    $operation = New-Object System.Windows.Forms.ComboBox
    $operation.Location = New-Object Drawing.Point(110, 81)
    $operation.Size = New-Object Drawing.Size(350, 25)
    $operation.DropDownStyle = 'DropDownList'
    [void]$operation.Items.Add('Copy (recommended; keeps torrent seeding)')
    [void]$operation.Items.Add('Move (stops seeding from the old location)')
    $operation.SelectedIndex = 0
    $form.Controls.Add($operation)

    $collisionLabel = New-Object System.Windows.Forms.Label
    $collisionLabel.Location = New-Object Drawing.Point(18, 122)
    $collisionLabel.Size = New-Object Drawing.Size(95, 22)
    $collisionLabel.Text = 'If file exists:'
    $form.Controls.Add($collisionLabel)

    $collisionPolicy = New-Object System.Windows.Forms.ComboBox
    $collisionPolicy.Location = New-Object Drawing.Point(110, 119)
    $collisionPolicy.Size = New-Object Drawing.Size(350, 25)
    $collisionPolicy.DropDownStyle = 'DropDownList'
    [void]$collisionPolicy.Items.Add('Add missing files; keep existing media (recommended)')
    [void]$collisionPolicy.Items.Add('Stop if any destination file exists')
    [void]$collisionPolicy.Items.Add('Overwrite existing files')
    $collisionPolicy.SelectedIndex = 0
    $form.Controls.Add($collisionPolicy)

    $previewLabel = New-Object System.Windows.Forms.Label
    $previewLabel.Location = New-Object Drawing.Point(18, 161)
    $previewLabel.Size = New-Object Drawing.Size(650, 22)
    $previewLabel.Text = 'Planned Jellyfin structure:'
    $form.Controls.Add($previewLabel)

    $previewBox = New-Object System.Windows.Forms.TextBox
    $previewBox.Location = New-Object Drawing.Point(20, 185)
    $previewBox.Size = New-Object Drawing.Size(665, 220)
    $previewBox.Multiline = $true
    $previewBox.ReadOnly = $true
    $previewBox.ScrollBars = 'Both'
    $previewBox.WordWrap = $false
    $previewBox.Text = $Preview
    $form.Controls.Add($previewBox)

    $run = New-Object System.Windows.Forms.Button
    $run.Location = New-Object Drawing.Point(480, 425)
    $run.Size = New-Object Drawing.Size(100, 34)
    $run.Text = 'Start'
    $run.Add_Click({
        if ([string]::IsNullOrWhiteSpace($rootBox.Text) -or -not (Test-Path -LiteralPath $rootBox.Text -PathType Container)) {
            [void][System.Windows.Forms.MessageBox]::Show('Choose an existing Jellyfin library folder. UNC network paths are supported.', 'Destination', 'OK', 'Warning')
            return
        }
        if ($operation.SelectedIndex -eq 1) {
            $answer = [System.Windows.Forms.MessageBox]::Show('Move removes the selected media from its download location and may stop the torrent from seeding. Continue?', 'Confirm move', 'YesNo', 'Warning')
            if ($answer -ne 'Yes') { return }
        }
        $mode = if ($operation.SelectedIndex -eq 0) { 'Copy' } else { 'Move' }
        $selectedCollisionPolicy = switch ($collisionPolicy.SelectedIndex) {
            0 { 'Skip' }
            1 { 'Stop' }
            2 { 'Overwrite' }
            default { 'Skip' }
        }
        $form.Tag = [pscustomobject]@{ Root = $rootBox.Text.Trim(); Mode = $mode; CollisionPolicy = $selectedCollisionPolicy }
        $form.DialogResult = 'OK'
        $form.Close()
    })
    $form.Controls.Add($run)
    $form.AcceptButton = $run

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Location = New-Object Drawing.Point(590, 425)
    $cancel.Size = New-Object Drawing.Size(95, 34)
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne 'OK') { return $null }
    return $form.Tag
}

function Get-AssociatedSidecars {
    param([IO.FileInfo]$Video)
    $prefix = $Video.BaseName
    return @(Get-ChildItem -LiteralPath $Video.DirectoryName -File | Where-Object {
        ($script:SidecarExtensions -contains $_.Extension.ToLowerInvariant()) -and
        (($_.BaseName -eq $prefix) -or $_.Name.StartsWith($prefix + '.', [StringComparison]::OrdinalIgnoreCase) -or $_.Name.StartsWith($prefix + '-', [StringComparison]::OrdinalIgnoreCase))
    })
}

function Get-SidecarTargetName {
    param([IO.FileInfo]$Sidecar, [IO.FileInfo]$Video, [string]$TargetVideoBase)
    $suffix = $Sidecar.Name.Substring($Video.BaseName.Length)
    return $TargetVideoBase + $suffix
}

function Initialize-NativeFileTransfer {
    if ($null -ne ('ReelArrange.NativeFileTransfer' -as [type])) { return }

    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

namespace ReelArrange
{
    public static class NativeFileTransfer
    {
        private enum ProgressResult : uint
        {
            Continue = 0,
            Cancel = 1,
            Stop = 2,
            Quiet = 3
        }

        private enum ProgressReason : uint
        {
            ChunkFinished = 0,
            StreamSwitch = 1
        }

        [Flags]
        private enum CopyFlags : uint
        {
            None = 0,
            FailIfExists = 0x00000001
        }

        [Flags]
        private enum MoveFlags : uint
        {
            ReplaceExisting = 0x00000001,
            CopyAllowed = 0x00000002,
            WriteThrough = 0x00000008
        }

        [UnmanagedFunctionPointer(CallingConvention.Winapi)]
        private delegate ProgressResult ProgressRoutine(
            long totalFileSize,
            long totalBytesTransferred,
            long streamSize,
            long streamBytesTransferred,
            uint streamNumber,
            ProgressReason callbackReason,
            IntPtr sourceFile,
            IntPtr destinationFile,
            IntPtr data
        );

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CopyFileEx(
            string existingFileName,
            string newFileName,
            ProgressRoutine progressRoutine,
            IntPtr data,
            ref bool cancel,
            CopyFlags copyFlags
        );

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool MoveFileWithProgress(
            string existingFileName,
            string newFileName,
            ProgressRoutine progressRoutine,
            IntPtr data,
            MoveFlags moveFlags
        );

        private static string NativePath(string path)
        {
            string fullPath = Path.GetFullPath(path);
            if (fullPath.StartsWith(@"\\?\")) return fullPath;
            if (fullPath.Length < 248) return fullPath;
            if (fullPath.StartsWith(@"\\")) return @"\\?\UNC\" + fullPath.Substring(2);
            return @"\\?\" + fullPath;
        }

        private static ProgressRoutine CreateProgressRoutine(Action<long, long> progress)
        {
            return delegate(
                long totalFileSize,
                long totalBytesTransferred,
                long streamSize,
                long streamBytesTransferred,
                uint streamNumber,
                ProgressReason callbackReason,
                IntPtr sourceFile,
                IntPtr destinationFile,
                IntPtr data)
            {
                if (progress != null) progress(totalBytesTransferred, totalFileSize);
                return ProgressResult.Continue;
            };
        }

        public static void Copy(string source, string destination, bool overwrite, Action<long, long> progress)
        {
            bool cancel = false;
            ProgressRoutine routine = CreateProgressRoutine(progress);
            CopyFlags flags = overwrite ? CopyFlags.None : CopyFlags.FailIfExists;
            if (!CopyFileEx(NativePath(source), NativePath(destination), routine, IntPtr.Zero, ref cancel, flags))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Unable to copy " + source);
            }
        }

        public static void Move(string source, string destination, bool overwrite, Action<long, long> progress)
        {
            ProgressRoutine routine = CreateProgressRoutine(progress);
            MoveFlags flags = MoveFlags.CopyAllowed | MoveFlags.WriteThrough;
            if (overwrite) flags |= MoveFlags.ReplaceExisting;
            if (!MoveFileWithProgress(NativePath(source), NativePath(destination), routine, IntPtr.Zero, flags))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Unable to move " + source);
            }
        }
    }
}
'@
}

function Format-TransferSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N1} KB' -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

function New-TransferProgressWindow {
    param([ValidateSet('Copy', 'Move')][string]$Mode, [int]$FileCount)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'ReelArrange - Transfer status'
    $form.Size = New-Object Drawing.Size(640, 270)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ControlBox = $false

    $header = New-Object System.Windows.Forms.Label
    $header.Location = New-Object Drawing.Point(22, 18)
    $header.Size = New-Object Drawing.Size(580, 24)
    $header.Font = New-Object Drawing.Font($header.Font, [Drawing.FontStyle]::Bold)
    $header.Text = "$Mode preparing..."
    $form.Controls.Add($header)

    $currentFile = New-Object System.Windows.Forms.Label
    $currentFile.Location = New-Object Drawing.Point(22, 50)
    $currentFile.Size = New-Object Drawing.Size(580, 38)
    $currentFile.AutoEllipsis = $true
    $form.Controls.Add($currentFile)

    $sizeStatus = New-Object System.Windows.Forms.Label
    $sizeStatus.Location = New-Object Drawing.Point(22, 91)
    $sizeStatus.Size = New-Object Drawing.Size(580, 22)
    $form.Controls.Add($sizeStatus)

    $fileProgress = New-Object System.Windows.Forms.ProgressBar
    $fileProgress.Location = New-Object Drawing.Point(22, 116)
    $fileProgress.Size = New-Object Drawing.Size(580, 24)
    $fileProgress.Minimum = 0
    $fileProgress.Maximum = 100
    $form.Controls.Add($fileProgress)

    $overallLabel = New-Object System.Windows.Forms.Label
    $overallLabel.Location = New-Object Drawing.Point(22, 155)
    $overallLabel.Size = New-Object Drawing.Size(580, 22)
    $overallLabel.Text = "Overall: 0 of $FileCount files complete"
    $form.Controls.Add($overallLabel)

    $overallProgress = New-Object System.Windows.Forms.ProgressBar
    $overallProgress.Location = New-Object Drawing.Point(22, 180)
    $overallProgress.Size = New-Object Drawing.Size(580, 24)
    $overallProgress.Minimum = 0
    $overallProgress.Maximum = [math]::Max(1, $FileCount)
    $form.Controls.Add($overallProgress)

    return [pscustomobject]@{
        Form = $form
        Header = $header
        CurrentFile = $currentFile
        SizeStatus = $sizeStatus
        FileProgress = $fileProgress
        OverallLabel = $overallLabel
        OverallProgress = $overallProgress
    }
}

function Invoke-TransferPlan {
    param(
        [object[]]$Plan,
        [ValidateSet('Copy', 'Move')][string]$Mode,
        [ValidateSet('Stop', 'Skip', 'Overwrite')][string]$CollisionPolicy = 'Stop',
        [bool]$ShowProgress = $true
    )

    $duplicates = $Plan | Group-Object -Property Target | Where-Object { $_.Count -gt 1 }
    if ($duplicates) {
        $paths = ($duplicates | ForEach-Object { $_.Name }) -join "`r`n"
        throw "Two selected files would use the same destination. Nothing was changed.`r`n`r`n$paths"
    }

    $existing = @($Plan | Where-Object { Test-Path -LiteralPath $_.Target })
    if ($existing.Count -gt 0 -and $CollisionPolicy -eq 'Stop') {
        $paths = ($existing | Select-Object -First 12 | ForEach-Object { $_.Target }) -join "`r`n"
        throw "Destination files already exist. Nothing was changed.`r`n`r`n$paths`r`n`r`nRun again and choose Skip or Overwrite if that is intentional."
    }

    if ($existing.Count -gt 0 -and $CollisionPolicy -eq 'Overwrite') {
        $paths = ($existing | Select-Object -First 10 | ForEach-Object { $_.Target }) -join "`r`n"
        $moreText = if ($existing.Count -gt 10) { "`r`n...and $($existing.Count - 10) more" } else { '' }
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Overwrite $($existing.Count) existing destination file(s)?`r`n`r`nMissing extras and other new files will be transferred first. Large existing movies are replaced afterward and may take several minutes.`r`n`r`nThe replaced files cannot be recovered by this tool.`r`n`r`n$paths$moreText",
            'Confirm overwrite',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return [pscustomobject]@{ Completed = 0; Skipped = 0; Overwritten = 0; Cancelled = $true }
        }
    }

    $missingItems = @($Plan | Where-Object { -not (Test-Path -LiteralPath $_.Target) })
    $itemsToTransfer = @(switch ($CollisionPolicy) {
        'Skip' { @($missingItems) }
        'Overwrite' { @($missingItems) + @($existing) }
        default { @($Plan) }
    })
    $completed = 0
    $progress = $null
    if ($itemsToTransfer.Count -gt 0) {
        Initialize-NativeFileTransfer
        if ($ShowProgress) {
            $progress = New-TransferProgressWindow -Mode $Mode -FileCount $itemsToTransfer.Count
            $progress.Form.Show()
            $progress.Form.Activate()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    try {
        for ($index = 0; $index -lt $itemsToTransfer.Count; $index++) {
            $item = $itemsToTransfer[$index]
            $parent = Split-Path -Parent $item.Target
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            $callback = $null
            if ($ShowProgress) {
                $progress.Header.Text = '{0} file {1} of {2}' -f $Mode, ($index + 1), $itemsToTransfer.Count
                $progress.CurrentFile.Text = $item.Target
                $progress.SizeStatus.Text = 'Starting...'
                $progress.FileProgress.Value = 0
                [System.Windows.Forms.Application]::DoEvents()
                $lastUiUpdate = [datetime]::MinValue
                $callback = [Action[long,long]]{
                    param([long]$transferred, [long]$total)
                    $now = [datetime]::UtcNow
                    if (($now - $lastUiUpdate).TotalMilliseconds -ge 100 -or $transferred -ge $total) {
                        $percent = if ($total -gt 0) { [math]::Min(100, [math]::Floor(($transferred * 100.0) / $total)) } else { 100 }
                        $progress.FileProgress.Value = [int]$percent
                        $progress.SizeStatus.Text = '{0} of {1} ({2}%)' -f (Format-TransferSize $transferred), (Format-TransferSize $total), $percent
                        [System.Windows.Forms.Application]::DoEvents()
                        $lastUiUpdate = $now
                    }
                }
            }

            $overwrite = ($CollisionPolicy -eq 'Overwrite')
            if ($Mode -eq 'Copy') {
                [ReelArrange.NativeFileTransfer]::Copy($item.Source, $item.Target, $overwrite, $callback)
            }
            else {
                [ReelArrange.NativeFileTransfer]::Move($item.Source, $item.Target, $overwrite, $callback)
            }

            $completed++
            if ($ShowProgress) {
                $progress.FileProgress.Value = 100
                $progress.OverallProgress.Value = $completed
                $progress.OverallLabel.Text = "Overall: $completed of $($itemsToTransfer.Count) files complete"
                [System.Windows.Forms.Application]::DoEvents()
            }
            Write-ActivityLog ("{0}: {1} -> {2}" -f $Mode, $item.Source, $item.Target)
        }
    }
    finally {
        if ($null -ne $progress) {
            $progress.Form.Close()
            $progress.Form.Dispose()
        }
    }
    return [pscustomobject]@{
        Completed = $completed
        Skipped = if ($CollisionPolicy -eq 'Skip') { $existing.Count } else { 0 }
        Overwritten = if ($CollisionPolicy -eq 'Overwrite') { $existing.Count } else { 0 }
        Cancelled = $false
    }
}

function Test-IsArtworkFile {
    param([IO.FileInfo]$File)
    if (-not (@('.jpg', '.jpeg', '.png', '.webp') -contains $File.Extension.ToLowerInvariant())) { return $false }
    return $File.BaseName -match '(?i)^(poster|folder|cover|default|movie|show|backdrop|fanart|background|art|banner|logo|clearlogo|landscape|thumb)(?:-?\d+)?$'
}

function Get-SeasonNumberFromNames {
    param([string[]]$Names)
    foreach ($name in $Names) {
        if ($name -match '(?i)^(?:Season[ ._-]*|S)(?<number>\d{1,2})$') {
            return [int]$matches.number
        }
    }
    return $null
}

function Get-FolderCompanionPlan {
    param(
        [string]$SourceRoot,
        [string]$TargetMediaRoot,
        [ValidateSet('movie', 'tv')][string]$MediaType,
        [object[]]$ExistingPlan
    )

    $results = New-Object System.Collections.Generic.List[object]
    $plannedSources = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $ExistingPlan) { [void]$plannedSources.Add([string]$entry.Source) }
    $sourceRootFull = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')
    $rootLeaf = Split-Path -Leaf $sourceRootFull

    foreach ($file in Get-ChildItem -LiteralPath $sourceRootFull -File -Recurse) {
        if ($plannedSources.Contains($file.FullName)) { continue }
        $relative = $file.FullName.Substring($sourceRootFull.Length).TrimStart('\')
        $segments = @($relative -split '\\')
        $extraIndex = -1
        $canonicalExtra = ''
        for ($i = 0; $i -lt ($segments.Count - 1); $i++) {
            $candidate = Get-CanonicalExtraFolder $segments[$i]
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $extraIndex = $i
                $canonicalExtra = $candidate
                break
            }
        }

        $targetBase = $TargetMediaRoot
        if ($MediaType -eq 'tv') {
            $seasonNames = New-Object System.Collections.Generic.List[string]
            $seasonNames.Add($rootLeaf)
            for ($i = 0; $i -lt ($segments.Count - 1); $i++) { $seasonNames.Add($segments[$i]) }
            $seasonNumber = Get-SeasonNumberFromNames $seasonNames.ToArray()
            if ($null -ne $seasonNumber) {
                $targetBase = Join-Path $TargetMediaRoot ('Season {0:D2}' -f $seasonNumber)
            }
        }

        if ($extraIndex -ge 0) {
            $target = Join-Path $targetBase $canonicalExtra
            for ($i = $extraIndex + 1; $i -lt $segments.Count; $i++) {
                $target = Join-Path $target $segments[$i]
            }
            $results.Add([pscustomobject]@{ Source = $file.FullName; Target = $target })
            continue
        }

        if (Test-IsLooseExtra $file) {
            $results.Add([pscustomobject]@{ Source = $file.FullName; Target = Join-Path $targetBase $file.Name })
            continue
        }

        if (Test-IsArtworkFile $file) {
            $parentRelative = $file.DirectoryName.Substring($sourceRootFull.Length).TrimStart('\')
            if ([string]::IsNullOrWhiteSpace($parentRelative) -or $null -ne (Get-SeasonNumberFromNames @($file.Directory.Name, $rootLeaf))) {
                $results.Add([pscustomobject]@{ Source = $file.FullName; Target = Join-Path $targetBase $file.Name })
            }
        }
    }
    return $results.ToArray()
}

function Get-MovieTargetVideoBase {
    param([IO.FileInfo]$Video, [string]$FolderName, [int]$Index, [int]$Count)
    $part = [regex]::Match($Video.BaseName, '(?i)(?:^|[ ._-])(?<type>cd|dvd|part|pt|disc|disk)[ ._-]?(?<number>\d+|[a-d])(?:$|[ ._-])')
    if ($part.Success) {
        return '{0}-{1}{2}' -f $FolderName, $part.Groups['type'].Value.ToLowerInvariant(), $part.Groups['number'].Value.ToLowerInvariant()
    }
    if ($Count -eq 1) { return $FolderName }

    $labels = New-Object System.Collections.Generic.List[string]
    $resolution = [regex]::Match($Video.BaseName, '(?i)(2160p|1080p|720p|480p|4k|uhd)')
    if ($resolution.Success) { $labels.Add($resolution.Value.ToLowerInvariant()) }
    $edition = [regex]::Match($Video.BaseName, '(?i)(director(?:''s|s)?[ ._-]*cut|extended[ ._-]*(?:cut|edition)?|theatrical[ ._-]*(?:cut|edition)?|uncut)')
    if ($edition.Success) {
        $editionLabel = ($edition.Value -replace '[._-]+', ' ' -replace '\s+', ' ').Trim()
        $labels.Add((Get-Culture).TextInfo.ToTitleCase($editionLabel.ToLowerInvariant()))
    }
    if ($labels.Count -eq 0) { $labels.Add("Version $($Index + 1)") }
    return '{0} - {1}' -f $FolderName, ($labels -join ' ')
}

function New-MoviePlan {
    param(
        [IO.FileInfo[]]$Videos,
        [object]$Match,
        [string]$Root,
        [string]$SourceRoot = '',
        [bool]$IncludeFolderContent = $false
    )
    $title = Get-SafeName $Match.Title
    $yearText = if ($Match.Year -match '^\d{4}$') { " ($($Match.Year))" } else { '' }
    $folderName = '{0}{1} [tmdbid-{2}]' -f $title, $yearText, $Match.Item.id
    $targetDirectory = Join-Path $Root $folderName
    $plan = New-Object System.Collections.Generic.List[object]
    $usedTargets = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    for ($index = 0; $index -lt $Videos.Count; $index++) {
        $video = $Videos[$index]
        $targetVideoBase = Get-MovieTargetVideoBase -Video $video -FolderName $folderName -Index $index -Count $Videos.Count
        $targetVideo = Join-Path $targetDirectory ($targetVideoBase + $video.Extension.ToLowerInvariant())
        if (-not $usedTargets.Add($targetVideo)) {
            $targetVideoBase += " - Version $($index + 1)"
            $targetVideo = Join-Path $targetDirectory ($targetVideoBase + $video.Extension.ToLowerInvariant())
            [void]$usedTargets.Add($targetVideo)
        }
        $plan.Add([pscustomobject]@{ Source = $video.FullName; Target = $targetVideo })
        foreach ($sidecar in Get-AssociatedSidecars $video) {
            $targetName = Get-SidecarTargetName -Sidecar $sidecar -Video $video -TargetVideoBase $targetVideoBase
            $plan.Add([pscustomobject]@{ Source = $sidecar.FullName; Target = Join-Path $targetDirectory $targetName })
        }
    }
    if ($IncludeFolderContent -and -not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        foreach ($entry in Get-FolderCompanionPlan -SourceRoot $SourceRoot -TargetMediaRoot $targetDirectory -MediaType movie -ExistingPlan $plan.ToArray()) {
            $plan.Add($entry)
        }
    }
    return $plan.ToArray()
}

function New-TvPlan {
    param(
        [IO.FileInfo[]]$Videos,
        [object[]]$EpisodeInfo,
        [object]$Match,
        [string]$Root,
        [string]$Credential,
        [string]$SourceRoot = '',
        [bool]$IncludeFolderContent = $false
    )
    $title = Get-SafeName $Match.Title
    $yearText = if ($Match.Year -match '^\d{4}$') { " ($($Match.Year))" } else { '' }
    $seriesFolderName = '{0}{1} [tmdbid-{2}]' -f $title, $yearText, $Match.Item.id
    $filePrefix = $title + $yearText
    $seasonCache = @{}
    $plan = New-Object System.Collections.Generic.List[object]

    for ($index = 0; $index -lt $Videos.Count; $index++) {
        $video = $Videos[$index]
        $ep = $EpisodeInfo[$index]
        $seasonKey = [string]$ep.Season
        if (-not $seasonCache.ContainsKey($seasonKey)) {
            try {
                $seasonCache[$seasonKey] = Invoke-TmdbRequest -Path ("/tv/{0}/season/{1}" -f $Match.Item.id, $ep.Season) -Query @{ language = 'en-US' } -Credential $Credential
            }
            catch {
                $seasonCache[$seasonKey] = $null
            }
        }

        $episodeNames = New-Object System.Collections.Generic.List[string]
        $seasonData = $seasonCache[$seasonKey]
        if ($null -ne $seasonData) {
            for ($number = $ep.Episode; $number -le $ep.LastEpisode; $number++) {
                $episodeRecord = @($seasonData.episodes | Where-Object { [int]$_.episode_number -eq $number } | Select-Object -First 1)
                if ($episodeRecord.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$episodeRecord[0].name)) {
                    $episodeNames.Add((Get-SafeName ([string]$episodeRecord[0].name)))
                }
            }
        }

        $episodeCode = 'S{0:D2}E{1:D2}' -f $ep.Season, $ep.Episode
        if ($ep.LastEpisode -gt $ep.Episode) { $episodeCode += '-E{0:D2}' -f $ep.LastEpisode }
        $targetVideoBase = "$filePrefix $episodeCode"
        if ($episodeNames.Count -gt 0) { $targetVideoBase += ' ' + ($episodeNames -join ' + ') }
        $seasonFolder = 'Season {0:D2}' -f $ep.Season
        $targetDirectory = Join-Path (Join-Path $Root $seriesFolderName) $seasonFolder
        $plan.Add([pscustomobject]@{ Source = $video.FullName; Target = Join-Path $targetDirectory ($targetVideoBase + $video.Extension.ToLowerInvariant()) })
        foreach ($sidecar in Get-AssociatedSidecars $video) {
            $targetName = Get-SidecarTargetName -Sidecar $sidecar -Video $video -TargetVideoBase $targetVideoBase
            $plan.Add([pscustomobject]@{ Source = $sidecar.FullName; Target = Join-Path $targetDirectory $targetName })
        }
    }
    if ($IncludeFolderContent -and -not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        $seriesTargetRoot = Join-Path $Root $seriesFolderName
        foreach ($entry in Get-FolderCompanionPlan -SourceRoot $SourceRoot -TargetMediaRoot $seriesTargetRoot -MediaType tv -ExistingPlan $plan.ToArray()) {
            $plan.Add($entry)
        }
    }
    return $plan.ToArray()
}

function Get-PlanPreview {
    param([object[]]$Plan, [string]$Root)
    $relative = @($Plan | ForEach-Object {
        $_.Target.Substring($Root.TrimEnd('\').Length).TrimStart('\')
    })
    if ($relative.Count -le 18) { return $relative -join "`r`n" }
    return (($relative | Select-Object -First 18) -join "`r`n") + "`r`n...and $($relative.Count - 18) more file(s)"
}

function Invoke-SelfTest {
    $failures = New-Object System.Collections.Generic.List[string]
    $seed = Get-SearchSeed 'The.Matrix.1999.1080p.BluRay.x265.mkv' 'movie'
    if ($seed.Query -ne 'The Matrix' -or $seed.Year -ne '1999') { $failures.Add('Movie search cleanup') }
    $seed = Get-SearchSeed 'Some.Show.S02E03.2160p.WEB-DL.mkv' 'tv'
    if ($seed.Query -ne 'Some Show') { $failures.Add('TV search cleanup') }
    $ep = Get-EpisodeInfo 'Some.Show.S02E03-E04.mkv'
    if ($null -eq $ep -or $ep.Season -ne 2 -or $ep.Episode -ne 3 -or $ep.LastEpisode -ne 4) { $failures.Add('SxxEyy episode parsing') }
    $ep = Get-EpisodeInfo 'Some Show 1x07.mkv'
    if ($null -eq $ep -or $ep.Season -ne 1 -or $ep.Episode -ne 7) { $failures.Add('1xYY episode parsing') }
    if ((Get-SafeName 'Movie: The / Test?') -ne 'Movie- The - Test-') { $failures.Add('Windows-safe names') }
    $folderSeed = Get-SearchSeed 'Folder.Movie.2024' 'movie'
    if ($folderSeed.Query -ne 'Folder Movie' -or $folderSeed.Year -ne '2024') { $failures.Add('Folder search cleanup') }
    $extraFolderCases = @{
        'Behind-the-Scenes' = 'behind the scenes'
        'Deleted_Scenes' = 'deleted scenes'
        'Featurettes' = 'featurettes'
        'Theme Music' = 'theme-music'
        'Trailers' = 'trailers'
    }
    foreach ($case in $extraFolderCases.GetEnumerator()) {
        if ((Get-CanonicalExtraFolder $case.Key) -ne $case.Value) { $failures.Add("Extras folder mapping: $($case.Key)") }
    }
    $mock1080 = New-Object IO.FileInfo 'C:\test\Movie.2024.1080p.mkv'
    $mock2160 = New-Object IO.FileInfo 'C:\test\Movie.2024.2160p.mkv'
    if ((Get-MovieTargetVideoBase -Video $mock1080 -FolderName 'Movie (2024) [tmdbid-1]' -Index 0 -Count 2) -notmatch ' - 1080p$' -or
        (Get-MovieTargetVideoBase -Video $mock2160 -FolderName 'Movie (2024) [tmdbid-1]' -Index 1 -Count 2) -notmatch ' - 2160p$') {
        $failures.Add('Multiple movie version naming')
    }

    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ReelArrange-' + [guid]::NewGuid().ToString('N'))
    try {
        $sourceRoot = Join-Path $testRoot 'source'
        $destinationRoot = Join-Path $testRoot 'destination'
        [void](New-Item -ItemType Directory -Path $sourceRoot, $destinationRoot -Force)
        $videoPath = Join-Path $sourceRoot 'Test.Movie.2024.1080p.mkv'
        $subtitlePath = Join-Path $sourceRoot 'Test.Movie.2024.1080p.en.srt'
        [IO.File]::WriteAllText($videoPath, 'test video')
        [IO.File]::WriteAllText($subtitlePath, 'test subtitle')
        $featuretteRoot = Join-Path $sourceRoot 'Featurettes'
        [void](New-Item -ItemType Directory -Path $featuretteRoot -Force)
        $featurettePath = Join-Path $featuretteRoot 'Making Of.mkv'
        [IO.File]::WriteAllText($featurettePath, 'test featurette')
        $posterPath = Join-Path $sourceRoot 'poster.jpg'
        [IO.File]::WriteAllText($posterPath, 'test poster')
        $mockMatch = [pscustomobject]@{
            Title = 'Test: Movie'
            Year = '2024'
            Item = [pscustomobject]@{ id = 123 }
        }
        $moviePlan = @(New-MoviePlan -Videos @((Get-Item -LiteralPath $videoPath)) -Match $mockMatch -Root $destinationRoot -SourceRoot $sourceRoot -IncludeFolderContent $true)
        $expectedVideo = Join-Path $destinationRoot 'Test- Movie (2024) [tmdbid-123]\Test- Movie (2024) [tmdbid-123].mkv'
        $expectedSubtitle = Join-Path $destinationRoot 'Test- Movie (2024) [tmdbid-123]\Test- Movie (2024) [tmdbid-123].en.srt'
        $expectedFeaturette = Join-Path $destinationRoot 'Test- Movie (2024) [tmdbid-123]\featurettes\Making Of.mkv'
        $expectedPoster = Join-Path $destinationRoot 'Test- Movie (2024) [tmdbid-123]\poster.jpg'
        $plannedTargets = @($moviePlan | ForEach-Object { $_.Target })
        if ($moviePlan.Count -ne 4 -or $plannedTargets -notcontains $expectedVideo -or $plannedTargets -notcontains $expectedSubtitle -or $plannedTargets -notcontains $expectedFeaturette -or $plannedTargets -notcontains $expectedPoster) {
            $failures.Add('Movie folder and sidecar planning')
        }

        $tvSourceRoot = Join-Path $testRoot 'tv source'
        $tvFeaturetteRoot = Join-Path $tvSourceRoot 'Season 02\Behind-the-Scenes'
        $tvTrailerRoot = Join-Path $tvSourceRoot 'Trailers'
        [void](New-Item -ItemType Directory -Path $tvFeaturetteRoot, $tvTrailerRoot -Force)
        $tvFeaturettePath = Join-Path $tvFeaturetteRoot 'Episode Making Of.mkv'
        $tvTrailerPath = Join-Path $tvTrailerRoot 'Season Trailer.mkv'
        [IO.File]::WriteAllText($tvFeaturettePath, 'test tv extra')
        [IO.File]::WriteAllText($tvTrailerPath, 'test tv trailer')
        $tvTargetRoot = Join-Path $destinationRoot 'Test Show (2024) [tmdbid-456]'
        $tvExtraPlan = @(Get-FolderCompanionPlan -SourceRoot $tvSourceRoot -TargetMediaRoot $tvTargetRoot -MediaType tv -ExistingPlan @())
        $tvTargets = @($tvExtraPlan | ForEach-Object { $_.Target })
        $expectedTvFeaturette = Join-Path $tvTargetRoot 'Season 02\behind the scenes\Episode Making Of.mkv'
        $expectedTvTrailer = Join-Path $tvTargetRoot 'trailers\Season Trailer.mkv'
        if ($tvExtraPlan.Count -ne 2 -or $tvTargets -notcontains $expectedTvFeaturette -or $tvTargets -notcontains $expectedTvTrailer) {
            $failures.Add('TV show and season extras planning')
        }

        $collisionSource = Join-Path $sourceRoot 'collision-source.txt'
        $collisionTarget = Join-Path $destinationRoot 'collision-target.txt'
        [IO.File]::WriteAllText($collisionSource, 'new content')
        [IO.File]::WriteAllText($collisionTarget, 'existing content')
        $collisionPlan = @([pscustomobject]@{ Source = $collisionSource; Target = $collisionTarget })
        $stoppedOnCollision = $false
        try { [void](Invoke-TransferPlan -Plan $collisionPlan -Mode Copy -CollisionPolicy Stop) }
        catch { $stoppedOnCollision = $true }
        $skipResult = Invoke-TransferPlan -Plan $collisionPlan -Mode Copy -CollisionPolicy Skip
        if (-not $stoppedOnCollision -or $skipResult.Completed -ne 0 -or $skipResult.Skipped -ne 1 -or [IO.File]::ReadAllText($collisionTarget) -ne 'existing content') {
            $failures.Add('Stop and skip collision handling')
        }

        $newTarget = Join-Path $destinationRoot 'new-target.txt'
        $overwriteWithoutConflict = Invoke-TransferPlan -Plan @([pscustomobject]@{ Source = $collisionSource; Target = $newTarget }) -Mode Copy -CollisionPolicy Overwrite -ShowProgress $false
        if ($overwriteWithoutConflict.Completed -ne 1 -or $overwriteWithoutConflict.Overwritten -ne 0 -or [IO.File]::ReadAllText($newTarget) -ne 'new content') {
            $failures.Add('Overwrite transfer path')
        }

        $moveSource = Join-Path $sourceRoot 'move-source.txt'
        $moveTarget = Join-Path $destinationRoot 'move-target.txt'
        [IO.File]::WriteAllText($moveSource, 'move content')
        $moveResult = Invoke-TransferPlan -Plan @([pscustomobject]@{ Source = $moveSource; Target = $moveTarget }) -Mode Move -CollisionPolicy Skip -ShowProgress $false
        if ($moveResult.Completed -ne 1 -or (Test-Path -LiteralPath $moveSource) -or [IO.File]::ReadAllText($moveTarget) -ne 'move content') {
            $failures.Add('Native move transfer path')
        }
    }
    finally {
        $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
        $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
            Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
        }
    }

    if ($failures.Count -gt 0) { throw ('Self-test failed: ' + ($failures -join ', ')) }
    Write-Output 'All self-tests passed.'
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

try {
    $settings = Get-Settings
    $mediaType = Show-MediaTypeDialog
    if ([string]::IsNullOrWhiteSpace($mediaType)) { exit 0 }

    $source = Select-MediaSource $mediaType
    if ($null -eq $source) { exit 0 }
    $videos = @($source.Videos)
    if ($videos.Count -eq 0) {
        if ($mediaType -eq 'movie') {
            throw 'No main movie video was found at the top level of that folder.'
        }
        throw 'No episode video files were found outside recognized extras folders.'
    }
    foreach ($video in $videos) {
        if (-not ($script:VideoExtensions -contains $video.Extension.ToLowerInvariant())) {
            throw "This is not a supported video file: $($video.FullName)"
        }
    }

    $credential = Get-TmdbCredential $settings
    if ([string]::IsNullOrWhiteSpace($credential)) { exit 0 }

    $seedName = [string]$source.SearchName
    $seed = Get-SearchSeed $seedName $mediaType
    if ([string]::IsNullOrWhiteSpace($seed.Query)) {
        $seed = Get-SearchSeed $videos[0].Name $mediaType
    }
    $match = Select-TmdbMatch -MediaType $mediaType -InitialQuery $seed.Query -InitialYear $seed.Year -Credential $credential
    if ($null -eq $match) { exit 0 }

    $episodeInfo = @()
    if ($mediaType -eq 'tv') {
        $validVideos = New-Object System.Collections.Generic.List[IO.FileInfo]
        $validEpisodes = New-Object System.Collections.Generic.List[object]
        foreach ($video in $videos) {
            $ep = Get-EpisodeInfo $video.Name
            if ($null -eq $ep) {
                if ($videos.Count -eq 1) {
                    $ep = Show-EpisodeNumberDialog $video.Name
                    if ($null -eq $ep) { exit 0 }
                }
                else {
                    continue
                }
            }
            $validVideos.Add($video)
            $validEpisodes.Add($ep)
        }
        if ($validVideos.Count -eq 0) {
            throw 'No episode numbers were found. Episode files need S01E01 or 1x01 in their names.'
        }
        if ($validVideos.Count -lt $videos.Count) {
            $answer = [System.Windows.Forms.MessageBox]::Show("$($videos.Count - $validVideos.Count) video file(s) did not contain an episode number and will be skipped. Continue with $($validVideos.Count) recognized episode(s)?", 'Unrecognized episodes', 'YesNo', 'Warning')
            if ($answer -ne 'Yes') { exit 0 }
        }
        $videos = $validVideos.ToArray()
        $episodeInfo = $validEpisodes.ToArray()
    }

    $suggestedRoot = if ($mediaType -eq 'movie') { [string]$settings.MovieRoot } else { [string]$settings.ShowRoot }
    $temporaryRoot = if ([string]::IsNullOrWhiteSpace($suggestedRoot)) { Join-Path $env:TEMP '__ReelArrangePreview__' } else { $suggestedRoot }
    if ($mediaType -eq 'movie') {
        $temporaryPlan = @(New-MoviePlan -Videos $videos -Match $match -Root $temporaryRoot -SourceRoot $source.SourceRoot -IncludeFolderContent $source.IsFolder)
    }
    else {
        $temporaryPlan = @(New-TvPlan -Videos $videos -EpisodeInfo $episodeInfo -Match $match -Root $temporaryRoot -Credential $credential -SourceRoot $source.SourceRoot -IncludeFolderContent $source.IsFolder)
    }
    $preview = Get-PlanPreview -Plan $temporaryPlan -Root $temporaryRoot
    $operation = Select-Operation -SuggestedRoot $suggestedRoot -Preview $preview -MediaType $mediaType
    if ($null -eq $operation) { exit 0 }

    if ($mediaType -eq 'movie') {
        $settings.MovieRoot = $operation.Root
        $plan = @(New-MoviePlan -Videos $videos -Match $match -Root $operation.Root -SourceRoot $source.SourceRoot -IncludeFolderContent $source.IsFolder)
    }
    else {
        $settings.ShowRoot = $operation.Root
        $plan = @(New-TvPlan -Videos $videos -EpisodeInfo $episodeInfo -Match $match -Root $operation.Root -Credential $credential -SourceRoot $source.SourceRoot -IncludeFolderContent $source.IsFolder)
    }
    Save-Settings $settings

    $transferResult = Invoke-TransferPlan -Plan $plan -Mode $operation.Mode -CollisionPolicy $operation.CollisionPolicy
    if ($transferResult.Cancelled) { exit 0 }
    $videoCount = @($plan | Where-Object { $script:VideoExtensions -contains ([IO.Path]::GetExtension($_.Target).ToLowerInvariant()) }).Count
    $destination = Split-Path -Parent $plan[0].Target
    if ($mediaType -eq 'tv') { $destination = Split-Path -Parent $destination }
    $transferSummary = "$($operation.Mode) completed for $($transferResult.Completed) file(s), including matching sidecars."
    if ($transferResult.Overwritten -gt 0) { $transferSummary += "`r`nOverwritten: $($transferResult.Overwritten) existing file(s)." }
    if ($transferResult.Skipped -gt 0) { $transferSummary += "`r`nSkipped: $($transferResult.Skipped) existing file(s)." }
    Show-InfoMessage ("Done. Prepared $videoCount video file(s) for Jellyfin using TMDB ID $($match.Item.id).`r`n`r`n$transferSummary`r`n`r`nDestination:`r`n$destination")
}
catch {
    try { Write-ActivityLog ("ERROR: $($_.Exception.Message)") } catch { }
    Show-ErrorMessage $_.Exception.Message
    exit 1
}
