# Limpar ambiente
Remove-Item -Path "output" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "output\Spartan_Desktop" -Force

# Copiar arquivos da build para a pasta organizadora
Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "output\Spartan_Desktop\" -Recurse -Force

# Renomear o executável para o padrão solicitado
if (Test-Path "output\Spartan_Desktop\spartan_app.exe") {
    Rename-Item -Path "output\Spartan_Desktop\spartan_app.exe" -NewName "Spartan Desktop.exe" -Force
}

# Garantir que a pasta de destino existe
if (-not (Test-Path "ultimo_zip")) {
    New-Item -ItemType Directory -Path "ultimo_zip" -Force
}

# Criar o arquivo ZIP na raiz primeiro para evitar problemas de path relativo no tar
Remove-Item -Path "Spartan_Desktop.zip" -Force -ErrorAction SilentlyContinue
tar -a -cf Spartan_Desktop.zip -C output Spartan_Desktop

# Mover para a pasta final 'ultimo_zip'
Move-Item -Path "Spartan_Desktop.zip" -Destination "ultimo_zip\Spartan_Desktop.zip" -Force

# Limpeza final
Remove-Item -Path "output" -Recurse -Force
Write-Output "Pronto! ultimo_zip\Spartan_Desktop.zip criado com sucesso."
