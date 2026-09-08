# DLU : 08-Sep-2026

Param (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$InputFilePath
)


# Add the required .NET assembly
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework


function Get-UtcTime {
    <#
    .SYNOPSIS
        Helper function that returns the timestamp in UTC in two
        different formats.
    #>
    param(
        [ValidateSet("FILE", "DISPLAY")]
        [string]$Format
    )

    if ($Format -eq "DISPLAY") {
        $TimeFormat = "yyyy-MM-ddTHH:mm:ssZ"
    }

    if ($Format -eq "FILE") {
        $TimeFormat = "yyyy-MM-dd_HHmmss"
    }

    $UtcTime = $((Get-Date).ToUniversalTime().ToString($TimeFormat))
    return $UtcTime
}


function Get-FormattedFileSize {
    <#
    .SYNOPSIS
        Function to format the size of the file to match the formatting in
        the Windows File Explorer.
    #>
    [CmdletBinding()]
    [OutputType([string])]

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    begin {
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            throw "File not found → $Path."
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
    process {
        $MsgText = "Hashing of $( $File.Name ) is complete.`n`nThe verification file is: '$(Split-Path $OutputFile -Leaf)'`n`nSaved in: $( $ParentDir )"
        [System.Windows.Forms.MessageBox]::Show($MsgText, "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}


function Write-ForensicHashesToFile {
    <#
    .SYNOPSIS
        Hashes selected file and writes output to seperate file.
    #>
    process {
        # Get the file to be hashed.
        $File = Get-Item -LiteralPath $InputFilePath
        $ParentDir = $File.DirectoryName

        # Construct the name of the verification file.
        $OutputFile = Join-Path -Path $ParentDir -ChildPath "$( $File.Name )_$( Get-UtcTime -Format FILE ).SHA256"

        Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Calculating MD5 and SHA256 hashes for → $( $File.Name )..." -ForegroundColor Blue
        Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Results will be saved to $OutputFile`n" -ForegroundColor Green

        "[$( Get-UtcTime -Format DISPLAY )] Hashing started for file → $( $File.Name )" | Out-File $OutputFile -Encoding utf8

        # Calculate file hash.
        $Md5Result = (Get-FileHash -Path $InputFilePath -Algorithm MD5).Hash
        $Sha256Result = (Get-FileHash -Path $InputFilePath -Algorithm SHA256).Hash

        # Build the verification report.
        $Report = @"


    File Name   :  $( $File.Name )
    Directory   :  $ParentDir
    File Size   :  $( Get-FormattedFileSize -Path $InputFilePath )
    MD5 Hash    :  $Md5Result
    SHA256 Hash :  $Sha256Result


"@

        # Write the verification report.
        $Report | Out-File -Append -FilePath $OutputFile -Encoding utf8

        "[$( Get-UtcTime -Format DISPLAY )] File hashing complete." | Out-File -Append -FilePath $OutputFile -Encoding utf8

        # Display specific lines to the terminal.
        $Report.Split("`n")[2..8] | Write-Host

        # Display success message box to the user.
        Get-Messagebox
    }
}

Write-ForensicHashesToFile
