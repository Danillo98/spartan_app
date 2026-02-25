# Limpar ambiente
Remove-Item -Path "output" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "output\Spartan_Desktop" -Force

# Copiar arquivos da build para a pasta organizadora
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "output\Spartan_Desktop\" -Recurse -Force

# Renomear o executável caso esteja com o nome padrão do Flutter
if (Test-Path "output\Spartan_Desktop\spartan_app.exe") {
    Rename-Item -Path "output\Spartan_Desktop\spartan_app.exe" -NewName "Spartan Desktop.exe" -Force
}

# Criar o arquivo ZIP usando o comando tar (disponível no Windows para maior velocidade e estabilidade)
Remove-Item -Path "Spartan_Desktop.zip" -Force -ErrorAction SilentlyContinue
# -a: auto-detect output format by extension (.zip)
# -c: create
# -f: filename
# -C: change directory (to 'output' so we don't include the 'output' folder itself in the zip, just its content)
tar -a -cf Spartan_Desktop.zip -C output Spartan_Desktop

# Limpeza final
Remove-Item -Path "output" -Recurse -Force
Write-Output "Pronto! Spartan_Desktop.zip criado com sucesso usando tar (BSTar)."
