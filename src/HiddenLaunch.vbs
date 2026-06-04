' Hidden launcher for the MarkItDown context menu.
' Starts pwsh running Launcher.ps1 with no visible console window.
' Args: 0 = mode (save|clip|open), 1 = target path
Option Explicit

Dim args, mode, target, scriptDir, launcher, shell, cmd
Set args = WScript.Arguments

If args.Count < 2 Then
    WScript.Quit 1
End If

mode = args(0)
target = args(1)

scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
launcher = scriptDir & "Launcher.ps1"

cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & launcher & """ " & mode & " """ & target & """"

Set shell = CreateObject("WScript.Shell")
' 0 = hidden window, False = do not wait for completion
shell.Run cmd, 0, False
