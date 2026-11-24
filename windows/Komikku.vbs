' Starts Komikku without a console window.
' PYTHONHOME points the bundled Python at its own standard library.
Option Explicit
Dim sh, fso, root, q
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
q = Chr(34)

With sh.Environment("Process")
    .Item("PYTHONHOME") = root
    .Item("PATH") = root & "\bin;" & .Item("PATH")
End With
sh.CurrentDirectory = root
sh.Run q & root & "\bin\pythonw.exe" & q & " " & q & root & "\komikku-launcher.pyw" & q, 0, False
