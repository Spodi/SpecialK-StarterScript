<#

.SYNOPSIS
Starts an application and automatically starts and stops Special K's global injection with it.

.DESCRIPTION
This script will automatically start Special K's global injection and your defined app. After the app is closed it also automatically ends Special K's global injection. It also comes with a little wrapper batch, that will run this scrip more conveniently and is required to run this from Steam.

.NOTES 
If you want to use this within Steam follow these steps:
1)	Put the wrapper and script in Steams directory (the one with steam.exe)
2)	Set your app's launch options in Steam to SKSS.bat %command% <startup parameters> e.g. SKSS.bat %command% -ipv4. Steam replaces %command% with the full path to the started app and any launch option it itself uses (like connecting to a friends lobby).

You can also drag & Drop an executable at the wrapper batch.

Special K Starter Script
Created by Spodi

.EXAMPLE
SKSS.bat "D:\SteamLibrary\steamapps\common\Monster Hunter World\MonsterHunterWorld.exe" -ipv4 anotheroption

Starts MonsterHunterWorld.exe with launch options set to: -ipv4 anotheroption

Equivalent for launch options for Monster Hunter World in Steam:
SKSS.bat %command% -ipv4 anotheroption

.EXAMPLE
SKSS.bat "D:\SteamLibrary\steamapps\common\Monster Hunter World\MonsterHunterWorld.exe" -Test """Test""" -ipv4" 

Uses automatic whitelisting and starts MonsterHunterWorld.exe with launch options set to: -Test "Test" -ipv4 

Equivalent for launch options for Monster Hunter World in Steam:
SKSS.bat %command% -Test """Test""" -ipv4

.EXAMPLE
SKSS.bat "D:\SteamLibrary\steamapps\common\Monster Hunter World\MonsterHunterWorld.exe" -Whitelist -SK_AppParams "-SK_AutoStop """Test""" -ipv4" 

Starts MonsterHunterWorld.exe with launch options set to: -ipv4 -SK_AutoStop "Test"

No equivalent in Steam!

.PARAMETER SK_StartApp
[MANDATORY]
Specifies the App to Start
The parameter name (-SK_StartApp) can be omitted when used as the first parameter.

.PARAMETER SK_AppParams
Specifies startup parameters for the started app.
The parameter name (-SK_AppParams) can be omitted when used as the second parameter. When the name is omitted, any parameter not used by the script will be passed to the started app. If any parameter normally parsed by this script should be sent to the started app instead, the name can not be omitted.

Use tripple quotes (""") instead of normal ones ("), if your app needs them in its own parameters!

DON'T use the named version (-SK_AppParams) in Steams launch options! That will break, if Steam also adds parameters by itself (like connecting to a friends lobby)!

.PARAMETER SK_InstallPath
Specifies the path to your Special K installation.
This is the folder with SpecialK32.dll and SpecialK64.dll. System variables are working here. ${env:USERPROFILE} will be replaced with your user folder e.g. C:\Users\DonaldDuck.

When not specified the script checks the following places in this order: Working Directory, Script Root, default home dir of SK (Documents\My Mods\SpecialK\)
Edit $SK_InstallPath inside the Script file to override the default value (so you don't have to type this parameter every time).

.PARAMETER SK_InjectOther
Specifies the full path to a different directory (with trailing backslash "\") that should be injected . Whitelists this directory instead of the directory of the started app. Blacklists the directly started app.
Use this if the service stops prematurely because Special K activated in a launcher or if automatic whitelisting fails to pick the right folder.

.PARAMETER SK_AutoStop
- injected (Default)
Waits until the app and all child processes are closed instead waiting until Special K is active and rendered its first frame before closing this script. Useful if you're using this for a non-Steam game added to Steam and want to keep the game in your status. Steam ususally will only display you ingame, as long this window is open.

- Exit
Same as above, but also doesn't stop the injection service until the script ends. Keeps the service running even when the app is restarted trough Special K or the app itself. Useful when Special K activates in a launcher and the service stops prematurly or you have to regularly auto-restart the app.

.PARAMETER Service
- Start
Starts Special Ks global injection service.

- Restart
REstarts Special Ks global injection service.

- Stop
Stops Special Ks global injection service.

.PARAMETER SK_AsAdmin
Starts the service with elevated rights (Admin).

.PARAMETER SK_Help
Shows this help in a new window. Essentally the same as Get-Help <ScriptName> -ShowWindow.
Only works if called from a terminal.
#>
param([CmdletBinding(PositionalBinding = $false)]
	[Parameter(ParameterSetName = "AdminMode", Position = 0, Mandatory)]					[Parameter(ParameterSetName = "AutoMode", Position = 0, Mandatory)]						[string]	$SK_StartApp,
	[Parameter(ParameterSetName = "AdminMode", Position = 1, ValueFromRemainingArguments)]	[Parameter(ParameterSetName = "AutoMode", Position = 1, ValueFromRemainingArguments)]	[string[]]	$SK_AppParams,
	[Parameter(ParameterSetName = "AdminMode", Mandatory)]									[Parameter(ParameterSetName = "AutoMode")]												[string]	$SK_WorkingDirectory,
	[Parameter(ParameterSetName = "AdminMode")]												[Parameter(ParameterSetName = "AutoMode")]												[string]	$SK_InjectOther,
	[Parameter(ParameterSetName = "AdminMode")]												[Parameter(ParameterSetName = "AutoMode")]	[ValidateSet("Injected", "Exit")]			[string]	$SK_WaitFor,
	[Parameter(ParameterSetName = "AdminMode", Mandatory)]																															[switch]	$SK_AdminMode,
	#[Parameter(ParameterSetName = "ServiceControl", Mandatory)]																			[ValidateSet("Start", "Restart", "Stop")]	[string]	$SK_Service,
	[Parameter(ParameterSetName = "ServiceControl")]										[Parameter(ParameterSetName = "AutoMode")]												[switch]	$SK_AsAdmin,
	[Parameter(ParameterSetName = "ServiceControl")]										[Parameter(ParameterSetName = "AutoMode")]												[string]
	# ------------------------------ <SETTINGS> ------------------------------
	# Edit this to set a default value for the path to your Special K installation.
	# DEFAULT: $SK_InstallPath = [Environment]::GetFolderPath('MyDocuments') + '\My Mods\SpecialK'
	
	$SK_InstallPath = ''
	
	# Do NOT change anything below!
	# ------------------------------ </SETTINGS> -----------------------------
	,
	[Parameter(ParameterSetName = "Help")]																								[Alias("?", "h")]							[switch]	$Help
)

#region -------------------------- <FUNCTIONS> -----------------------------

function IsAdministrator {
	$Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
	$Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
function IsUacEnabled {
    (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).EnableLua -ne 0
}

#endregion ----------------------- </FUNCTIONS> ----------------------------

if ($SK_WorkingDirectory) {
	Set-Location $SK_WorkingDirectory
}
Write-Host (get-location).Path
Import-Module "$PSScriptRoot\SpecialK_CMDs.psm1"

Add-Type -Name ConsoleUtils -Namespace WPIA -MemberDefinition @'
   [DllImport("Kernel32.dll")]
   public static extern IntPtr GetConsoleWindow();
   [DllImport("user32.dll")]
   public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@
$ConsoleMode = @{
 HIDDEN    = 0;
 NORMAL    = 1;
 MINIMIZED = 2;
 MAXIMIZED = 3;
 SHOW      = 5
 RESTORE   = 9
}
$hWnd = [WPIA.ConsoleUtils]::GetConsoleWindow()

#Splash
Write-Host -NoNewline -ForegroundColor 'White' 'S'
Write-Host -NoNewline -ForegroundColor 'Gray' 'pecial '
Write-Host -NoNewline -ForegroundColor 'White' 'K '
Write-Host -NoNewline -ForegroundColor 'White' 'S'
Write-Host -NoNewline -ForegroundColor 'Gray' 'tarter '
Write-Host -NoNewline -ForegroundColor 'White' 'S'
Write-Host -ForegroundColor 'Gray' 'cript'
Write-Host 'v2.3.0
'

Write-Host -NoNewline -ForegroundColor 'White' 'S'
Write-Host -NoNewline -ForegroundColor 'Gray' 'pecial '
Write-Host -ForegroundColor 'White' 'K'

$Versions = Get-SkVersions -SkInstallPath $SK_InstallPath
Write-Host "32Bit v$(($Versions | Where-Object 'Name' -EQ 'SpecialK32.dll').ProductVersion) | 64Bit v$(($Versions | Where-Object 'Name' -EQ 'SpecialK64.dll').ProductVersion)
"
Remove-Variable 'Versions'

if (Get-SkTeardownStatus | Get-SkServiceProcess -SkInstallPath $SK_InstallPath) {
	$IsRunning = $true
}

if ($SK_AsAdmin) {
	if (!(IsAdministrator)) {
		if (IsUacEnabled) {
			[string[]]$argList = @('-NoLogo', '-ExecutionPolicy Bypass', "-File `"$PSCommandPath`"")
			
			if (!($SK_WorkingDirectory)) {
				$SK_WorkingDirectory = Get-Location
				$argList += "-SK_WorkingDirectory `"$SK_WorkingDirectory`""
			}
			$argList += '-SK_AdminMode'
			$argList += $MyInvocation.BoundParameters.GetEnumerator() | where-object -Property 'Key' -ne 'SK_AsAdmin' | ForEach-Object {
				If (($_.Value) -eq $true ) { "-$($_.Key)" } else { "-$($_.Key) `"$($_.Value)`"" }
			}
			$argList += $MyInvocation.UnboundArguments
			Write-Host 'Elevating Script...'
			[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.HIDDEN) | Out-Null
			[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.MINIMIZED) | Out-Null
			try {
			Start-Process PowerShell.exe -wait -Verb Runas -WorkingDirectory (get-location).Path -ArgumentList $argList -ErrorAction 'Stop'
			}
			finally {}
			[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.SHOW) | Out-Null
			[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.RESTORE) | Out-Null


			Write-Host 'Returned to normal privileges.'
		}
		else {
			THROW "You must be administrator to run this script with -SK_AsAdmin"
		}
	}
}

# Help pop-up, if there is no app to start
if ($SK_Help) {
	Get-Help -ShowWindow $PSCommandPath
	Write-Host 'Closing this will also close the help window.'
	Write-Host 'You can close this when you finished reading.'
	Pause
	EXIT 0
}
elseif ((! $SK_StartApp)) {
	Get-Help $PSCommandPath
	Pause
	EXIT 0
}

$SK_StartAppPath = (Split-Path $SK_StartApp -Parent)
if (! $SK_StartAppPath) {
	$SK_StartAppPath = (get-location).Path
}

if (! $SK_AsAdmin) {
	#only run if you don't spawn the second instance
	#Whitelist handling
	$WhitelistItem = $SK_StartAppPath
	if ($SK_InjectOther) {
		$WhitelistItem = $SK_InjectOther
		$BlacklistItem = $SK_StartAppPath
	}


	if ($WhitelistItem) {
		Write-Host 'Whitelisting' $WhitelistItem
		$WhitelistWritten = Add-SkList -Type 'allow' $WhitelistItem -SkInstallPath $SK_InstallPath
	}
	if ($BlacklistItem) {
		Write-Host 'Blacklisting' $BlacklistItem
		$BlacklistWritten = Add-SkList -Type 'deny' $BlacklistItem -SkInstallPath $SK_InstallPath
	}


	if ($SK_AdminMode -and $IsRunning) {
		Stop-SkService -SkInstallPath $SK_InstallPath
		Start-Sleep -Milliseconds 500
	}
	Write-Host 'Starting global injection service...'
	Start-SkService -SkInstallPath $SK_InstallPath


	Write-Host "Starting `"$SK_StartApp`" $SK_AppParams"

	Start-SkService -SkInstallPath $SK_InstallPath
	$jobInput = New-Object PSObject
	Add-Member -InputObject $jobInput -MemberType 'NoteProperty' -Name 'StartApp'		-Value $SK_StartApp
	Add-Member -InputObject $jobInput -MemberType 'NoteProperty' -Name 'StartAppPath'	-Value $SK_StartAppPath
	Add-Member -InputObject $jobInput -MemberType 'NoteProperty' -Name 'AppParams'		-Value $SK_AppParams
	Add-Member -InputObject $jobInput -MemberType 'NoteProperty' -Name 'WorkingDir'		-Value (Get-Location).Path

	$job = Start-Job -InputObject $jobInput -ScriptBlock {
		end {
			function Start-ProcessSK {
				<#
			.SYNOPSIS
			Just for simpler use later, because PS doesn't like empty arguments by deafult.
			#>
				param(
					[string][Parameter(Mandatory, Position = 0)]$FilePath,
					[string][Parameter(Position = 1)][AllowEmptyString()]$ArgumentList,
					[switch]$PassThru,
					[switch]$Wait,
					[string][AllowEmptyString()]$WorkingDirectory
				)
				if ($Wait -and $PassThru) {
					if ($ArgumentList -and $WorkingDirectory) { 
						Start-Process -Wait -PassThru -FilePath $FilePath -WorkingDirectory $WorkingDirectory -ArgumentList $ArgumentList
					}
					elseif ($ArgumentList) {
						Start-Process -Wait -PassThru -FilePath $FilePath -ArgumentList $ArgumentList
					}
					elseif ($WorkingDirectory) {
						Start-Process -Wait -PassThru -FilePath $FilePath -WorkingDirectory $WorkingDirectory
					}
					else {
						Start-Process -Wait -PassThru -FilePath $FilePath
					}
				}
				elseif ($Wait) {
					if ($ArgumentList -and $WorkingDirectory) { 
						Start-Process -Wait -FilePath $FilePath -WorkingDirectory $WorkingDirectory -ArgumentList $ArgumentList
					}
					elseif ($ArgumentList) {
						Start-Process -Wait -FilePath $FilePath -ArgumentList $ArgumentList
					}
					elseif ($WorkingDirectory) {
						Start-Process -Wait -FilePath $FilePath -WorkingDirectory $WorkingDirectory
					}
					else {
						Start-Process -Wait -FilePath $FilePath
					}
				}
				elseif ($PassThru) {
					if ($ArgumentList -and $WorkingDirectory) { 
						Start-Process -PassThru -FilePath $FilePath -WorkingDirectory $WorkingDirectory -ArgumentList $ArgumentList
					}
					elseif ($ArgumentList) {
						Start-Process -PassThru -FilePath $FilePath -ArgumentList $ArgumentList
					}
					elseif ($WorkingDirectory) {
						Start-Process -PassThru -FilePath $FilePath -WorkingDirectory $WorkingDirectory
					}
					else {
						Start-Process -PassThru -FilePath $FilePath
					}
				}
				else {
					if ($ArgumentList -and $WorkingDirectory) { 
						Start-Process -FilePath $FilePath -WorkingDirectory $WorkingDirectory -ArgumentList $ArgumentList
					}
					elseif ($ArgumentList) {
						Start-Process -FilePath $FilePath -ArgumentList $ArgumentList
					}
					elseif ($WorkingDirectory) {
						Start-Process -FilePath $FilePath -WorkingDirectory $WorkingDirectory
					}
					else {
						Start-Process -FilePath $FilePath
					}
				}
			}
			$data = $input | ConvertTo-Json | ConvertFrom-Json #Welp, input disappers after access. so there has to be a deep copy, as asigning a variable to another just creates a reference, that will also disappear
			Set-Location $data.WorkingDir
			Start-ProcessSK -wait -PassThru -FilePath $data.StartApp -WorkingDirectory $data.StartAppPath -ArgumentList $data.AppParams -ErrorAction 'Stop'
		}
	}
	[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.MINIMIZED) | Out-Null
	$jobcheck = $job | Get-Job
	if ($jobcheck.State -ne 'Failed') {
		Wait-SkAck -When $SK_WaitFor
	}

	if ((! $IsRunning) -or ($SK_AdminMode)) {
		Stop-SkService -SkInstallPath $SK_InstallPath

	}

	if ($SK_AdminMode) {
		$job | Wait-Job | Out-Null
		Start-Sleep -Milliseconds 500
	}
	[WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.RESTORE) | Out-Null
	if ($WhitelistWritten) {
		Write-Host 'Removing' $WhitelistItem 'from whitelist'
		Remove-SkList -Type 'allow' $WhitelistItem
	}
	if ($BlacklistWritten) {
		Write-Host 'Removing' $BlacklistItem 'from blacklist'
		Remove-SkList -Type 'allow' $BlacklistItem
	}


}
If (($IsRunning) -and (! $SK_AdminMode)) {
	Write-Host 'Restarting Service...'
	Start-SkService -SkInstallPath $SK_InstallPath
}
Write-Host '
Done!'
EXIT