# Script para Testar PWA Localmente - Spartan App
# Execute este script APÓS compilar o app (compilar_pwa.ps1)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SPARTAN APP - Servidor Local PWA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica se o build existe
if (-not (Test-Path "build\web\index.html")) {
    Write-Host "✗ Build não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Execute primeiro: .\compilar_pwa.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✓ Build encontrado!" -ForegroundColor Green
Write-Host ""

# Obtém o IP local
Write-Host "Obtendo endereço IP local..." -ForegroundColor Yellow
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" | Select-Object -First 1).IPAddress

if (-not $ipAddress) {
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like "192.168.*"} | Select-Object -First 1).IPAddress
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SERVIDOR INICIADO COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse no COMPUTADOR:" -ForegroundColor Yellow
Write-Host "  http://localhost:8000" -ForegroundColor White
Write-Host ""

if ($ipAddress) {
    Write-Host "Acesse no CELULAR (mesma rede Wi-Fi):" -ForegroundColor Yellow
    Write-Host "  http://${ipAddress}:8000" -ForegroundColor White
    Write-Host ""
}

Write-Host "Para INSTALAR o PWA:" -ForegroundColor Cyan
Write-Host "  Android: Menu (⋮) → 'Adicionar à tela inicial'" -ForegroundColor Gray
Write-Host "  iOS: Compartilhar (□↑) → 'Adicionar à Tela de Início'" -ForegroundColor Gray
Write-Host ""
Write-Host "Pressione Ctrl+C para parar o servidor" -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Inicia o servidor
Set-Location "build\web"

# Tenta usar Python
try {
    python -m http.server 8000
} catch {
    Write-Host ""
    Write-Host "✗ Python não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale o Python ou use outro método:" -ForegroundColor Yellow
    Write-Host "  1. Instalar Python: https://www.python.org/downloads/" -ForegroundColor White
    Write-Host "  2. Ou use: flutter run -d chrome --release" -ForegroundColor White
    Write-Host ""
}
