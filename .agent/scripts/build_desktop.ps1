# Script de Deploy e Versionamento Spartan Desktop
$version = "1.0.8"
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

Write-Host "Gerando arquivo ZIP com pasta organizadora..."
if (Test-Path $zipName) { Remove-Item $zipName }
# Ao passar a pasta diretamente (sem \*), o PowerShell inclui a pasta no ZIP
Compress-Archive -Path "$folderInsideZip" -DestinationPath "$zipName"

# Gera o manifesto de versao
$versionJson = @{
    version = $version
    url     = $storageUrl
    notes   = "Melhorias na estabilidade da catraca e novo modo Acesso Livre."
} | ConvertTo-Json

$versionJson | Out-File -FilePath "version.json" -Encoding utf8

Write-Host "SUCESSO!"
Write-Host "Upload manual no Supabase Storage (Pasta: downloads):"
Write-Host "1. $zipName (Este agora contem a pasta '$folderInsideZip')"
Write-Host "2. version.json (Use o arquivo da raiz do projeto)"

# Limpa a pasta temporaria apos zipar
if (Test-Path $folderInsideZip) { Remove-Item -Recurse -Force $folderInsideZip }
