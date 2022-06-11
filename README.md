# Special K Starter Script (SKSS)

## SYNOPSIS
Starts an application and automatically starts and stops Special K's global injection with it.

## DESCRIPTION
This script will automatically start Special K's global injection and your defined app. After the app is closed it also automatically ends Special K's global injection. It also comes with a little wrapper batch, that will run this scrip more conveniently and is required to run this from Steam.

## COMPONENT
Requires Module `SpecialK_PSLibrary`

## PARAMETER
### -SK_StartApp
**[MANDATORY]**\
Specifies the App to Start

The parameter name (`-SK_StartApp`) can be omitted when used as the first parameter.

### -SK_AppParams
Specifies startup parameters for the started app.

The parameter name (`-SK_AppParams`) can be omitted when used as the second parameter. When the name is omitted, any parameter not used by the script will be passed to the started app. If any parameter normally parsed by this script should be sent to the started app instead, the name can not be omitted.

Use tripple quotes (`"""`) instead of normal ones (`"`), if your app needs them in its own parameters!
DON'T use the named version (`-SK_AppParams`) in Steams launch options! That will break, if Steam also adds parameters by itself (like connecting to a friends lobby)!

### -SK_InstallPath
Specifies the path to your Special K installation.

This is the folder with `SpecialK32.dll` and `SpecialK64.dll`. System variables are working here. `${env:USERPROFILE}` will be replaced with your user folder e.g. C:\Users\DonaldDuck.

When not specified the script checks the following places in this order: Working Directory, Script Root, default home dir of SK (`Documents\My Mods\SpecialK\`)

That means you can just drop any verison of SK starting with `v22.4.7` in the same folder as the script or working path (usually the game) to use a different version of SK than SKIF (or another folder with this script). It's recommended to also drop the `Servlet` folder alongside the script (it technically works without).
Or edit `$SK_InstallPath` inside the Script file to override the default value (so you don't have to type this parameter every time).
### -SK_InjectOther
Specifies the full path to a different directory that should be injected. Whitelists this directory instead of the directory of the started app. Blacklists the directly started app.

Use this if the service stops prematurely because Special K activated in a launcher or if automatic whitelisting fails to pick the right folder.

### -SK_AutoStop
#### - injected (Default)
  Waits until the app and all child processes are closed instead waiting until Special K is active and rendered its first frame before closing this script. Useful if you're using this for a non-Steam game added to Steam and want to keep the game in your status. Steam ususally will only display you ingame, as long this window is open.

#### - Exit
  Same as above, but also doesn't stop the injection service until the script ends. Keeps the service running even when the app is restarted trough Special K or the app itself. Useful when Special K activates in a launcher and the service stops prematurly or you have to regularly auto-restart the app.

The console needs to be kept open until the started app exited, so it can actually stop the service.
### -SK_AsAdmin
Starts the service with elevated rights (Admin).

In this mode the console needs to be kept open when the service was already running until the started app exited to restart the service with normal privileges.
### -SK_AdminMode
Internal parameter that is used with `-SK_AsAdmin`.\
*Do **NOT** use this to start the script!*
### -SK_WorkingDirectory
Internal parameter that normally is used with `m-SK_AsAdmin`.\
You can use this to set the working directory of the script.
### -SK_Help
Shows this help in a new window. Essentally the same as `Get-Help <ScriptName> -ShowWindow`.\
Only works if called from a terminal.

## EXAMPLE
An example shortcut to start a game and SK as admin would look like this:\
Target: `C:\Users\Spodi\Scripts\SpecialK\SKSS\SKSS-reboot\SKSS.bat "unlockfps_clr.exe" -SK_AsAdmin`\
Start in: `"D:\Program Files\Genshin Impact"`
