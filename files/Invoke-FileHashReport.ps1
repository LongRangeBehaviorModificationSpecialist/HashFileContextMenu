<#
.SYNOPSIS
    Consolidated script to calculate single or multi-algorithm file hashes and write timestamped reports.
#>

#Requires -Version 5.1

Param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Position = 1, Mandatory = $false)]
    [ValidateSet("MD5", "SHA1", "SHA256", "SHA512", "All")]
    [string]$Algorithm = "All",

    [switch]$NoPopup,
    [switch]$PrintToScreen
)

# Explicitly import the module from the user modules directory
Import-Module FileHashTools -Force
Write-Host "FileHashTools module imported..." -ForegroundColor Cyan

$Stopwatch  = [System.Diagnostics.Stopwatch]::StartNew()
$File       = Get-Item -LiteralPath $FilePath
$ParentDir  = $File.DirectoryName
$FileSize   = Get-FormattedFileSize -Bytes $File.Length

# If printing to screen, we don't need to generate a verification file path or write to disk
if (-not $PrintToScreen) {
    $FileExt = if ($Algorithm -eq "All") { "SHA256" } else { $Algorithm }
    $OutputFile = Join-Path -Path $ParentDir -ChildPath "$( $File.Name )_$( Get-UtcTime -Format FILE ).$FileExt"

    Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Calculating hashes for => $( $File.Name )..." -ForegroundColor Blue
    Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Results will be saved to => $OutputFile`n" -ForegroundColor Green

    "[$( Get-UtcTime -Format DISPLAY )] Hashing started for file => $( $File.Name )" |
        Out-File -LiteralPath $OutputFile -Encoding UTF8 -NoClobber
}
else {
    Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Calculating $Algorithm hash for => $( $File.Name )..." -ForegroundColor Blue
}

try {
    # Ultra-fast single-pass stream engine
    $FileHashes = Get-MultiFileHash -FilePath $FilePath
}
catch {
    $Stopwatch.Stop()
    if (-not $PrintToScreen) {
        $Failed = "[$( Get-UtcTime -Format DISPLAY )] Hashing FAILED after [ $( Format-Duration -Span $Stopwatch.Elapsed ) ] => $( $_.Exception.Message )"
        $Failed | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8
    }
    throw
}

$Stopwatch.Stop()

# Build report field lines
if ($Algorithm -eq "All") {
    $FieldLines = @(
        "    File Name   :  $( $File.Name )"
        "    Directory   :  $ParentDir"
        "    File Size   :  $FileSize"
        "    MD5 Hash    :  $( $FileHashes.MD5 )"
        "    SHA1 Hash   :  $( $FileHashes.SHA1 )"
        "    SHA256 Hash :  $( $FileHashes.SHA256 )"
        "    SHA512 Hash :  $( $FileHashes.SHA512 )"
    )
}
else {
    $SingleHashValue = $FileHashes.$Algorithm
    $FieldLines = @(
        "    File Name   :  $( $File.Name )"
        "    Directory   :  $ParentDir"
        "    File Size   :  $FileSize"
        "    Hash        :  $SingleHashValue"
        "    Algorithm   :  $Algorithm"
    )
}

$Completed = "[$( Get-UtcTime -Format DISPLAY )] File hashing complete [ $( Format-Duration -Span $Stopwatch.Elapsed ) ]."

# If not printing to screen, write the report to the output file
if (-not $PrintToScreen) {
    $ReportLines = @("", "") + $FieldLines + @("", "", $Completed)
    $ReportLines | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8
}

# Display the report to the terminal
Write-Host
$FieldLines | Write-Host
Write-Host
Write-Host "$Completed`n" -ForegroundColor Green

# Display success message box only if it's a file save operation and popups aren't suppressed
if (-not $PrintToScreen -and -not $NoPopup) {
    try {
        Show-MessageBox -FileName $File.Name -VerificationFilePath $OutputFile
    }
    catch {
        Write-Warning "Could not display the message box: $( $_.Exception.Message )"
    }
}



# # Determine output file extension based on selected algorithm view
# $FileExt = if ($Algorithm -eq "All") {
#     "SHA256"
# } else {
#     $Algorithm
# }

# $OutputFile = Join-Path -Path $ParentDir -ChildPath "$( $File.Name )_$( Get-UtcTime -Format FILE ).$FileExt"

# Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Calculating hashes for => $( $File.Name )..." -ForegroundColor Blue
# Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Results will be saved to => $OutputFile`n" -ForegroundColor Green

# "[$( Get-UtcTime -Format DISPLAY )] Hashing started for file => $( $File.Name )" |
#     Out-File -LiteralPath $OutputFile -Encoding UTF8 -NoClobber

# try {
#     # Always leverages the ultra-fast single-pass stream engine underneath
#     $FileHashes = Get-MultiFileHash -FilePath $FilePath
# }
# catch {
#     $Stopwatch.Stop()
#     $Failed = "[$( Get-UtcTime -Format DISPLAY )] Hashing FAILED after [ $( Format-Duration -Span $Stopwatch.Elapsed ) ] => $( $_.Exception.Message )"
#     $Failed | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8
#     throw
# }

# $Stopwatch.Stop()

# # Build report lines depending on whether a single algorithm or all were requested
# if ($Algorithm -eq "All") {
#     $FieldLines = @(
#         "    File Name   :  $( $File.Name )"
#         "    Directory   :  $ParentDir"
#         "    File Size   :  $FileSize"
#         "    MD5 Hash    :  $( $FileHashes.MD5 )"
#         "    SHA1 Hash   :  $( $FileHashes.SHA1 )"
#         "    SHA256 Hash :  $( $FileHashes.SHA256 )"
#         "    SHA512 Hash :  $( $FileHashes.SHA512 )"
#     )
# }
# else {
#     $SingleHashValue = $FileHashes.$Algorithm
#     $FieldLines = @(
#         "    File Name   :  $( $File.Name )"
#         "    Directory   :  $ParentDir"
#         "    File Size   :  $FileSize"
#         "    Hash        :  $SingleHashValue"
#         "    Algorithm   :  $Algorithm"
#     )
# }

# $Completed = "[$( Get-UtcTime -Format DISPLAY )] File hashing complete [ $( Format-Duration -Span $Stopwatch.Elapsed ) ]."

# $ReportLines = @("", "") + $FieldLines + @("", "", $Completed)
# $ReportLines | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8

# $FieldLines | Write-Host
# Write-Host
# Write-Host "$Completed`n" -ForegroundColor Green

# if (-not $NoPopup) {
#     try {
#         Show-MessageBox -FileName $File.Name -VerificationFilePath $OutputFile
#     }
#     catch {
#         Write-Warning "Could not display the message box: $( $_.Exception.Message )"
#     }
# }
