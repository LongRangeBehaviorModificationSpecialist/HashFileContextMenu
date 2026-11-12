<#
.SYNOPSIS
    Shared helper module containing high-performance stream hashing and
    formatting utilities.
#>

function Get-UtcTime {
    <#
    .SYNOPSIS
        Returns the current UTC date and time as a string in one of two
        formats.

    .DESCRIPTION
        Gets the current time in UTC and formats it as text.  The invariant
        culture is always used, so the separators in the result never change
        with the computer's regional settings.  Two formats are supported:

            DISPLAY :   ISO 8601 style with milliseconds, for console and
                        log lines.
                        Example: 2026-11-04T14:30:15.123Z

            FILE    :   Safe for use in file names (no colons), second
                        resolution.
                        Example: 2026-11-04_14.30.15

    .PARAMETER Format
        The output style.  This parameter is mandatory.  Valid values are
        "FILE" and "DISPLAY".

    .EXAMPLE
        Get-UtcTime -Format DISPLAY

        Returns a string such as 2026-11-04T14:30:15.123Z.

    .EXAMPLE
        $OutputFile = "Evidence.E01_$( Get-UtcTime -Format FILE ).SHA256"

        Builds a file name that contains a UTC time stamp:
            Evidence.E01_2026-11-04_14.30.15.SHA256

    .INPUTS
        None.  This function does not accept pipeline input.

    .OUTPUTS
        System.String.  The formatted UTC date and time.

    .NOTES
        The time is read at the moment of the call, so two calls made one
        after the other can return different values.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("FILE", "DISPLAY")]
        [string]$Format
    )

    $TimeFormat = switch ($Format) {
        "DISPLAY" { "yyyy-MM-ddTHH:mm:ss.fffZ" }
        "FILE"    { "yyyy-MM-dd_HH.mm.ss" }
    }

    [datetime]::UtcNow.ToString(
        $TimeFormat,
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}


function Get-FormattedFileSize {
    <#
    .SYNOPSIS
        Returns a size in bytes as readable text, showing the rounded size
        and the exact byte count.

    .DESCRIPTION
        Chooses the largest unit (TB, GB, MB or KB) that fits, using
        1024-based units like Windows File Explorer.  The rounded value is
        shown with two decimal places, followed by the exact byte count
        with thousands separators. Sizes under 1 KB are shown as plain bytes.

        The size can be supplied directly with '-Bytes' or looked up from a
        file with -FilePath.  The invariant culture is always used so the text
        is the same on every computer.

        Example result: 1.50 MB (1,572,864 bytes)

        A value that would round up to 1,024.00 of a unit (for example
        1,048,575 bytes) is shown in the next larger unit instead.

    .PARAMETER FilePath
        Path to the file whose size should be formatted.  The path is used
        literally (wildcard characters such as [ ] are not expanded) and must
        point to an existing file, otherwise a terminating error is thrown.

    .PARAMETER Bytes
        The size in bytes. Use this when the size is already known (for
        example $File.Length) to avoid a second file lookup.

    .EXAMPLE
        Get-FormattedFileSize -FilePath "C:\Evidence\memory.raw"

        Returns a string such as "8.00 GB (8,589,934,592 bytes)".

    .EXAMPLE
        Get-FormattedFileSize -Bytes $File.Length

        Formats a size that is already available.

    .EXAMPLE
        Get-FormattedFileSize -Bytes 512

        Returns "512 bytes".

    .INPUTS
        None.  This function does not accept pipeline input.

    .OUTPUTS
        System.String.  The formatted size.

    .NOTES
        Units are 1024-based (KB = 1,024 bytes), matching Windows File
        Explorer.
    #>
    [CmdletBinding(DefaultParameterSetName = "ByPath")]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "ByPath")]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory, ParameterSetName = "ByBytes")]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$Bytes
    )

    if ($PSCmdlet.ParameterSetName -eq "ByPath") {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            throw "File not found => $FilePath."
        }
        $Bytes = (Get-Item -LiteralPath $FilePath).Length
    }

    $Inv = [System.Globalization.CultureInfo]::InvariantCulture

    if ($Bytes -lt 1KB) {
        return [string]::Format($Inv, "{0:N0} bytes", $Bytes)
    }

    # Divide by 1,024 until the rounded value is below 1,024 (or the largest
    # unit is reached)
    $Units = "KB", "MB", "GB", "TB"
    $Size  = [double]$Bytes
    $Index = -1
    do {
        $Size /= 1024
        $Index++
    } while ([math]::Round($Size, 2) -ge 1024 -and $Index -lt ($Units.Count - 1))

    return [string]::Format(
        $Inv,
        "{0:N2} {1} ({2:N0} bytes)",
        $Size,
        $Units[$Index],
        $Bytes
    )
}


function Show-MessageBox {
    <#
    .SYNOPSIS
        Shows a formatted completion dialog (bold headings, colored title,
        monospaced values).

    .DESCRIPTION
        Replacement for the standard message box version of 'Show-MessageBox'.
        The built-in Windows message box can only show plain text, so this
        version builds a small custom dialog with a read-only RichTextBox,
        which supports fonts, bold text, sizes and colors.  The text can also
        be selected and copied by the user.

        If the session is not interactive (for example a scheduled task or
        a service), nothing is shown and the function returns without error.

    .PARAMETER FileName
        The name of the file that was hashed (name only, no folder).

    .PARAMETER VerificationFilePath
        The full path of the verification file.  The file name and the folder
        shown in the dialog are taken from this path.

    .PARAMETER Title
        The title bar text of the dialog.  The default is "Success".

    .EXAMPLE
        Show-MessageBox `
            -FileName "drive.E01" -VerificationFilePath `
            "D:\Evidence\drive.E01_2026-11-04_14.30.15.SHA256"

    .INPUTS
        None.  This function does not accept pipeline input.

    .OUTPUTS
        None.

    .NOTES
        Requires Windows and an interactive desktop session.  The function
        waits until the user clicks "OK".
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$VerificationFilePath,

        [string]$Title = "Success"
    )

    if (-not [Environment]::UserInteractive) {
        Write-Verbose "Session is not interactive; the message box was not shown."
        return
    }

    # Add the required .NET assembly
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $VerificationFileName = Split-Path -Path $VerificationFilePath -Leaf
    $Directory            = Split-Path -Path $VerificationFilePath -Parent

    # Fonts and colors used in the custom dialog box
    $Bold = [System.Drawing.FontStyle]::Bold
    $Fonts = @{
        Heading = [System.Drawing.Font]::New("Segoe UI", 14, $Bold)
        Label   = [System.Drawing.Font]::New("Segoe UI", 10, $Bold)
        Value   = [System.Drawing.Font]::New("Consolas", 10)
        Normal  = [System.Drawing.Font]::New("Segoe UI", 10)
    }

    $Blue  = [System.Drawing.Color]::FromArgb(21, 93, 252)
    $Black = [System.Drawing.Color]::Black

    $Form = [System.Windows.Forms.Form]::New()
    try {
        $Form.Text            = $Title
        $Form.StartPosition   = "CenterScreen"
        $Form.FormBorderStyle = "FixedDialog"
        $Form.MaximizeBox     = $false
        $Form.MinimizeBox     = $false
        $Form.TopMost         = $true
        $Form.ClientSize      = [System.Drawing.Size]::New(560, 260)


        $Rtb             = [System.Windows.Forms.RichTextBox]::New()
        $Rtb.ReadOnly    = $true
        $Rtb.BorderStyle = "None"
        $Rtb.BackColor   = $Form.BackColor
        $Rtb.DetectUrls  = $false
        $Rtb.TabStop     = $false
        $Rtb.Location    = [System.Drawing.Point]::New(15, 15)
        $Rtb.Size        = [System.Drawing.Size]::New(530, 195)


        # Appends text to the end of the RichTextBox using the given
        # font and color
        $AddText = {
            param(
                [string]$Text,
                [System.Drawing.Font]$Font,
                [System.Drawing.Color]$Color
            )
            $Rtb.SelectionStart  = $Rtb.TextLength
            $Rtb.SelectionLength = 0
            $Rtb.SelectionFont   = $Font
            $Rtb.SelectionColor  = $Color
            $Rtb.AppendText($Text)
        }

        & $AddText "Hashing Complete`n`n"           $Fonts.Heading $Blue
        & $AddText "File hashed`n"                  $Fonts.Label   $Black
        & $AddText "$FileName`n`n"                  $Fonts.Value   $Black
        & $AddText "Verification File Name`n"       $Fonts.Label   $Black
        & $AddText "$VerificationFileName`n`n"      $Fonts.Value   $Black
        & $AddText "Verification File Saved in`n"   $Fonts.Label   $Black
        & $AddText $Directory                       $Fonts.Value   $Black

        $Rtb.SelectionStart = 0   # keep the view at the top

        $Button              = [System.Windows.Forms.Button]::New()
        $Button.Text         = "OK"
        $Button.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $Button.Size         = [System.Drawing.Size]::New(85, 30)
        $Button.Location     = [System.Drawing.Point]::New(460, 218)

        $Form.AcceptButton = $Button
        $Form.Controls.AddRange(@($Rtb, $Button))

        [void]$Form.ShowDialog()
    }
    finally {
        $Form.Dispose()
        foreach ($Font in $Fonts.Values) { $Font.Dispose() }
    }
}


function Format-Duration {
    <#
    .SYNOPSIS
        Converts a TimeSpan into short, readable text for console messages.

    .DESCRIPTION
        The layout depends on the length of the time span.  The invariant
        culture is always used so the output is the same on every computer.

            Under 1 minute    "12.50 seconds"
            Under 1 hour      "5 min 07 sec"
            1 hour or more    "2 hr 05 min 09 sec"

        Seconds are shown with two decimal places only for spans under
        one minute.  Longer spans show whole minutes and seconds (fractions
        of a second are dropped, not rounded).

    .PARAMETER Span
        The elapsed time to format, for example the Elapsed value of
        a Stopwatch.  This parameter is mandatory.

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
        None.  This function does not accept pipeline input.

    .OUTPUTS
        System.String.  The formatted duration.
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$Span
    )

    $Inv = [System.Globalization.CultureInfo]::InvariantCulture

    if ($Span.TotalSeconds -lt 60) {
        return [string]::Format(
            $Inv,
            "{0:N2} seconds",
            $Span.TotalSeconds
        )
    }

    if ($Span.TotalHours -lt 1) {
        return [string]::Format(
            $Inv,
            "{0} min {1:00} sec",
            $Span.Minutes,
            $Span.Seconds
        )
    }

    [string]::Format(
        $Inv,
        "{0} hr {1:00} min {2:00} sec", `
        [int][math]::Floor($Span.TotalHours),
        $Span.Minutes,
        $Span.Seconds
    )
}


function Get-MultiFileHash {
    <#
    .SYNOPSIS
        Calculates the MD5, SHA1 and SHA256 hashes of a file in a single read
        pass.

    .DESCRIPTION
        Opens the file once for sequential, read-only access and reads it in
        80 KB blocks.  Each block is passed to the MD5, SHA1 and SHA256
        algorithms, so the file is read from disk only once instead of three
        times (as would happen with three calls to 'Get-FileHash').

        The path is converted to a full path first.  If the file does not
        exist, a terminating error is thrown.  The file stream and the hash
        objects are always disposed, even when an error occurs.

    .PARAMETER FilePath
        Path to the file to hash. Wildcards are not supported.  A relative
        path is resolved against the process working directory, which may
        differ from the current PowerShell location.

    .EXAMPLE
        Get-MultiFileHash -FilePath "D:\Evidence\Laptop01.E01"

        Returns an object with the properties Path, MD5, SHA1 and SHA256.

    .EXAMPLE
        (Get-MultiFileHash -FilePath "D:\Evidence\Laptop01.E01").SHA256

        Returns only the SHA256 hash as an uppercase hexadecimal string.

    .INPUTS
        None.  This function does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject with these properties:
            Path    The full path of the file that was hashed.
            MD5     32-character uppercase hexadecimal string.
            SHA1    40-character uppercase hexadecimal string.
            SHA256  64-character uppercase hexadecimal string.

    .NOTES
        The file is opened with FileShare.Read, so the function fails if
        another process has the file open for writing.

        Hash values contain no dashes and are uppercase.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [switch]$AllowSharedWrite
    )

    <#
    Resolve against the PowerShell location (
    not [Environment]::CurrentDirectory).  The path is treated literally,
    so wildcard characters such as "[" or "]" in file names are not
    expanded.
    #>
    $ResolvedPath =$PSCmdlet.GetUnresolvedProviderPathFromPSPath($FilePath)
    if (-not (Test-Path -LiteralPath $ResolvedPath -PathType Leaf)) {
        throw "File not found: $ResolvedPath"
    }

    # Open a single FileStream with sequential scan optimization and
    # an 4 MB buffer
    $BufferSize = 4MB
    $ShareMode  = if ($AllowSharedWrite) {
        [System.IO.FileShare]::ReadWrite
    }
    else {
        [System.IO.FileShare]::Read
    }

    $FileStream = $null
    $Md5        = $null
    $Sha1       = $null
    $Sha256     = $null
    $Sha512     = $null

    try {
        <#
        Open a single FileStream with the sequential scan hint.  The
        FileStream's internal buffer is disabled (bufferSize = 1)
        because the data is read in large blocks into our own buffer.
        #>
        $FileStream = [System.IO.FileStream]::new(
            $ResolvedPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            $ShareMode,
            1,
            [System.IO.FileOptions]::SequentialScan
        )

        # Initialize the three hash algorithms
        $Md5    = [System.Security.Cryptography.MD5]::Create()
        $Sha1   = [System.Security.Cryptography.SHA1]::Create()
        $Sha256 = [System.Security.Cryptography.SHA256]::Create()
        $Sha512 = [System.Security.Cryptography.SHA512]::Create()

        $Buffer = [byte[]]::new($BufferSize)

        <#
        Read the file block-by-block and feed all three hashes. Passing
        '$null' as the output buffer stops .NET from copying every block
        onto itself.
        #>
        while (($BytesRead = $FileStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $null = $Md5.TransformBlock($Buffer, 0, $BytesRead, $null, 0)
            $null = $Sha1.TransformBlock($Buffer, 0, $BytesRead, $null, 0)
            $null = $Sha256.TransformBlock($Buffer, 0, $BytesRead, $null, 0)
            $null = $Sha512.TransformBlock($Buffer, 0, $BytesRead, $null, 0)
        }

        # Finalize the hashes (passing a 0-byte block since the stream is fully read)
        $null = $Md5.TransformFinalBlock($Buffer, 0, 0)
        $null = $Sha1.TransformFinalBlock($Buffer, 0, 0)
        $null = $Sha256.TransformFinalBlock($Buffer, 0, 0)
        $null = $Sha512.TransformFinalBlock($Buffer, 0, 0)

        # Convert the resulting byte arrays to uppercase hex strings (no dashes)
        [PSCustomObject]@{
            Path   = $ResolvedPath
            MD5    = [BitConverter]::ToString($Md5.Hash).Replace("-", "")
            SHA1   = [BitConverter]::ToString($Sha1.Hash).Replace("-", "")
            SHA256 = [BitConverter]::ToString($Sha256.Hash).Replace("-", "")
            SHA512 = [BitConverter]::ToString($Sha512.Hash).Replace("-", "")
        }
    }
    finally {
        # Clean up unmanaged streams and crypto objects
        if ($FileStream) { $FileStream.Dispose() }
        if ($Md5)        { $Md5.Dispose() }
        if ($Sha1)       { $Sha1.Dispose() }
        if ($Sha256)     { $Sha256.Dispose() }
        if ($Sha512)     { $Sha512.Dispose() }
    }
}
