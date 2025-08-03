function Get-PatternType {
    param(
        [string]$InputString
    )

    if ($InputString -match '[\*\?\[\]]') {
        return 'Glob'
    } 
    #elseif ($InputString -match '[\^\$\.\|\(\)\+\{\}\\]') {
    #    return 'Regex'
    #} 
    else {
        return 'Literal'
    }
}

function Update-References {
    param(
        [string]$Root,
        [string[]]$Extensions,
        [string]$OldBaseName,
        [string]$NewBaseName
    )

    foreach ($pattern in $Extensions) {
        Get-ChildItem -Path $Root -Recurse -Include $pattern -File |
        ForEach-Object {
            $content = Get-Content -Raw -Encoding UTF8 $_.FullName
            if ($content -match [regex]::Escape($OldBaseName)) {
                $newContent = $content -replace [regex]::Escape($OldBaseName), $NewBaseName
                Set-Content -LiteralPath $_.FullName -Value $newContent -Encoding UTF8
                Write-Host "Updated references in $($_.FullName): $OldBaseName → $NewBaseName"
            }
        }
    }
}

function Get-FilesMatching {
    param(
        [string]$Root,
        [string]$Pattern,
        [string]$PatternType
    )
    
    switch ($PatternType) {
        'Glob' {
            return Get-ChildItem -Path $Root -Recurse -File | Where-Object { $_.BaseName -like $Pattern }
        }
        'Literal' {
            return Get-ChildItem -Path $Root -Recurse -File | Where-Object { $_.BaseName -eq $Pattern } 
        }
    }
}

function Rename-FileAndReferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OldName,

        [Parameter(Mandatory)]
        [string]$NewName,

        [string]$Root = $pwd,

        [string[]]$Extensions = @('*.ps1', '*.psm1', '*.psd1', '*.json', '*.cs', '*.js', '*.ts', '*.txt', '*.env')
    )

    process {
        $patternType = Get-PatternType -InputString $OldName

        if ($patternType -eq 'Regex') {
            Write-Warning "Regex patterns are not supported for renaming."
            return
        }
        $files = Get-FilesMatching -Root $Root -Pattern $OldName -PatternType $patternType

        if (-not $files) {
            Write-Warning "No files matching '$OldName' found under '$Root'"
            Write-Warning "You are replacing strings?"
            scooter -s $OldName -r $NewName -I "$($Extensions -join ',')"
            #return
        }
        else {

            # Convert single file to array for consistent processing
            if ($files -isnot [array]) { $files = @($files) }
            
            foreach ($file in $files) {
                $oldBaseName = $file.BaseName
                $extension = $file.Extension
            
                # Generate new name based on pattern type
                if ($patternType -eq 'Glob') {
                    #$newBaseName = $NewName -replace '\*', $oldBaseName
                    $newBaseName = $NewName
                }
                elseif ($patternType -eq 'Literal') {
                    $newBaseName = $NewName
                }
                else {
                    Write-Warning "Unsupported pattern type: $patternType"
                    #return
                }
            
                $newFileName = $newBaseName + $extension
            
                Rename-Item -LiteralPath $file.FullName -NewName $newFileName -Force
                Update-References -Root $Root -Extensions $Extensions -OldBaseName $oldBaseName -NewBaseName $newBaseName
            }
        }
        
        Write-Host "Done."
    }
}

Set-Alias -Name rref -Value Rename-FileAndReferences
