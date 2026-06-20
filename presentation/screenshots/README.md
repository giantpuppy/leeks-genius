# 截图规格清单

以下截图需要准备后替换到 `presentation.md` 中。

## 推荐截图方式

- 使用实机或模拟器截图
- 保持统一机型比例（推荐 iPhone 14 Pro / 类似比例）
- 截图后建议套一个手机壳 mockup（可在 Canva 中处理）
- 格式：PNG 或 JPG

## 截图清单

| 编号 | 用途 | 建议页面 | 文件名 |
|------|------|----------|--------|
| 01 | 封面 App 展示 | 月历首页 / 开屏页 | `home.png` |
| 02 | 用户场景拼贴 | 微信/大麦/小红书/日历拼贴 | `scenario.png` |
| 03 | 痛点流程 | 相册截图/日历截图拼贴 | `painpoint.png` |
| 04 | 排期板 | 排期板双密度视图 | `schedule_board.png` |
| 05 | 详情页 | 详情页 + 待办清单 | `detail_todo.png` |
| 06 | 个人中心 | 四张图表 dashboard | `profile_charts.png` |
| 07 | Logo + 色板 | Logo 拆解、紫绿色板 | `brand.png` |
| 08 | 核心界面 2×2 | 月历/排期板/详情/个人中心 | `screens_grid.png` |
| 09 | 技术架构 | 技术栈图标 / 架构图 | `architecture.png` |
| 10 | 二维码 | GitHub / Vercel 二维码 | `qrcode.png` |
| 11 | 团队 / 个人 | 头像 + 一句话 | `team.png` |

## 替换方式

在 `presentation.md` 中找到对应的占位块：

```markdown
<div class="placeholder">
  【截图位置】
  <br>排期板双密度视图
</div>
```

替换为 Marp 图片语法：

```markdown
![排期板双密度视图](screenshots/schedule_board.png)
```

或直接写 HTML：

```markdown
<img src="screenshots/schedule_board.png" width="80%" />
```

## 占位框说明

当前使用 CSS 占位框，导出时会显示「截图位置」提示文字。请尽量在导出前完成替换，避免正式版本出现占位文字。
