# Script de Compilação PWA - Spartan App
# Execute este script para compilar o app para web

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SPARTAN APP - Compilação PWA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica se o Flutter está instalado
Write-Host "Verificando instalação do Flutter..." -ForegroundColor Yellow

$flutterFound = $false
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    if ($flutterVersion) {
        Write-Host "✓ Flutter encontrado!" -ForegroundColor Green
        Write-Host $flutterVersion -ForegroundColor Gray
        Write-Host ""
        $flutterFound = $true
    }
}
catch {
    Write-Host "✗ Flutter não encontrado no PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Por favor, adicione o Flutter ao PATH ou execute:" -ForegroundColor Yellow
    Write-Host "  C:\caminho\para\flutter\bin\flutter build web --release" -ForegroundColor White
    Write-Host ""
    exit 1
}

if (-not $flutterFound) {
    Write-Host "✗ Flutter não encontrado no PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Por favor, adicione o Flutter ao PATH ou execute:" -ForegroundColor Yellow
    Write-Host "  C:\caminho\para\flutter\bin\flutter build web --release" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Limpa builds anteriores
Write-Host "Limpando builds anteriores..." -ForegroundColor Yellow
if (Test-Path "build\web") {
    Remove-Item -Recurse -Force "build\web"
    Write-Host "✓ Build anterior removido" -ForegroundColor Green
}
Write-Host ""

# Executa flutter clean
Write-Host "Executando flutter clean..." -ForegroundColor Yellow
flutter clean
Write-Host "✓ Clean concluído" -ForegroundColor Green
Write-Host ""

# Obtém dependências
Write-Host "Obtendo dependências..." -ForegroundColor Yellow
flutter pub get
Write-Host "✓ Dependências obtidas" -ForegroundColor Green
Write-Host ""

# Compila para web
Write-Host "Compilando para WEB (modo release)..." -ForegroundColor Yellow
Write-Host "Isso pode levar alguns minutos..." -ForegroundColor Gray
Write-Host ""

flutter build web --release --web-renderer html

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✓ COMPILAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Arquivos gerados em: build\web" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Próximos passos:" -ForegroundColor Yellow
    Write-Host "  1. Testar localmente: cd build\web" -ForegroundColor White
    Write-Host "     Depois: python -m http.server 8000" -ForegroundColor White
    Write-Host "  2. Acessar: http://localhost:8000" -ForegroundColor White
    Write-Host "  3. Ver guia completo: GUIA_PWA_COMPLETO.md" -ForegroundColor White
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "✗ ERRO na compilação!" -ForegroundColor Red
    Write-Host "Verifique os erros acima e tente novamente." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
