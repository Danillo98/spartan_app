Remove-Item -Path "output" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "output\Motor Spartan" -Force
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "output\Motor Spartan\" -Recurse -Force
Rename-Item -Path "output\Motor Spartan\spartan_app.exe" -NewName "Motor Spartan.exe" -Force
Remove-Item -Path "Spartan_Motor_Catraca.zip" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path (Get-Location) 'output'), (Join-Path (Get-Location) 'Spartan_Motor_Catraca.zip'))
Remove-Item -Path "output" -Recurse -Force
Write-Output "Done creating Spartan_Motor_Catraca.zip with proper resolution icon!"
