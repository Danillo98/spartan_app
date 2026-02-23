# Script de Deploy e Versionamento Spartan Desktop
$version = "2.0.3"
$zipName = "Spartan_Desktop.zip"
$storageUrl = "https://mcmxltjymjqqmshjmwdx.supabase.co/storage/v1/object/public/downloads/$zipName"

Write-Host "Iniciando Build para Windows (Release)..."
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no build do Flutter."
    exit 1
}

$buildPath = "build\windows\x64\runner\Release"
# Nome da pasta que aparecera dentro do ZIP
$folderInsideZip = "Spartan Desktop"

Write-Host "Preparando pasta de distribuicao..."
if (Test-Path $folderInsideZip) { Remove-Item -Recurse -Force $folderInsideZip }
New-Item -ItemType Directory -Path $folderInsideZip

# Copia os arquivos do build para a pasta organizadora
Copy-Item -Path "$buildPath\*" -Destination "$folderInsideZip" -Recurse
# Limpeza de arquivos de desenvolvimento/debug
Remove-Item -Path "$folderInsideZip\spartan_app.exp", "$folderInsideZip\spartan_app.lib", "$folderInsideZip\spartan_app.pdb" -ErrorAction SilentlyContinue

# IMPORTANTE: Remover o executavel duplicado/original para evitar confusao
# O CMake gera o "Spartan Desktop.exe", mas o Flutter as vezes deixa o "spartan_app.exe"
if (Test-Path "$folderInsideZip\spartan_app.exe") { 
    Remove-Item -Path "$folderInsideZip\spartan_app.exe" -Force 
}

# Gera o manifesto de versao
$versionJson = @{
    version = $version
    url     = $storageUrl
    notes   = "V2.0.3 - Filtro de perfil inteligente (QR Code), Liberação remota de catraca e melhorias de zoom na ficha de treino."
} | ConvertTo-Json

# Salva na raiz (para upload no Supabase)
$versionJson | Out-File -FilePath "version.json" -Encoding utf8

# TAMBEM COPIA para dentro da pasta que sera zipada (para monitoramento local)
$versionJson | Out-File -FilePath "$folderInsideZip\version.json" -Encoding utf8

Write-Host "Gerando arquivo ZIP com pasta organizadora e version.json incluso..."
if (Test-Path $zipName) { Remove-Item $zipName }
Compress-Archive -Path "$folderInsideZip" -DestinationPath "$zipName"

Write-Host "SUCESSO!"
Write-Host "Upload manual no Supabase Storage (Pasta: downloads):"
Write-Host "1. $zipName (Contem a pasta '$folderInsideZip' e o version.json interno)"
Write-Host "2. version.json (Manifesto para o servidor)"

# Limpa a pasta temporaria apos zipar
if (Test-Path $folderInsideZip) { Remove-Item -Recurse -Force $folderInsideZip }
