Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "OISOFlash"
$form.Size = New-Object System.Drawing.Size(560, 440)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "OISOFlash"
$title.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(15, 10)
$title.Size = New-Object System.Drawing.Size(200, 30)
$form.Controls.Add($title)

$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "1. Selecteer Image-bestanden (.iso, .img, .bin, .raw, .dmg):"
$lbl1.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$lbl1.Location = New-Object System.Drawing.Point(15, 48)
$lbl1.Size = New-Object System.Drawing.Size(400, 20)
$form.Controls.Add($lbl1)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(15, 72)
$listBox.Size = New-Object System.Drawing.Size(390, 110)
$form.Controls.Add($listBox)

$script:files = New-Object System.Collections.ArrayList

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Toevoegen..."
$btnAdd.Location = New-Object System.Drawing.Point(415, 72)
$btnAdd.Size = New-Object System.Drawing.Size(120, 30)
$btnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Filter = "Disk Images (*.iso;*.img;*.bin;*.raw;*.dmg)|*.iso;*.img;*.bin;*.raw;*.dmg|Alle bestanden (*.*)|*.*"
    if ($dlg.ShowDialog() -eq "OK") {
        foreach ($f in $dlg.FileNames) {
            if (-not $script:files.Contains($f)) {
                [void]$script:files.Add($f)
                [void]$listBox.Items.Add([System.IO.Path]::GetFileName($f))
            }
        }
        if ($listBox.Items.Count -gt 0 -and $listBox.SelectedIndex -eq -1) { $listBox.SelectedIndex = 0 }
    }
})
$form.Controls.Add($btnAdd)

$btnRem = New-Object System.Windows.Forms.Button
$btnRem.Text = "Verwijderen"
$btnRem.Location = New-Object System.Drawing.Point(415, 110)
$btnRem.Size = New-Object System.Drawing.Size(120, 30)
$btnRem.Add_Click({
    $idx = $listBox.SelectedIndex
    if ($idx -ne -1) {
        $listBox.Items.RemoveAt($idx)
        $script:files.RemoveAt($idx)
    }
})
$form.Controls.Add($btnRem)

$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "2. Kies doel USB-stick:"
$lbl2.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$lbl2.Location = New-Object System.Drawing.Point(15, 195)
$lbl2.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($lbl2)

$combo = New-Object System.Windows.Forms.ComboBox
$combo.DropDownStyle = "DropDownList"
$combo.Location = New-Object System.Drawing.Point(15, 220)
$combo.Size = New-Object System.Drawing.Size(420, 28)
$form.Controls.Add($combo)

$script:drives = @{}

function Refresh-Drives {
    $script:drives.Clear()
    $combo.Items.Clear()
    $disks = Get-Disk | Where-Object { $_.BusType -eq 'USB' }
    foreach ($d in $disks) {
        $gb = [math]::Round($d.Size / 1GB, 1)
        $label = "PhysicalDrive$($d.Number) - $($d.FriendlyName) ($gb GB)"
        $script:drives[$label] = "\\.\PhysicalDrive$($d.Number)"
        [void]$combo.Items.Add($label)
    }
    if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
    else { [void]$combo.Items.Add("Geen USB-sticks gevonden"); $combo.SelectedIndex = 0 }
}

$btnRef = New-Object System.Windows.Forms.Button
$btnRef.Text = "Vernieuwen"
$btnRef.Location = New-Object System.Drawing.Point(445, 219)
$btnRef.Size = New-Object System.Drawing.Size(90, 26)
$btnRef.Add_Click({ Refresh-Drives })
$form.Controls.Add($btnRef)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(15, 270)
$progress.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($progress)

$status = New-Object System.Windows.Forms.Label
$status.Text = "OISOFlash Klaar."
$status.Location = New-Object System.Drawing.Point(15, 302)
$status.Size = New-Object System.Drawing.Size(520, 20)
$form.Controls.Add($status)

$btnFlash = New-Object System.Windows.Forms.Button
$btnFlash.Text = "FLASH MET OISOFLASH"
$btnFlash.BackColor = [System.Drawing.Color]::FromArgb(217, 83, 79)
$btnFlash.ForeColor = [System.Drawing.Color]::White
$btnFlash.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$btnFlash.Location = New-Object System.Drawing.Point(15, 335)
$btnFlash.Size = New-Object System.Drawing.Size(520, 48)
$btnFlash.Add_Click({
    $idx = $listBox.SelectedIndex
    if ($idx -eq -1) { [System.Windows.Forms.MessageBox]::Show("Kies eerst een bestand.", "OISOFlash"); return }
    $drvLabel = $combo.SelectedItem
    if (-not $script:drives.ContainsKey($drvLabel)) { [System.Windows.Forms.MessageBox]::Show("Kies een geldige USB-stick.", "OISOFlash"); return }

    $imgPath = $script:files[$idx]
    $target = $script:drives[$drvLabel]

    $ans = [System.Windows.Forms.MessageBox]::Show("Alle gegevens op:`n$drvLabel`n`nworden GEWIST en overschreven met:`n$([System.IO.Path]::GetFileName($imgPath))`n`nDoorgaan?", "OISOFlash - WAARSCHUWING", "YesNo", "Warning")
    if ($ans -eq "Yes") {
        $btnFlash.Enabled = $false
        $status.Text = "USB voorbereiden..."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $diskNum = $target.Replace("\\.\PhysicalDrive", "")
            Clear-Disk -Number $diskNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop

            $status.Text = "Bezig met flashen... Verwijder de USB-stick niet."
            $total = (Get-Item $imgPath).Length
            $buf = New-Object byte[] (4MB)
            $written = 0

            $src = [System.IO.File]::OpenRead($imgPath)
            $dst = New-Object System.IO.FileStream($target, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 4MB, [System.IO.FileOptions]::WriteThrough)

            while (($read = $src.Read($buf, 0, $buf.Length)) -gt 0) {
                $dst.Write($buf, 0, $read)
                $written += $read
                $progress.Value = [int](($written * 100) / $total)
                [System.Windows.Forms.Application]::DoEvents()
            }
            $src.Close()
            $dst.Close()

            $status.Text = "Klaar! Je kunt de USB-stick veilig verwijderen."
            [System.Windows.Forms.MessageBox]::Show("Flashen gelukt!", "OISOFlash")
        }
        catch {
            $status.Text = "Fout: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Fout: $($_.Exception.Message)`n`nStart OISOFlash.exe als Administrator.", "OISOFlash Fout")
        }
        finally {
            $btnFlash.Enabled = $true
        }
    }
})
$form.Controls.Add($btnFlash)

Refresh-Drives
[void]$form.ShowDialog()
