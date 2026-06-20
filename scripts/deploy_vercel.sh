#!/usr/bin/env bash
# 本地构建并部署到 Vercel
# 用法：bash scripts/deploy_vercel.sh

set -e

echo "🚀 正在构建 Flutter Web..."
flutter build web --release

echo "🌐 正在部署到 Vercel..."
npx vercel deploy --prod build/web

echo "✅ 部署完成"
