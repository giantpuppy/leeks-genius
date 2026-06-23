#!/bin/bash
if [ ! -d "flutter_sdk" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter_sdk
fi
export PATH="$PATH:$PWD/flutter_sdk/bin"
flutter config --no-analytics
flutter config --enable-web
# 使用 WASM 构建，Vercel 配置了跨域头支持 Skwasm 渲染器
# Skwasm 比 CanvasKit 小约 40%，手机加载更快
flutter build web --release --wasm

# 移除空的 build 项，避免加载器选错
sed -i 's/,{}//g' build/web/flutter_bootstrap.js
