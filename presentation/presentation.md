---
marp: true
theme: default
paginate: true
backgroundColor: '#0F0F0F'
color: '#FFFFFF'
class: invert
style: |
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;700;900&display=swap');

  :root {
    --color-background: #0F0F0F;
    --color-foreground: #FFFFFF;
    --color-purple: #8B5CF6;
    --color-green: #34D399;
    --color-gray: #B0B0B0;
  }

  section {
    font-family: 'Noto Sans SC', sans-serif;
    background-color: #0F0F0F;
    color: #FFFFFF;
    padding: 60px;
  }

  h1 {
    color: #8B5CF6;
    font-weight: 900;
    font-size: 2.8em;
    margin-bottom: 0.3em;
  }

  h2 {
    color: #34D399;
    font-weight: 700;
    font-size: 1.8em;
    margin-top: 0;
  }

  h3 {
    color: #FFFFFF;
    font-weight: 700;
  }

  strong {
    color: #34D399;
  }

  code {
    background-color: #1A1A1A;
    color: #34D399;
    padding: 2px 6px;
    border-radius: 4px;
  }

  ul li::marker {
    color: #8B5CF6;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9em;
  }

  th {
    background-color: #8B5CF6;
    color: #FFFFFF;
    padding: 12px;
    text-align: left;
  }

  td {
    border-bottom: 1px solid #333;
    padding: 12px;
    color: #E0E0E0;
  }

  tr:nth-child(even) {
    background-color: #1A1A1A;
  }

  section.lead {
    text-align: center;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
  }

  .lead h1 {
    font-size: 4em;
    margin-bottom: 0.2em;
  }

  .lead p {
    font-size: 1.4em;
    color: #B0B0B0;
  }

  .slogan {
    color: #34D399;
    font-size: 1.6em;
    font-weight: 700;
    margin-top: 1em;
  }

  .tagline {
    color: #8B5CF6;
    font-size: 1.2em;
    font-weight: 700;
    letter-spacing: 0.1em;
  }

  .placeholder {
    background-color: #1A1A1A;
    border: 2px dashed #8B5CF6;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #8B5CF6;
    font-size: 1.2em;
    font-weight: 700;
    min-height: 300px;
    text-align: center;
  }

  .placeholder-small {
    min-height: 180px;
  }

  .two-column {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 40px;
    align-items: center;
  }

  .two-column-wide {
    display: grid;
    grid-template-columns: 1.2fr 0.8fr;
    gap: 40px;
    align-items: center;
  }

  .three-column {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 24px;
    margin-top: 30px;
  }

  .card {
    background-color: #1A1A1A;
    border-radius: 16px;
    padding: 24px;
    border-left: 4px solid #8B5CF6;
  }

  .card h3 {
    color: #34D399;
    margin-top: 0;
    font-size: 1.3em;
  }

  .card p {
    color: #E0E0E0;
    line-height: 1.6;
  }

  .painpoint-card {
    background-color: #1A1A1A;
    border-radius: 12px;
    padding: 20px 24px;
    margin-bottom: 16px;
    border-left: 4px solid #8B5CF6;
  }

  .painpoint-card h3 {
    color: #34D399;
    margin-top: 0;
    margin-bottom: 8px;
  }

  .painpoint-card p {
    margin: 0;
    color: #E0E0E0;
  }

  footer {
    color: #666;
    font-size: 0.7em;
  }

  .page-number {
    color: #8B5CF6;
  }

  blockquote {
    font-size: 1.2em;
    color: #B0B0B0;
    font-style: italic;
    border-left: 4px solid #34D399;
    padding-left: 20px;
    margin: 24px 0;
  }

  blockquote p {
    margin: 0;
  }
---

<!-- _class: lead -->

# 排期天菜

<p class="tagline">韭菜的自我管理排期剧历</p>

<p class="slogan">让每一张票，都有处安放。</p>

<p style="margin-top: 60px; color: #666;">Paiqi Release</p>

<!-- 封面视觉：Logo 大图居中，黑底紫绿渐变光效 -->

---

## 排剧期，记场次，存票根

一款面向 **杂食党 P 人剧女** 的本地排期管理应用。

把「盘票、记场次、存票根」的碎片流程，变成一个 App。

> 盘剧写 repo 快乐，排期不快乐。

<div class="two-column-wide" style="margin-top: 30px;">
  <div>
    <ul>
      <li><strong>排剧期：</strong>可视化对比剧目排期</li>
      <li><strong>记场次：</strong>已购/想看场次 + 待办提醒</li>
      <li><strong>存票根：</strong>月底年底数据复盘</li>
    </ul>
  </div>
  <div class="placeholder" style="min-height: 280px;">
    【截图位置】<br>App 月历首页 / 开屏页
  </div>
</div>

---

## 为谁而做

这不是所有人的日历，这是 **剧女的日历**。

<div class="two-column-wide">
  <div>
    <ul>
      <li>重度戏剧 / 音乐剧爱好者</li>
      <li>一年看几十场，杂食党，多剧并行</li>
      <li>微信群、大麦、小红书、原生日历四头跑</li>
      <li>P 人，不爱整理，但被迫整理</li>
    </ul>

> 她们不缺工具，缺的是一套「懂剧场信息密度」的排期工具。
  </div>
  <div class="placeholder" style="min-height: 320px;">
    【截图位置】<br>用户场景拼贴：微信 / 大麦 / 小红书 / 日历
  </div>
</div>

---

## 产品解决的痛点和场景

<div class="painpoint-card">
  <h3>📱 信息散：四处存，找不到</h3>
  <p>群聊、相册、日历、备忘录各存一点；宣排期截图放相册吃灰，想查卡司时翻半天。</p>
</div>

<div class="painpoint-card">
  <h3>⏰ 易出错：午晚场、物料、取票全怕忘</h3>
  <p>午场 14:00 还是 14:30 常搞混；换物料、帮人取票、面交、买周边、领鸡蛋规则地点全靠临场记忆。</p>
</div>

<div class="painpoint-card">
  <h3>📊 难复盘：看完就忘，年底一笔糊涂账</h3>
  <p>票根散落、repo 懒得上传，一年到底看了多少场、花了多少钱、追了哪些演员，没有清晰记录。</p>
</div>

---

## 通用工具为什么治不好

| 工具 | 问题 |
|------|------|
| 原生日历 | 只能记时间，塞不下卡司 / 票版 / 物料 |
| Excel / Notion | 太重，P 人坚持不下来 |
| 大麦 / 猫眼 | 只关心「已购票」，不关心「想看」和「规划」 |
| 小红书收藏 | 信息滞后，不好检索 |

> 剧女需要的是一个「懂剧场信息密度」的专属工具，而不是第二个日历。

---

## 产品定位：排 · 记 · 存

围绕看剧排期的核心流程，做一款简洁美观的本地工具。

<div class="three-column">
  <div class="card">
    <h3>🟣 排</h3>
    <p>把剧目宣排期表变成可视化排期流。</p>
    <p>支持横向纵向对比场次，一眼看清哪天有哪些剧、哪些卡司，想看的场次手动 mark 后自动同步到月历。</p>
  </div>
  <div class="card">
    <h3>🟢 记</h3>
    <p>保存 + 提醒，不再临场失忆。</p>
    <p>已购票场次集中管理，可添加提醒和备注：换物料、帮人取票、面交、买周边、领鸡蛋规则地点，一场场列清楚。</p>
  </div>
  <div class="card">
    <h3>🟣 存</h3>
    <p>收录数据，月底年底一键复盘。</p>
    <p>看过的剧目次数、演员次数、花费金额全部变成可视化图表，一键生成年度看剧报告，让每一张票都有处安放。</p>
  </div>
</div>

---

<!-- 建议插入在第 6 页之后：现场 Demo 路线图 -->

## 现场演示：一位剧女的一天

<div class="two-column-wide">
  <div>
    <ol>
      <li><strong>打开月历</strong>：今天有哪些演出？</li>
      <li><strong>管理台收剧</strong>：把新剧先放进资料库</li>
      <li><strong>加入排期流</strong>：挑选场次进入可视排期</li>
      <li><strong>排期板对比</strong>：3天聚焦 ↔ 7天宏观切换</li>
      <li><strong>记录票根与待办</strong>：买完票不再失忆</li>
      <li><strong>个人中心复盘</strong>：数据自动生成报告</li>
    </ol>
  </div>
  <div class="placeholder" style="min-height: 360px;">
    【截图位置】<br>三张核心页面拼贴<br>月历 / 排期板 / 个人中心
  </div>
</div>

---

## 排：把排期表变成可视化排期流

<div class="two-column-wide">
  <div>
    <ul>
      <li>剧目宣排期一键查看</li>
      <li>横向纵向对比场次与卡司</li>
      <li>想看的场次手动 mark</li>
      <li>自动同步到月历首页</li>
    </ul>

> 不再翻相册、不再搜大麦，排期流上一眼盘清楚。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>排期板双密度视图
  </div>
</div>

---

## 记：保存 + 提醒，不再临场失忆

<div class="two-column-wide">
  <div>
    <ul>
      <li>已购票场次集中管理</li>
      <li>添加提醒和备注事项</li>
      <li>换物料、帮人取票、面交、买周边</li>
      <li>领鸡蛋规则地点一一记录</li>
    </ul>

> 剧场门口不再手忙脚乱，打开 App 就知道今天要干嘛。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>详情页待办清单
  </div>
</div>

---

## 存：月底年底一键复盘

<div class="two-column-wide">
  <div>
    <ul>
      <li>看过的剧目次数统计</li>
      <li>看过的演员次数统计</li>
      <li>花费金额可视化</li>
      <li>一键生成年度看剧报告</li>
    </ul>

> 年底发小红书年度总结，素材直接从这里拿。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>个人中心四张图表
  </div>
</div>

---

## 视觉设计：像素风 + 星之果实紫绿

<div class="two-column-wide">
  <div>
    <ul>
      <li>黑底 <code>#0F0F0F</code>，护眼不刺眼</li>
      <li>紫 <code>#8B5CF6</code> + 绿 <code>#34D399</code>，星之果实感</li>
      <li>像素字体与图标，致敬剧场票根 / 街机复古感</li>
      <li>Logo 字谜：「非」+ 横线 +「菜」= <strong>韭</strong>，其余为紫</li>
    </ul>
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>Logo 拆解图 + 色板展示
  </div>
</div>

---

## 总结：我们做对了什么

<div class="three-column">
  <div class="card">
    <h3>从真实场景出发</h3>
    <p>不是凭空造工具，而是把自己作为目标用户，把每天重复的排期动作提炼成「排 · 记 · 存」。</p>
  </div>
  <div class="card">
    <h3>聚焦核心流程</h3>
    <p>先做 MVP 验证最小闭环：排期可视化、场次记录、数据复盘，不堆功能。</p>
  </div>
  <div class="card">
    <h3>视觉差异化</h3>
    <p>像素风 + 紫绿配色 + Logo 字谜，让「排期天菜」在工具类 App 中有记忆点。</p>
  </div>
</div>

> 接下来：OCR 识别排期表、提醒通知、观演记录与社交分享，持续打磨。

---

<!-- _class: lead -->

# 排期天菜

<p class="slogan">让每一张票，都有处安放。</p>

<p style="margin-top: 80px; font-size: 1.5em; color: #34D399;">愿 vibe coding 赐福我的戏梦人生</p>

<p style="margin-top: 40px; color: #666;">Paiqi · 排期天菜</p>

<div style="margin-top: 30px;">
  <img src="assets/qr_paiqi_preview.png" width="160" height="160" alt="在线预览二维码" style="border-radius: 12px;" />
  <p style="margin-top: 12px; font-size: 0.9em; color: #B0B0B0;">扫码体验：giantpuppy.github.io/paiqi</p>
</div>

<!-- 结尾页：Logo + 结语 + 紫绿光效 + 在线预览二维码 -->
