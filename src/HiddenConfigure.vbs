' Opens the MarkItDown settings GUI without flashing a console window.
Option Explicit
Dim scriptDir, configure, shell, cmd
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
configure = scriptDir & "Configure.ps1"
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & configure & """"
Set shell = CreateObject("WScript.Shell")
' 0 = hidden console; the WinForms window still shows. False = don't wait.
shell.Run cmd, 0, False
