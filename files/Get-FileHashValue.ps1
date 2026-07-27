# DLU : 12-Jun-2026

Param (
    [Parameter(Position = 0,
               Mandatory = $true)]
    [string]$InputFilePath,

    [Parameter(Position = 1,
               Mandatory = $true)]
    [ValidateSet("MD5", "SHA1", "SHA256", "SHA512")]
    [string]$Algorithm
)


# Add the required .NET assembly
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework


function Get-UtcTime {
    <#
        .SYNOPSIS
            Returns the timestamp in UTC to add to the text file.
    #>
    process {
        return $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    }
}


function Get-UtcFileTime {
    <#
        .SYNOPSIS
            Return the UTC time to add to the output file's name.
    #>
    process {
        return $((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HHmmss"))
    }
}


function Get-FormattedFileSize {
    <#
        .SYNOPSIS
            Function to format the size of the file to match the formatting in the Windows File Explorer.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    begin {
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            throw "File not found: $Path"
        }
    }
    process {
        $File = Get-Item -Path $Path
        $Bytes = $File.Length

        if ($Bytes -ge 1GB) {
            $Value = "{0:N2} GB" -f ($Bytes / 1GB)
        }
        elseif ($Bytes -ge 1MB) {
            $Value = "{0:N2} MB" -f ($Bytes / 1MB)
        }
        elseif ($Bytes -ge 1KB) {
            $Value = "{0:N2} KB" -f ($Bytes / 1KB)
        }
        else {
            $Value = "$Bytes bytes"
        }

        return "$Value ({0:N0} bytes)" -f $Bytes
    }
}


function Get-Messagebox {
    <#
        .SYNOPSIS
            Shows message box when hashing is complete.
    #>
    begin{
        $MsgText = "Hashing of $($File.Name) is complete.`n`nThe verification file is: '$(Split-Path $OutputFile -Leaf)'`n`nSaved in: $ParentDir"
    }
    process {
        [System.Windows.Forms.MessageBox]::Show($MsgText, "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}


# Get the file to be hashed
$File = Get-Item -LiteralPath $InputFilePath
$ParentDir = $File.DirectoryName

# Construct the name of the verification file
$OutputFile = Join-Path -Path $ParentDir -ChildPath "$( $File.Name )_$( Get-UtcFileTime ).$Algorithm"

Write-Host "`n[$(Get-UtcTime)] Calculating $Algorithm hash for: $($File.Name)..." -ForegroundColor Blue
Write-Host "`n Results will be saved to $OutputFile" -ForegroundColor Green

"[$(Get-UtcTime)] Hashing started for file: $($File.Name)" | Out-File $OutputFile -Encoding utf8

# Calculate file hash
$HashResult = (Get-FileHash -Path $InputFilePath -Algorithm $Algorithm).Hash

# Build the verification report
$Report = @"


    File Name  :  $($File.Name)
    Directory  :  $ParentDir
    File Size  :  $(Get-FormattedFileSize $InputFilePath)
    Hash       :  $HashResult
    Algorithm  :  $Algorithm


"@

# Write the verification report
$Report | Out-File -Append -FilePath $OutputFile -Encoding utf8

"[$(Get-UtcTime)] File hashing complete." | Out-File -Append -FilePath $OutputFile -Encoding utf8

# Display specific lines to the terminal
$Report.Split("`n")[2..8] | Write-Host


# Display success message box to the user
Get-Messagebox
