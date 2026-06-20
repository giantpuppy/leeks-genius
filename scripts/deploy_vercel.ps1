# 本地构建并部署到 Vercel
# 用法：右键以 PowerShell 运行，或在终端执行 .\scripts\deploy_vercel.ps1

$ErrorActionPreference = "Stop"

Write-Host "🚀 正在构建 Flutter Web..." -ForegroundColor Cyan
flutter build web --release

Write-Host "🌐 正在部署到 Vercel..." -ForegroundColor Cyan
npx vercel deploy --prod build/web

Write-Host "✅ 部署完成" -ForegroundColor Green
