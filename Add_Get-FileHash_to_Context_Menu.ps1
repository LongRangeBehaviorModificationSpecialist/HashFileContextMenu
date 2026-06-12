# DLU : 19-May-2026


# Establish the root directory
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

# Define Destination Paths
$PSScriptDir = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\WindowsPowerShell"
$iconsDir   = Join-Path -Path $env:USERPROFILE -ChildPath "Pictures\icons"


function Test-Environment {
    <#
    .SYNOPSIS
        Check to see if the script is run with Administrative Privileges
    #>
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Administrative privileges required. Please run PowerShell as Administrator."
    }
    else {
        Write-Host "[-] Running as Administrator. Continuing with the process..." -ForegroundColor Green
    }
}


function Copy-PS1File {
    <#
    .SYNOPSIS
        Copies the `Get-FileHashValue.ps1` file to the `%USERPROFILE\Documents\WindowsPowerShell` folder
    #>
    # Handle Get-FileHashValue.ps1
    if (-not (Test-Path -Path $PSScriptDir)) {
        New-Item -Path $PSScriptDir -ItemType Directory -ErrorAction Stop | Out-Null
    }

    $file_hash_script = Join-Path -Path $root -ChildPath "files\Get-FileHashValue.ps1"
    Copy-Item -Path $file_hash_script -Destination $PSScriptDir -Force -ErrorAction Stop
    Write-Host "[-] File `Get-FileHashValue.ps1` was copied to $PSScriptDir" -ForegroundColor Cyan
}


function Copy-Icons {
    <#
    .SYNOPSIS
        Copies the three .ico files to the `%USERPROFILE%\Pictures\icons` folder
        If the folder does not exist, it will be created
    #>
    if (-not (Test-Path -Path $iconsDir)) {
        New-Item -Path $iconsDir -ItemType Directory -ErrorAction Stop | Out-Null
    }

    $image_folder = Join-Path -Path $root -ChildPath "img"
    $images       = Get-ChildItem -Path $image_folder -File -Filter *.ico

    foreach ($file in $images) {
        Copy-Item -Path $file.FullName -Destination $iconsDir -Force -ErrorAction Stop
        Write-Host "[-] Copied $($file.Name) to $iconsDir"
    }
}


function Import-HKCR {
    # Import the HKEY_CLASSES_ROOT registry hive if not already done

    try {
        if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
            $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Global
            Write-Host "[-] The HKEY_CLASSES_ROOT Path was added to the PSDrive list." -ForegroundColor Cyan
        }
        else {
            Write-Host "[-] The HKEY_CLASSES_ROOT Path is already added to the PSDrive list. Continuing with script..." -ForegroundColor Green
        }
    }
    catch {
        $errorMsg = "[!] An unknown error occurred when running '$($MyInvocation.MyCommand.Name)'. Error: $($_.Exception.Message)"
        Write-Host "$errorMsg" -ForegroundColor Red
    }
}


function Invoke-RegistryEdits {

    begin {
        Write-Host "[-] Starting `Invoke-RegistryEdits` function..." -ForegroundColor Green

        #$regPath = "HKCR:\*\Shell\GetFileHash"

        #if (-not (Test-Path $regPath)) {
        #New-Item -Path $regPath -Force | Out-Null
        #}

        $regKeyHashTable = [ordered]@{
            "Software\Classes\*\shell\GetFileHash"                                              = @{
                "Icon"        = ("ExpandString", '%USERPROFILE%\Pictures\icons\hashtag.ico')
                "MUIVerb"     = ("String", "Get File Hash")
                "SubCommands" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell"                                        = @{
                "" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5"                                  = @{
                "Icon"        = ("ExpandString", '%USERPROFILE%\Pictures\icons\hashtag.ico')
                "MUIVerb"     = ("String", "MD5")
                "SubCommands" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5\shell"                            = @{
                "" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5\shell\MD5-ToFile"                 = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\folder.ico')
                "MUIVerb" = ("String", "MD5 -> Save To File")
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5\shell\MD5-ToFile\command"         = @{
                "" = ("ExpandString", 'powershell.exe -NoExit %USERPROFILE%\Documents\WindowsPowerShell\Get-FileHashValue.ps1 "%L" MD5')
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5\shell\MD5-ToScreen"               = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\terminal.ico')
                "MUIVerb" = ("String", "MD5 -> Print To Screen")
            }
            "Software\Classes\*\shell\GetFileHash\shell\01MD5\shell\MD5-ToScreen\command"       = @{
                "" = ("String", 'powershell.exe -NoExit Get-FileHash -Path "%L" -Algorithm MD5 | Format-List')
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1"                                 = @{
                "Icon"        = ("ExpandString", '%USERPROFILE%\Pictures\icons\hashtag.ico')
                "MUIVerb"     = ("String", "SHA1")
                "SubCommands" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1\shell"                           = @{
                "" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1\shell\SHA1-ToFile"               = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\folder.ico')
                "MUIVerb" = ("String", "SHA1 -> Save To File")
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1\shell\SHA1-ToFile\command"       = @{
                "" = ("ExpandString", 'powershell.exe -NoExit %USERPROFILE%\Documents\WindowsPowerShell\Get-FileHashValue.ps1 "%L" SHA1')
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1\shell\SHA1-ToScreen"             = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\terminal.ico')
                "MUIVerb" = ("String", "SHA1 -> Print To Screen")
            }
            "Software\Classes\*\shell\GetFileHash\shell\02SHA1\shell\SHA1-ToScreen\command"     = @{
                "" = ("String", 'powershell.exe -NoExit Get-FileHash -Path "%L" -Algorithm SHA1 | Format-List')
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256"                               = @{
                "Icon"        = ("ExpandString", '%USERPROFILE%\Pictures\icons\hashtag.ico')
                "MUIVerb"     = ("String", "SHA256")
                "SubCommands" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256\shell"                         = @{
                "" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256\shell\SHA256-ToFile"           = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\folder.ico')
                "MUIVerb" = ("String", "SHA256 -> Save To File")
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256\shell\SHA256-ToFile\command"   = @{
                "" = ("ExpandString", 'powershell.exe -NoExit %USERPROFILE%\Documents\WindowsPowerShell\Get-FileHashValue.ps1 "%L" SHA256')
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256\shell\SHA256-ToScreen"         = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\terminal.ico')
                "MUIVerb" = ("String", "SHA256 -> Print To Screen")
            }
            "Software\Classes\*\shell\GetFileHash\shell\03SHA256\shell\SHA256-ToScreen\command" = @{
                "" = ("String", 'powershell.exe -NoExit Get-FileHash -Path "%L" -Algorithm SHA256 | Format-List')
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512"                               = @{
                "Icon"        = ("ExpandString", '%USERPROFILE%\Pictures\icons\hashtag.ico')
                "MUIVerb"     = ("String", "SHA512")
                "SubCommands" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512\shell"                         = @{
                "" = ("String", "")
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512\shell\SHA512-ToFile"           = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\folder.ico')
                "MUIVerb" = ("String", "SHA512 -> Save To File")
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512\shell\SHA512-ToFile\command"   = @{
                "" = ("ExpandString", 'powershell.exe -NoExit %USERPROFILE%\Documents\WindowsPowerShell\Get-FileHashValue.ps1 "%L" SHA512')
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512\shell\SHA512-ToScreen"         = @{
                "Icon"    = ("ExpandString", '%USERPROFILE%\Pictures\icons\terminal.ico')
                "MUIVerb" = ("String", "SHA512 -> Print To Screen")
            }
            "Software\Classes\*\shell\GetFileHash\shell\04SHA512\shell\SHA512-ToScreen\command" = @{
                "" = ("String", 'powershell.exe -NoExit Get-FileHash -Path "%L" -Algorithm SHA512 | Format-List')
            }
        }
    }
    process {
        # Open HKEY_LOCAL_MACHINE directly via standard Win32 security context
        $RegistryHive = [Microsoft.Win32.Registry]::LocalMachine

        foreach ($subKeyPath in $regKeyHashTable.Keys) {
            $entries = $regKeyHashTable[$subKeyPath]

            # SANITIZATION STEP:
            # 1. Trim removes accidental leading/trailing spaces
            # 2. Replace switches any accidental forward slashes to backslashes
            $cleanPath = $subKeyPath.Trim().Replace('/', '\')

            try {
                # Create SubKey natively using the sanitized path string
                $currentKey = $RegistryHive.CreateSubKey($cleanPath)
            }
            catch {
                throw "[!] Failed to create path: '$cleanPath'. Details: $_"
            }

            foreach ($propName in $entries.Keys) {
                $propType, $propValue = $entries[$propName]

                # Map your custom strings cleanly to [Microsoft.Win32.RegistryValueKind] enums
                $valueKind = if ($propType -eq "ExpandString") {
                    [Microsoft.Win32.RegistryValueKind]::ExpandString
                }
                else {
                    [Microsoft.Win32.RegistryValueKind]::String
                }

                # Set value natively
                $currentKey.SetValue($propName, $propValue, $valueKind)
            }

            # Safely close the unmanaged memory pointer handler
            if ($currentKey) { $currentKey.Close() }
            Write-Host "[+] Applied configuration safely to: $subKeyPath" -ForegroundColor Gray
        }

        Write-Host "[+] All registry operations completed successfully." -ForegroundColor Green
    }
}


function Add-FileExtAssociation {
    <#
    .SYNOPSIS
        Registers and forces .MD5, .SHA1, .SHA256, and .SHA512 extensions
        to open automatically using Notepad++.
    #>
    begin {
        Write-Host "[-] Configuring Notepad++ File Associations..." -ForegroundColor Green

        # Target hash extensions
        $extensions = @(".MD5", ".SHA1", ".SHA256", ".SHA512")

        # Establish a unique ProgID specific to Notepad++ for these types
        $progId = "Notepad++LogFile"

        # Detect the installation path of Notepad++ from the registry dynamically
        # Checks both 64-bit and 32-bit install vectors automatically
        $nppPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe" -ErrorAction SilentlyContinue).'(default)'

        # Fallback to standard installation paths if App Paths metadata isn't set
        if (-not $nppPath) {
            if (Test-Path "${env:ProgramFiles}\Notepad++\notepad++.exe") {
                $nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
            }
            elseif (Test-Path "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe") {
                $nppPath = "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
            }
        }

        # Halt if Notepad++ is completely missing from the target machine environment
        if (-not $nppPath) {
            throw "[!] Notepad++ was not detected on this machine. Please verify it is installed."
        }

        Write-Host "[+] Found Notepad++ executable at: $nppPath" -ForegroundColor Gray

        # Map out the standard Open Execution Verb structure for our custom ProgID
        # The '"%1"' variable tells Windows to pass the target file path directly into the application space
        $associationMap = [ordered]@{
            "Software\Classes\$progId"                    = @{
                "" = ("String", "Hash Log File")
            }
            "Software\Classes\$progId\shell\open\command" = @{
                "" = ("String", "`"$nppPath`" `"%1`"")
            }
        }
    }
    process {
        $RegistryHive = [Microsoft.Win32.Registry]::LocalMachine

        # Deploy the core application execution target maps
        foreach ($subKeyPath in $associationMap.Keys) {
            $entries = $associationMap[$subKeyPath]

            try {
                $currentKey = $RegistryHive.CreateSubKey($subKeyPath)
                foreach ($propName in $entries.Keys) {
                    $propType, $propValue = $entries[$propName]
                    $currentKey.SetValue($propName, $propValue, [Microsoft.Win32.RegistryValueKind]::String)
                }
                if ($currentKey) { $currentKey.Close() }
            }
            catch {
                throw "[!] Failed setting open execution handlers: $subKeyPath. Details: $_"
            }
        }

        # Loop through and re-route the extensions to target the new open schema
        foreach ($ext in $extensions) {
            try {
                $extKey = $RegistryHive.CreateSubKey("Software\Classes\$ext")
                $extKey.SetValue("", $progId, [Microsoft.Win32.RegistryValueKind]::String)
                $extKey.Close()
                Write-Host "[+] Associated $ext with Notepad++ successfully." -ForegroundColor Gray
            }
            catch {
                Write-Error "[!] Failed linking extension $ext. Details: $($_)"
            }
        }

        Write-Host "[+] All extensions mapped to open with Notepad++." -ForegroundColor Green
    }
}


# --- Execution Flow ---
try {
    Write-Host "[-] Starting Setup..." -ForegroundColor Cyan
    Test-Environment
    Copy-PS1File
    Copy-Icons
    # Import-HKCR
    Invoke-RegistryEdits
    Add-FileExtAssociation
}
catch {
    Write-Host "`n[!] ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host "`n[-] Script Workflow Complete!`n" -ForegroundColor Green
}
