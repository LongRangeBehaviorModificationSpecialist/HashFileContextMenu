# DLU : 12-Jun-2026

Param (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$input_file_path,

    [Parameter(Position = 1, Mandatory = $true)]
    [ValidateSet("MD5", "SHA1", "SHA256", "SHA512")]
    [string]$algorithm
)


# Add the required .NET assembly
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework


function Get-UtcTime {
    # Helper function that returns the timestamp in UTC to add to the text file
    $utc_time = $((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    return $utc_time
}


function Get-UtcFileTime {
    # Helper function to return the UTC time the script was run to add to the output file's name
    $utc_file_time = $((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HHmmss"))
    return $utc_file_time
}


function Get-FormattedFileSize {
    # Helper function to format the size of the file to match the formatting in the Windows File Explorer
    param (
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    if (-not (Test-Path -Path $path -PathType Leaf)) {
        throw "File not found: $path"
    }

    $file = Get-Item -Path $path
    $bytes = $file.Length

    if ($bytes -ge 1GB) {
        $value = "{0:N2} GB" -f ($bytes / 1GB)
    }
    elseif ($bytes -ge 1MB) {
        $value = "{0:N2} MB" -f ($bytes / 1MB)
    }
    elseif ($bytes -ge 1KB) {
        $value = "{0:N2} KB" -f ($bytes / 1KB)
    }
    else {
        $value = "$bytes bytes"
    }

    return "$value ({0:N0} bytes)" -f $bytes
}


function Get-Messagebox {
    # Helper function to show message box when hashing is complete
    $msg_text = "Hashing of $($file.Name) is complete.`n`nThe verification file is: '$(Split-Path $output_file -Leaf)'`n`nSaved in: $parent_dir"
    [System.Windows.Forms.MessageBox]::Show($msg_text, "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}


# Get the file to be hashed
$file = Get-Item -LiteralPath $input_file_path
$parent_dir = $file.DirectoryName

# Construct the name of the verification file
$output_file = Join-Path -Path $parent_dir -ChildPath "$($file.Name)_$(Get-UtcFileTime).$algorithm"

Write-Host "`n[$(Get-UtcTime)] Calculating $algorithm hash for: $($file.Name)..." -ForegroundColor Blue
Write-Host "`n Results will be saved to $output_file" -ForegroundColor Green

"[$(Get-UtcTime)] Hashing started for file: $($file.Name)" | Out-File $output_file -Encoding utf8

# Calculate file hash
$hash_result = (Get-FileHash -Path $input_file_path -Algorithm $algorithm).Hash

# Build the verification report
$report = @"


    File Name  :  $($file.Name)
    Directory  :  $parent_dir
    File Size  :  $(Get-FormattedFileSize $input_file_path)
    Hash       :  $hash_result
    Algorithm  :  $algorithm


"@

# Write the verification report
$report | Out-File -Append -FilePath $output_file -Encoding utf8

"[$(Get-UtcTime)] File hashing complete." | Out-File -Append -FilePath $output_file -Encoding utf8

# Display specific lines to the terminal
$report.Split("`n")[2..8] | Write-Host


# Display success message box to the user
Get-Messagebox
