function Rename-FileAndReferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OldName,

        [Parameter(Mandatory)]
        [string]$NewName,

        [string]$Root = '.',

        [string[]]$Extensions = @('*.ps1','*.psm1','*.json','*.cs','*.js','*.ts','*.txt')
    )

    process {
        # 1) Locate and rename the file itself
        $file = Get-ChildItem -Path $Root -Recurse -File |
                Where-Object { $_.Name -eq $OldName } |
                Select-Object -First 1

        if (-not $file) {
            Write-Warning "File '$OldName' not found under '$Root'"
            return
        }

        $newPath = Join-Path $file.DirectoryName $NewName
        Rename-Item -LiteralPath $file.FullName -NewName $NewName -Force
        Write-Host "Renamed:`n  $($file.FullName)`n→ $newPath"

        # 2) Update all references in other files
        foreach ($pattern in $Extensions) {
            Get-ChildItem -Path $Root -Recurse -Include $pattern -File |
            ForEach-Object {
                $content = Get-Content -Raw -Encoding UTF8 $_.FullName
                if ($content -match [regex]::Escape($OldName)) {
                    $newContent = $content -replace [regex]::Escape($OldName), [regex]::Escape($NewName)
                    Set-Content -LiteralPath $_.FullName -Value $newContent -Encoding UTF8
                    Write-Host "Updated references in $($_.FullName)"
                }
            }
        }

        Write-Host "Done."
    }
}
