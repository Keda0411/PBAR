Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
scriptPath = files.BuildPath(files.GetParentFolderName(WScript.ScriptFullName), "PBAR.ps1")
command = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File """ & scriptPath & """"
shell.Run command, 0, False
