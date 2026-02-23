# Script de Deploy e Versionamento Spartan Desktop
$version = "1.0.7"
$zipName = "Spartan_Desktop.zip"
$storageUrl = "https://mcmxltjymjqqmshjmwdx.supabase.co/storage/v1/object/public/downloads/$zipName"

Write-Host "Iniciando Build para Windows (Release)..."
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no build do Flutter."
    exit 1
}

$buildPath = "build\windows\x64\runner\Release"
$tempPath = "SpartanDesktop"

Write-Host "Preparando pasta de distribuicao..."
if (Test-Path $tempPath) { Remove-Item -Recurse -Force $tempPath }
New-Item -ItemType Directory -Path $tempPath

Copy-Item -Path "$buildPath\*" -Destination "$tempPath" -Recurse
Remove-Item -Path "$tempPath\spartan_app.exp", "$tempPath\spartan_app.lib", "$tempPath\spartan_app.pdb" -ErrorAction SilentlyContinue

Write-Host "Gerando arquivo ZIP..."
if (Test-Path $zipName) { Remove-Item $zipName }
Compress-Archive -Path "$tempPath\*" -DestinationPath $zipName

$versionJson = @{
    version = $version
    url     = $storageUrl
    notes   = "Melhorias na estabilidade da catraca e novo modo Acesso Livre."
} | ConvertTo-Json

$versionJson | Out-File -FilePath "version.json" -Encoding utf8

Write-Host "SUCESSO!"
Write-Host "Upload manual no Supabase Storage (Pasta: downloads):"
Write-Host "1. $zipName"
Write-Host "2. version.json"

if (Test-Path $tempPath) { Remove-Item -Recurse -Force $tempPath }
