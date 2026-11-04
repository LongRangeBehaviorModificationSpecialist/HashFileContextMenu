<#
.SYNOPSIS
    Calculates MD5, SHA1 and SHA256 hashes of a single file and saves a timestamped verification report.

.DESCRIPTION
    This script reads the file supplied in -FilePath exactly once and feeds every block of data to
    three hash algorithms (MD5, SHA1 and SHA256) at the same time. It is intended for documenting
    the integrity of forensic evidence files, images, or any other file that must be verified later.

    For the selected file the script:
        1. Creates a verification file in the SAME directory as the source file. The name is
           "<OriginalFileName>_<yyyy-MM-dd_HH.mm.ss in UTC>.SHA256".
        2. Writes a start-time line, a report block (file name, directory, size, MD5, SHA1, SHA256),
           and a completion line that includes the elapsed time.
        3. Echoes the progress messages and the report block to the console.
        4. Displays a Windows message box telling the user that hashing is complete and where the
           verification file was saved.

    All time stamps are in UTC. The verification file is encoded as UTF-8.

    The script requires Windows PowerShell 5.0 or later (or PowerShell 7+ on Windows) because it
    loads the System.Windows.Forms and PresentationFramework assemblies for the completion
    message box and uses the [Type]::new() constructor syntax.

.PARAMETER FilePath
    The path to the file that will be hashed. The parameter is mandatory and can be supplied by
    position. Wildcards are not supported and the path must point to a file, not a folder.

.EXAMPLE
    .\HashFile.ps1 -FilePath "D:\Evidence\Laptop01.E01"

    Hashes Laptop01.E01 and creates "Laptop01.E01_2026-11-04_14.30.15.SHA256" in D:\Evidence.

.EXAMPLE
    .\HashFile.ps1 "D:\Evidence\Laptop01.E01"

    Same as the previous example, using the FilePath parameter by position.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Tools\HashFile.ps1" -FilePath "E:\Case42\image.dd"

    Runs the script from a command prompt or shortcut without changing the machine's execution policy.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    None. Nothing is written to the PowerShell output stream. Results are written to the console
    (Write-Host), to the verification file on disk, and to a message box.

.NOTES
    Platform : Windows only (uses Windows Forms for the message box).
    Output   : The verification file has a .SHA256 extension but also contains the MD5 and SHA1
               values.
    Paths    : A relative path is resolved against the process working directory
               ([Environment]::CurrentDirectory), which can differ from the PowerShell location.
               Using a full path is recommended.
    Errors   : If hashing fails part way through, the verification file will contain only the
               "Hashing started" line.

    Last Updated: 04-Nov-2026

.LINK
    https://github.com/LongRangeBehaviorModificationSpecialist/HashFileContextMenu
#>

Param (
    [Parameter(Position=0, Mandatory=$true)]
    [string]$FilePath
)


# Add the required .NET assembly
Add-Type -AssemblyName System.Windows.Forms, PresentationFramework


function Get-UtcTime {
    <#
    .SYNOPSIS
        Returns the current UTC date and time as a string in one of two formats.

    .DESCRIPTION
        Gets the current time, converts it to UTC, and formats it as text. Two formats are supported:

            DISPLAY   ISO 8601 style with milliseconds, for console and log lines.
                      Example: 2026-11-04T14:30:15.123Z
            FILE      Safe for use in file names (no colons), second resolution.
                      Example: 2026-11-04_14.30.15

        If -Format is omitted, no custom format is applied and the result is the current culture's
        default date/time string, so supplying -Format is recommended.

    .PARAMETER Format
        The output style. Valid values are "FILE" and "DISPLAY".

    .EXAMPLE
        Get-UtcTime -Format DISPLAY

        Returns a string such as 2026-11-04T14:30:15.123Z.

    .EXAMPLE
        $OutputFile = "Evidence.E01_$( Get-UtcTime -Format FILE ).SHA256"

        Builds a file name that contains a UTC time stamp: Evidence.E01_2026-11-04_14.30.15.SHA256

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.String. The formatted UTC date and time.

    .NOTES
        The time is read at the moment of the call, so two calls made one after the other can return
        different values.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("FILE", "DISPLAY")]
        [string]$Format
    )

    if ($Format -eq "DISPLAY") {
        $TimeFormat = "yyyy-MM-ddTHH:mm:ss.fffZ"
    }

    if ($Format -eq "FILE") {
        $TimeFormat = "yyyy-MM-dd_HH.mm.ss"
    }

    $UtcTime = $((Get-Date).ToUniversalTime().ToString($TimeFormat))
    return $UtcTime
}


function Get-FormattedFileSize {
    <#
    .SYNOPSIS
        Returns a file's size as readable text, showing the rounded size and the exact byte count.

    .DESCRIPTION
        Looks up the file and chooses the largest unit (GB, MB, KB or bytes) that fits, using
        1024-based units like Windows File Explorer. The rounded value is shown with two decimal
        places followed by the exact byte count with thousands separators.

        Example result: 1.50 MB (1,572,864 bytes)

        The function throws a terminating error if the path does not exist or is not a file.

    .PARAMETER FilePath
        Path to the file whose size should be formatted. The path must point to an existing file
        (not a folder).

    .EXAMPLE
        Get-FormattedFileSize -FilePath "C:\Evidence\memory.raw"

        Returns a string such as "8.00 GB (8,589,934,592 bytes)".

    .EXAMPLE
        $Size = Get-FormattedFileSize -FilePath $File.FullName

        Stores the formatted size so it can be placed in a report.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.String. The formatted size.

    .NOTES
        Files smaller than 1 KB are shown as "<n> bytes (<n> bytes)" because the rounded value and
        the exact count are the same number.
        The thousands separator and decimal mark follow the current culture.
    #>
    [CmdletBinding()]
    [OutputType([string])]

    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    begin {
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            throw "File not found => $FilePath."
        }
    }
    process {
        $File  = Get-Item -Path $FilePath
        $Bytes = $File.Length

        if ($Bytes -ge 1GB) { $Value = "{0:N2} GB" -f ($Bytes / 1GB) }
        elseif ($Bytes -ge 1MB) { $Value = "{0:N2} MB" -f ($Bytes / 1MB) }
        elseif ($Bytes -ge 1KB) { $Value = "{0:N2} KB" -f ($Bytes / 1KB) }
        else { $Value = "$Bytes bytes" }

        return "$Value ({0:N0} bytes)" -f $Bytes
    }
}


function Get-MessageBox {
    <#
    .SYNOPSIS
        Shows an information message box announcing that hashing has finished.

    .DESCRIPTION
        Displays a Windows message box titled "Success" with an OK button and an information icon.
        The message names the file that was hashed, the verification file that was created, and the
        folder it was saved in.

        This function has no parameters. It reads three variables that must already exist in the
        calling scope (PowerShell dynamic scoping):

            $File        The FileInfo object of the file that was hashed.
            $OutputFile  The full path of the verification file.
            $ParentDir   The directory that contains both files.

        The function blocks until the user closes the message box.

    .EXAMPLE
        Get-MessageBox

        Run from inside Write-ForensicHashesToFile, after $File, $OutputFile and $ParentDir have been
        set, to show the completion dialog.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. The dialog result is discarded with Out-Null.

    .NOTES
        Requires an interactive Windows desktop session. It will not work in a non-interactive
        session such as a scheduled task, a remote session or a service.
        The System.Windows.Forms assembly must be loaded first (done at the top of the script).
    #>
    process {
        $MsgText = "Hashing of $( $File.Name ) is complete.`n`nThe verification file is [ `
            $(Split-Path $OutputFile -Leaf) ]`n`nSaved in => $( $ParentDir )"

        [System.Windows.Forms.MessageBox]::Show($MsgText, "Success", [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}


function Format-Duration {
    <#
    .SYNOPSIS
        Converts a TimeSpan into short, readable text for console messages.

    .DESCRIPTION
        The layout depends on the length of the time span. The invariant culture is always used so
        the output is the same on every computer.

            Under 1 minute    "12.50 seconds"
            Under 1 hour      "5 min 07 sec"
            1 hour or more    "2 hr 05 min 09 sec"

        Seconds are shown with two decimal places only for spans under one minute. Longer spans
        show whole minutes and seconds (fractions of a second are dropped, not rounded).

    .PARAMETER Span
        The elapsed time to format, for example the Elapsed value of a Stopwatch. This parameter
        is mandatory.

    .EXAMPLE
        Format-Duration -Span (New-TimeSpan -Seconds 75)
        Returns "1 min 15 sec".

    .EXAMPLE
        Format-Duration -Span (New-TimeSpan -Hours 2 -Minutes 5 -Seconds 9)

        Returns "2 hr 05 min 09 sec".

    .EXAMPLE
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Seconds 3
        Format-Duration -Span $Stopwatch.Elapsed

        Returns a string such as "3.01 seconds".

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.String. The formatted duration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$Span
    )

    begin {
        $Inv = [System.Globalization.CultureInfo]::InvariantCulture
    }
    process {
        if ($Span.TotalSeconds -lt 60) {
            return [string]::Format($Inv, "{0:N2} seconds", $Span.TotalSeconds)
        }

        if ($Span.TotalHours -lt 1) {
            return [string]::Format($Inv, "{0} min {1:00} sec", $Span.Minutes, $Span.Seconds)
        }

        [string]::Format(
            $Inv, "{0} hr {1:00} min {2:00} sec", `
            [int][math]::Floor($Span.TotalHours), $Span.Minutes, $Span.Seconds
        )
    }
}


function Get-MultiFileHash {
    <#
    .SYNOPSIS
        Calculates the MD5, SHA1 and SHA256 hashes of a file in a single read pass.

    .DESCRIPTION
        Opens the file once for sequential, read-only access and reads it in 80 KB blocks. Each block
        is passed to the MD5, SHA1 and SHA256 algorithms, so the file is read from disk only once
        instead of three times (as would happen with three calls to Get-FileHash).

        The path is converted to a full path first. If the file does not exist, a terminating error
        is thrown. The file stream and the hash objects are always disposed, even when an error occurs.

    .PARAMETER FilePath
        Path to the file to hash. Wildcards are not supported. A relative path is resolved against
        the process working directory, which may differ from the current PowerShell location.

    .EXAMPLE
        Get-MultiFileHash -FilePath "D:\Evidence\Laptop01.E01"

        Returns an object with the properties Path, MD5, SHA1 and SHA256.

    .EXAMPLE
        (Get-MultiFileHash -FilePath "D:\Evidence\Laptop01.E01").SHA256

        Returns only the SHA256 hash as an uppercase hexadecimal string.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with these properties:
            Path    The full path of the file that was hashed.
            MD5     32-character uppercase hexadecimal string.
            SHA1    40-character uppercase hexadecimal string.
            SHA256  64-character uppercase hexadecimal string.

    .NOTES
        The file is opened with FileShare.Read, so the function fails if another process has the file
        open for writing.
        Hash values contain no dashes and are uppercase.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $ResolvedPath = [System.IO.Path]::GetFullPath($FilePath)
    if (-not (Test-Path -LiteralPath $ResolvedPath)) {
        throw "File not found: $ResolvedPath"
    }

    # Open a single FileStream with sequential scan optimization and an 80KB buffer
    $FileStream = [System.IO.FileStream]::new(
        $ResolvedPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read,
        81920, # 80 KB buffer size
        [System.IO.FileOptions]::SequentialScan
    )

    # Initialize both hash algorithms
    $Md5    = [System.Security.Cryptography.MD5]::Create()
    $Sha1   = [System.Security.Cryptography.SHA1]::Create()
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $Buffer = New-Object byte[] 81920

        # Read the file chunk-by-chunk and feed both hashes simultaneously
        while (($BytesRead = $FileStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $null = $Md5.TransformBlock($Buffer, 0, $BytesRead, $Buffer, 0)
            $null = $Sha1.TransformBlock($Buffer, 0, $BytesRead, $Buffer, 0)
            $null = $Sha256.TransformBlock($Buffer, 0, $BytesRead, $Buffer, 0)
        }

        # Finalize the hashes (passing a 0-byte block since the stream is fully read)
        $null = $Md5.TransformFinalBlock($Buffer, 0, 0)
        $null = $Sha1.TransformFinalBlock($Buffer, 0, 0)
        $null = $Sha256.TransformFinalBlock($Buffer, 0, 0)

        # Convert the resulting byte arrays to standard hex strings
        [PSCustomObject]@{
            Path   = $resolvedPath
            MD5    = [BitConverter]::ToString($Md5.Hash) -replace '-'
            SHA1   = [BitConverter]::ToString($Sha1.Hash) -replace '-'
            SHA256 = [BitConverter]::ToString($Sha256.Hash) -replace '-'
        }
    }
    finally {
        # Clean up unmanaged streams and crypto objects
        if ($FileStream) { $FileStream.Dispose() }
        if ($Md5)        { $Md5.Dispose() }
        if ($Sha1)       { $Sha1.Dispose() }
        if ($Sha256)     { $Sha256.Dispose() }
    }
}


function Write-ForensicHashesToFile {
    <#
    .SYNOPSIS
        Hashes a file and saves a timestamped verification report beside it.

    .DESCRIPTION
        This is the main routine of the script. It performs these steps:

            1. Starts a stopwatch and gets the file and its parent directory.
            2. Builds the verification file name:
               "<FileName>_<UTC yyyy-MM-dd_HH.mm.ss>.SHA256" in the same directory as the file.
            3. Writes a "Hashing started" line to the new file and prints status messages to the console.
            4. Calls Get-MultiFileHash to calculate the MD5, SHA1 and SHA256 hashes.
            5. Writes a report (file name, directory, size, and the three hashes) to the file.
            6. Writes a completion line with the elapsed time (via Format-Duration) to the file.
            7. Prints the report lines and the completion line to the console.
            8. Shows a completion message box by calling Get-MessageBox.

        The stopwatch is stopped in the end block. The elapsed time recorded in the file does not
        include the time the message box stays open.

    .PARAMETER FilePath
        Path to the file to hash. The file must exist. The verification file is created in the same
        folder, so the account running the script needs write access to that folder.

    .EXAMPLE
        Write-ForensicHashesToFile -FilePath "D:\Evidence\Laptop01.E01"

        Hashes the file and creates a verification file such as
        "Laptop01.E01_2026-11-04_14.30.15.SHA256" in D:\Evidence.

    .EXAMPLE
        Get-ChildItem "D:\Evidence" -Filter *.E01 | ForEach-Object { Write-ForensicHashesToFile -FilePath $_.FullName }

        Hashes every .E01 file in a folder one after another. A message box appears after each file.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. Output is sent to the console, a text file, and a message box, not to the pipeline.

    .NOTES
        Get-MessageBox depends on the variables $File, $OutputFile and $ParentDir defined in this
        function, so the two functions must be kept together.
        The report is written as it is built, so a failure during hashing leaves a verification file
        that contains only the "Hashing started" line.
        The report uses only the first run's time stamp for the file name; two runs on the same file
        within the same second would write to the same verification file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    begin {
        $Stopwatch    = [System.Diagnostics.Stopwatch]::StartNew()
        # Get the file to be hashed
        $File         = Get-Item -LiteralPath $FilePath
        $ParentDir    = $File.DirectoryName
    }
    process {

        # Construct the name of the verification file
        $OutputFile = Join-Path -Path $ParentDir -ChildPath "$( $File.Name )_$( Get-UtcTime -Format FILE ).SHA256"

        Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Calculating hashes for => $( $File.Name )..." `
            -ForegroundColor Blue
        Write-Host "`n[$( Get-UtcTime -Format DISPLAY )] Results will be saved to => $OutputFile`n" `
            -ForegroundColor Green

        "[$( Get-UtcTime -Format DISPLAY )] Hashing started for file => $( $File.Name )" | Out-File $OutputFile `
            -Encoding UTF8

        $FileHashes = Get-MultiFileHash -FilePath $FilePath

        # Build the verification report
        $Report = @"


    File Name   :  $( $File.Name )
    Directory   :  $ParentDir
    File Size   :  $( Get-FormattedFileSize -FilePath $FilePath )
    MD5 Hash    :  $( $FileHashes.MD5 )
    SHA1 Hash   :  $( $FileHashes.SHA1 )
    SHA256 Hash :  $( $FileHashes.SHA256 )


"@

        # Write the verification report
        $Report | Out-File -Append -FilePath $OutputFile -Encoding UTF8

        $Completed = "[$( Get-UtcTime -Format DISPLAY )] File hashing complete [ $( Format-Duration -Span `
        $Stopwatch.Elapsed ) ]."

        $Completed | Out-File -Append -FilePath $OutputFile -Encoding UTF8

        # Display specific lines to the terminal.
        $Report.Split("`n")[2..9] | Write-Host

        Write-Host "$Completed`n" -ForegroundColor Green

        # Display success message box to the user.
        Get-MessageBox
    }
    end {
        if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    }
}

Write-ForensicHashesToFile -FilePath $FilePath
