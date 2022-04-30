function Get-SkPath {
	<#
	.SYNOPSIS
	Returns the a path of a Special K installation (if it includes SpecialK32.dll or SpecialK64.dll). Trhows an error otherwise.
	Checks the following places in this order: Working Directory, Script Root, default home dir of SK (Documents\My Mods\SpecialK\)
	.PARAMETER Path
	Returns the given path if it includes SpecialK32.dll or SpecialK64.dll. Gives an error otherwise.
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'LP', 'LiteralPath')]	[string[]]	$Path
	)

	if ($path) {
		If ((Test-Path -LiteralPath (Join-Path -Path $Path -ChildPath '\SpecialK64.dll') -PathType 'Leaf') -or (Test-Path -LiteralPath (Join-Path -Path $Path -ChildPath '.\SpecialK32.dll') -PathType 'Leaf')) {
			Write-Output $path
			return
		}
		else {
			Write-Error -Category 'ObjectNotFound' "The Path `"$Path`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
			return
		}
	}
	if ((Test-Path -LiteralPath '.\SpecialK64.dll' -PathType 'Leaf') -or (Test-Path -LiteralPath '.\SpecialK32.dll' -PathType 'Leaf')) {
		Write-Output (Get-Item '.')
		return
	}
	if ($PSScriptRoot) {
		if ((Test-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '.\SpecialK64.dll') -PathType 'Leaf') -or (Test-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '.\SpecialK32.dll') -PathType 'Leaf')) {
			Write-Output (Get-Item $PSScriptRoot)
			return
		}
	}
	if ((Test-Path -LiteralPath (Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath '.\My Mods\SpecialK\SpecialK64.dll') -PathType 'Leaf') -or (Test-Path -LiteralPath (Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath '.\My Mods\SpecialK\SpecialK32.dll') -PathType 'Leaf')) {
		Write-Output (Get-Item (Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath '\My Mods\SpecialK\'))
		return
	}
	Write-Error -Category 'ObjectNotFound' 'No valid Special K installation found.'
	return
}

function Get-SkTeardownStatus {
	<#
	.SYNOPSIS
	Returns an array of which teardown handles are aviailable (32, 64). Might also get handles when the injection service is not running, but SK is still injected in a process.
	#>
	$output = @()
	try {
		$SK_Event = [System.Threading.EventWaitHandle]::OpenExisting("Local\SK_GlobalHookTeardown32")
		$SK_Event.close()
		$output += [string]'32'
	}
	catch { }
	try {
		$SK_Event = [System.Threading.EventWaitHandle]::OpenExisting("Local\SK_GlobalHookTeardown64")
		$SK_Event.close()
		$output += [string]'64'
	}
	catch { }
	Write-Output $output
}

function Get-SkTeardown {
	<#
	.SYNOPSIS
	Gets the Teardown event handle of either 32 or 64Bit SK. Does NOT close the handle on its own! Use "-Timeout <Millisecons>" if you want to wait until the handle appears.
	
	.PARAMETER Timeout
	Timeout in milliseconds
	Waits until a handle is obtained or until the timeout has passed. Always rounds down to the nearest 250ms interval.
	
	.NOTES
	Does NOT close the handle on its own! Make sure you assign this to an object and use the .close() method, when you're done with the event (like "$obj.close()"). SK might not shut down correctly if this event isn't closed.
	If the .set() method is used on the handle SKs will try to shutdown and remove itself from any process that it is not fully active. 
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline, Mandatory)][ValidateSet('32', '64')]	[string]	$Bitness,
		[Parameter()]														[int]		$Timeout
	)

	begin {
		$output = @()
	}

	process {
		if ($Timeout) {
			$times = [math]::Truncate($Timeout / 250)
			$i = 0
			while ($i -le $times) {
				Try {
					$SK_Event = [System.Threading.EventWaitHandle]::OpenExisting("Local\SK_GlobalHookTeardown$Bitness")
					$output += $SK_Event
					break
				}
				Catch {
					$i++
					Start-Sleep -Milliseconds "250"
				}
			}
		}
		else {
			Try {
				$SK_Event = [System.Threading.EventWaitHandle]::OpenExisting("Local\SK_GlobalHookTeardown$Bitness")
				$output += $SK_Event
			}
			Catch { }
		}
	}

	end {
		Write-Output $output
	}
}

function Get-SkServiceProcess {
	<#
	.SYNOPSIS
	Returns a process object of an active service. Only works if the service was started from the current SkPath (see Get-SkPath). Use "-Timeout <Millisecons>" if you want to wait until the process appears.
	.PARAMETER Bitness
	Defines the Bitness (32, 64) of the service to get.
	.PARAMETER Timeout
	Timeout in milliseconds
	Waits until a process is obtained or until the timeout has passed. Always rounds down to the nearest 250ms interval.
	.PARAMETER SkInstallPath
	Defines an alternative path to an SkPath that was started.
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline, Position = 0, Mandatory)][ValidateSet('32', '64')]			[string]	$Bitness,
		[Parameter()]																				[int]		$Timeout,
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)

	begin {
		$output = @()
		try {
			$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
		}
		catch {
			Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
			break
		}

	}

	process {
		$Path = (Join-Path -Path $InstallPath -ChildPath "\Servlet\SpecialK$($Bitness).pid")
		
		if ($Timeout) {
			$times = [math]::Truncate($Timeout / 250)
			$i = 0
			while ($i -le $times) {
				Try {
					$ID = Get-Content -LiteralPath $Path -ErrorAction 'Stop'
					$Process = Get-Process -ID $ID -ErrorAction 'Stop'
					$output += $Process
					break
				}
				Catch {
					$i++
					Start-Sleep -Milliseconds "250"
				}
			}
		}
		else {
			if (Test-Path -LiteralPath $Path) {
				try {
					$ID = Get-Content -LiteralPath $Path
					$Process = Get-Process -ID $ID -ErrorAction 'Stop'
				}
				catch [Microsoft.PowerShell.Commands.ProcessCommandException] {}
				$output += $Process
			}
		}
			
	}

	end {
		Write-Output $output
	}
}

function Wait-SkAck {
	<#
	.SYNOPSIS
	Waits until Special K sends it's ack event. Without a timeout this command will wait indefinitely.

	.PARAMETER When
	Defines what type of event to wait for.
	
	- Injected
	This event is send as soon SK is active and rendered it's first frame.

	- Exit
	This event is send when an active SK session is shut down (game closed). This has to be listened to for before the shut down, or it is never fired by SK!
	
	.PARAMETER Timeout
	Timeout in milliseconds
	When a timeout is set this command will only wait the specified duration and return $true if the event was fired and nothing if it wasn't. Without a timeout this command will wait indefinitely.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)][AllowEmptyString()][ValidateSet('Injected', 'Exit', '')]	[string]	$When,
		[Parameter()]											[int]		$Timeout
	)

	if ($When -ne 'Exit') {
		$handle = New-Object -TypeName System.Threading.EventWaitHandle -ArgumentList $false, AutoReset, 'Local\SKIF_InjectAck'
		if ($Timeout) {
			$output = $handle.WaitOne($Timeout)
		}
		else {
			$handle.WaitOne() | Out-Null
		}
		$handle.Close()
		return $output
	}
	else {
		$handle = New-Object -TypeName System.Threading.EventWaitHandle -ArgumentList $false, AutoReset, 'Local\SKIF_InjectExitAck'
		if ($Timeout) {
			$output = $handle.WaitOne($Timeout)
		}
		else {
			$handle.WaitOne() | Out-Null
		}
		$handle.Close()
		return $output
	}
}

Function Start-SkService {
	<#
	.SYNOPSIS
	Starts the SK injection service in the current SkPath (see Get-SkPath).

	.PARAMETER SkInstallPath
	Defines an alternative path to an SkPath.
	#>
	param (
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)
	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	$ServletPath = (Join-Path -Path $InstallPath -ChildPath 'Servlet')
	$SK32 = (Join-Path -Path $InstallPath -ChildPath '\SpecialK32.dll')
	$SK64 = (Join-Path -Path $InstallPath -ChildPath '\SpecialK64.dll')


	if (Test-Path -LiteralPath $SK32) {
		If (Test-Path -LiteralPath "$ServletPath\SKIFsvc32.exe" -PathType leaf) {
			Write-Information 'Starting 32Bit service (SKIF Standalone)...'
			Start-Process -FilePath "$ServletPath\SKIFsvc32.exe" -WorkingDirectory $ServletPath -ArgumentList "Start"
		}
		else {
			$rundll = Join-Path -Path ([Environment]::GetFolderPath('SystemX86')) 'rundll32.exe'
			If (Test-Path -LiteralPath "$rundll" -PathType leaf) {
				Write-Information 'Starting 32Bit service (Rundll32)...'
				Start-Process -FilePath $rundll -WorkingDirectory $ServletPath -ArgumentList "`"$SK32`", RunDLL_InjectionManager Install"
			}
			else {
				Write-Error -Category 'ObjectNotFound' 'No SKIFsvc32.exe or 32-Bit rundll32.exe found. Your system seems broken...'
				return
			}
		}
		$SK_Event32 = Get-SkServiceProcess -Bitness '32' -Timeout '10000'
		if (! $SK_Event32) {
			if (Get-SkTeardownStatus -contains '32' ) {
				Write-Error 'Failed to start 32-bit Service (Timeout), but another instance might be running or SK is still stuck somewhere.'
			}
			else {
				Write-Error 'Failed to start 32-bit Service (Timeout)'
			}
		}
		else {
			Write-Information 'Success'
		}
	}

 if ([Environment]::Is64BitOperatingSystem) {
		if (Test-Path -LiteralPath $SK64) {
			If (Test-Path -LiteralPath "$ServletPath\SKIFsvc64.exe" -PathType 'Leaf') {
				Write-Information 'Starting 64Bit service (SKIF Standalone)...'
				Start-Process -FilePath "$ServletPath\SKIFsvc64.exe" -WorkingDirectory $ServletPath -ArgumentList "Start"
			}
			else {
				$rundll = Join-Path -Path ([Environment]::GetFolderPath('System')) 'rundll32.exe'
				If (Test-Path -LiteralPath "$rundll" -PathType 'Leaf') {
					Write-Information 'Starting 64Bit service (Rundll32)...'
					Start-Process -FilePath $rundll -WorkingDirectory $ServletPath -ArgumentList "`"$SK64`", RunDLL_InjectionManager Install"
				}
				else {
					Write-Error -Category 'ObjectNotFound' 'No SKIFsvc64.exe or 64Bit rundll32.exe found. Your system seems broken...'
					return
				}
			}
			$SK_Event64 = Get-SkServiceProcess -Bitness '64' -Timeout '10000'
			if (! $SK_Event64) {
				if (Get-SkTeardownStatus -contains '64' ) {
					Write-Error 'Failed to start 64bit Service (Timeout), but another instance might be running or SK is still stuck somewhere.'
				}
				else {
					Write-Error 'Failed to start 64bit Service (Timeout)'
				}
			}
			else {
				Write-Information 'Successfully started 64-bit Service'
			}
		}
	}
	Start-Sleep -Milliseconds '30' #This is to prevent race conditions
}

Function Stop-SkService {
	<#
	.SYNOPSIS
	Stops any active SK injection service.
	#>
	param (
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)
	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	$ServletPath = (Join-Path -Path $InstallPath -ChildPath 'Servlet')
	$SK32 = (Join-Path -Path $InstallPath -ChildPath '\SpecialK32.dll')
	$SK64 = (Join-Path -Path $InstallPath -ChildPath '\SpecialK64.dll')


	if (Test-Path -LiteralPath $SK32) {
		If (Test-Path -LiteralPath "$ServletPath\SKIFsvc32.exe" -PathType leaf) {
			Write-Information 'Stopping 32Bit service (SKIF Standalone)...'
			Start-Process -FilePath "$ServletPath\SKIFsvc32.exe" -WorkingDirectory $ServletPath -ArgumentList "Stop"
		}
		else {
			$rundll = Join-Path -Path ([Environment]::GetFolderPath('SystemX86')) 'rundll32.exe'
			If (Test-Path -LiteralPath $rundll -PathType leaf) {
				Write-Information 'Stopping 32Bit service (Rundll32)...'
				Start-Process -FilePath $rundll -WorkingDirectory $ServletPath -ArgumentList "`"$SK32`", RunDLL_InjectionManager Remove"
			}
			else {
				Write-Error -Category 'ObjectNotFound' 'No SKIFsvc32.exe or 32-Bit rundll32.exe found. Your system seems broken...'
				return
			}
		}
	}
	
	if ([Environment]::Is64BitOperatingSystem) {
		if (Test-Path -LiteralPath $SK64) {
			If (Test-Path -LiteralPath "$ServletPath\SKIFsvc64.exe" -PathType 'Leaf') {
				Write-Information 'Stopping 64Bit service (SKIF Standalone)...'
				Start-Process -FilePath "$ServletPath\SKIFsvc64.exe" -WorkingDirectory $ServletPath -ArgumentList "Stop"
			}
			else {
				$rundll = Join-Path -Path ([Environment]::GetFolderPath('System')) 'rundll32.exe'
				If (Test-Path -LiteralPath $rundll -PathType 'Leaf') {
					Write-Information 'Stopping 64Bit service (Rundll32)...'
					Start-Process -FilePath $rundll -WorkingDirectory $ServletPath -ArgumentList "`"$SK64`", RunDLL_InjectionManager Remove"
				}
				else {
					Write-Error -Category 'ObjectNotFound' 'No SKIFsvc64.exe or 64-Bit rundll32.exe found. Your system seems broken...'
					return
				}
			}
		}
	}

	Start-Sleep -Milliseconds '30' #This is to prevent race conditions
}

function Get-SkList {


	[CmdletBinding(PositionalBinding = $false)]
	param (
		[Parameter(Mandatory)][ValidateSet('white', 'black', 'allow', 'deny')]	[string]	$Type,
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)

	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	if (($Type -eq 'white') -or (($Type -eq 'allow'))) {
		$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\whitelist.ini')
	}
	else {
		$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\blacklist.ini')
	}
	if (Test-Path -LiteralPath $Path) {
		$output = Get-Content $Path
		Write-Output $output
	}
	else {
		#Write-Error -Category 'ObjectNotFound' "`"$Path`" not found."
	}
}

function Add-SkList {
	<#
	.SYNOPSIS
	Writes an entry in the white/blacklist of the current SkPath (see Get-SkPath). Paths that are whitelisted by default in SK will be ignored.

	.PARAMETER Value
	Defines the text to write in the list. Special characters are automatically escaped unless the "-Raw" switch is used.

	.PARAMETER Type
	Defines which list the value is added to. Allowed types are 'allow' or 'white' for whitelisting and 'deny' or 'black' for blacklisting.

	.PARAMETER Raw
	Special regex characters in the string won't be escaped. Use this if you actually want to write an regex expression and not an exact match.

	.PARAMETER SkInstallPath
	Defines an alternative path to an SkPath.
	#>
	[CmdletBinding(PositionalBinding = $false)]
	param (
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]	[string]	$Value,
		[Parameter(Mandatory)][ValidateSet('white', 'black', 'allow', 'deny')]						[string]	$Type,
		[Parameter()]																				[switch]	$Raw,
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)

	Process {
		try {
			$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
		}
		catch {
			Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
			break
		}
		if (($Type -eq 'white') -or (($Type -eq 'allow'))) {
			$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\whitelist.ini')
			if (($Value -like '*SteamApps*') -or ($Value -like '*Epic Games\*') -or ($Value -like '*GOG Galaxy\Games*') -or ($Value -like '*Origin Games\*')) {
				Write-Warning 'Ignoring entry, as this path is already whitelisted by default in Special K.'
				return
			}
		}
		else {
			$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\blacklist.ini')
		}
		if (! (Test-Path -LiteralPath $Path -PathType 'Leaf')) {
			Write-Warning "`"$Path`" does not exist and will be created."
			$parent = -LiteralPath (Split-Path $Path -Parent)
			if (! (Test-Path $parent -PathType 'Container')) {
				New-Item $parent -ItemType 'Directory'
			}
			New-Item $Path -ItemType 'File'
		}

		if (! $Raw) {
			$Value = ($Value -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1')	#escaping all special chars in regex \blah.exe -> \\blah\.exe (matches "\blah.exe")
		}

		$CompareReg = ($Value -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1')	# \\blah\.exe -> \\\\blah\\.exe (matches "\\blah\.exe")
		$CompareResult = Get-Content -Encoding 'utf8' -LiteralPath $Path | Where-Object { $_ -match $CompareReg }
		if (! $CompareResult) {
			Write-Information "Adding $Value"
			Add-Content -Encoding 'utf8' -LiteralPath $Path -Value "`r`n$Value" -NoNewline
			$Success = $true
		}
	}
	end { Write-Output $Success }
}

function Remove-SkList {
	<#
	.SYNOPSIS
	Removes an entry in the white/blacklist of the current SkPath (see Get-SkPath).

	.PARAMETER Value
	Defines the value to remove in the list. Special characters are automatically escaped unless the "-Regex" switch is used.

	.PARAMETER Type
	Defines which list the value is removed from. Allowed types are 'allow' or 'white' for whitelisting and 'deny' or 'black' for blacklisting.

	.PARAMETER Raw
	Special regex characters in the string won't be escaped. Use this if you want to remove an regex entry that was previously added with the "-Raw" parameter.

	.PARAMETER SkInstallPath
	Defines an alternative path to an SkPath.
	#>
	[CmdletBinding(PositionalBinding = $false)]
	param (
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]	[string]	$Value,
		[Parameter(Mandatory)][ValidateSet('white', 'black', 'allow', 'deny')]						[string]	$Type,
		[Parameter()]																				[switch]	$Raw,
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)

	Process {
		try {
			$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
		}
		catch {
			Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
			break
		}
		if (($Type -eq 'white') -or (($Type -eq 'allow'))) {
			$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\whitelist.ini')
		}
		else {
			$Path = (Join-Path -Path $InstallPath -ChildPath '\Global\blacklist.ini')
		}
		
		if (! $Raw) {
			$Value = ($Value -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1')   # \\blah\.exe -> \\\\blah\\.exe (matches "\\blah\.exe")
		}

		$Content = Get-Content -Encoding 'utf8' -LiteralPath $Path | Where-Object { ($_ -ne $Value) -and ($_ -ne '') }
		$Content = $Content -join "`r`n"	#add nweline after eacht object, but get rid of the newline at the end of file
		Write-Information "Removing $Value"
		#Set-Content -Encoding 'utf8' -LiteralPath $Path -Value $Content -NoNewline
		[System.IO.File]::WriteAllLines($Path, $Content)	#Workaround for powsh 5.1, so no BOM is written
	}
}

function Get-SkVersions {
	param (
		[Parameter(ValueFromPipelineByPropertyName)][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)
	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	#[System.IO.Directory]::EnumerateFiles($_, 'SpecialK*.dll', 'TopDirectoryOnly')
	Get-ChildItem -LiteralPath $InstallPath -Filter "SpecialK*.dll" -Depth 0 `
	| Select-Object -Property 'Name', 'BaseName' -ExpandProperty 'VersionInfo' `
	| Where-Object -Property 'ProductName' -EQ 'Special K' `
	| Select-Object -Property 'Name', 'BaseName', 'ProductVersion' `
	| Write-Output
}

function Set-SkToAVX {
	param (
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)
	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	$SK32AVX = Join-Path $InstallPath '\SpecialK32-AVX2.dll'
	$SK64AVX = Join-Path $InstallPath '\SpecialK64-AVX2.dll'
	$SK32 = Join-Path $InstallPath '\SpecialK32.dll'
	$SK64 = Join-Path $InstallPath '\SpecialK64.dll'
	$SK32SSE = Join-Path $InstallPath '\SpecialK32-SSE.dll'
	$SK64SSE = Join-Path $InstallPath '\SpecialK64-SSE.dll'
	
	If ((Test-Path -LiteralPath $SK32 -PathType 'Leaf') -and (Test-Path -LiteralPath $SK32AVX -PathType 'Leaf')) {
		if (Test-Path -LiteralPath $SK32SSE -PathType 'Leaf') {
			Remove-Item -LiteralPath $SK32SSE
		}
		Rename-Item -LiteralPath $SK32 (Split-Path $SK32SSE -Leaf)
		Rename-Item -LiteralPath $SK32AVX (Split-Path $SK32 -Leaf)
	}

	If ((Test-Path -LiteralPath $SK64 -PathType 'Leaf') -and (Test-Path -LiteralPath $SK64AVX -PathType 'Leaf')) {
		if (Test-Path -LiteralPath $SK64SSE -PathType 'Leaf') {
			Remove-Item -LiteralPath $SK64SSE
		}
		Rename-Item -LiteralPath $SK64 (Split-Path $SK64SSE -Leaf)
		Rename-Item -LiteralPath $SK64AVX (Split-Path $SK64 -Leaf)
	}
}

function Set-SkToSSE {
	param (
		[Parameter(ValueFromPipelineByPropertyName)][AllowEmptyString()][Alias('PSPath', 'Path')]	[string]	$SkInstallPath
	)
	try {
		$InstallPath = Get-SkPath $SkInstallPath -ErrorAction 'Stop'
	}
	catch {
		Write-Error -Category 'ObjectNotFound' "The Path `"$SkInstallPath`" is no valid Special K installation. No SpecialK32.dll or SpecialK64.dll was found."
		return
	}

	$SK32AVX = Join-Path $InstallPath '\SpecialK32-AVX2.dll'
	$SK64AVX = Join-Path $InstallPath '\SpecialK64-AVX2.dll'
	$SK32 = Join-Path $InstallPath '\SpecialK32.dll'
	$SK64 = Join-Path $InstallPath '\SpecialK64.dll'
	$SK32SSE = Join-Path $InstallPath '\SpecialK32-SSE.dll'
	$SK64SSE = Join-Path $InstallPath '\SpecialK64-SSE.dll'

	If ((Test-Path -LiteralPath $SK32 -PathType 'Leaf') -and (Test-Path -LiteralPath $SK32SSE -PathType 'Leaf')) {
		if (Test-Path -LiteralPath $SK32AVX -PathType 'Leaf') {
			Remove-Item -LiteralPath $SK32AVX
		}
		Rename-Item -LiteralPath $SK32 (Split-Path $SK32AVX -Leaf)
		Rename-Item -LiteralPath $SK32SSE (Split-Path $SK32 -Leaf)
	}
	
	If ((Test-Path -LiteralPath $SK64 -PathType 'Leaf') -and (Test-Path -LiteralPath $SK64SSE -PathType 'Leaf')) {
		if (Test-Path -LiteralPath $SK64AVX -PathType 'Leaf') {
			Remove-Item -LiteralPath $SK64AVX
		}
		Rename-Item -LiteralPath $SK64 (Split-Path $SK64AVX -Leaf)
		Rename-Item -LiteralPath $SK64SSE (Split-Path $SK64 -Leaf)
	}
}