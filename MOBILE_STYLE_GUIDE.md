# 手机长页模式样式设计文档

> 来自 `src/mobile.js`，可复用到其他基于 Puppeteer 的 Markdown → PDF 项目。

---

## 设计规格

- **画布宽度**：390px（iPhone 标准宽度）
- **输出方式**：单页不分页，动态测量内容高度
- **渲染精度**：`deviceScaleFactor: 2`（2x Retina 清晰度）
- **内边距**：上 20px / 下 32px / 左右 18px

---

## Google 品牌色

| 色名   | 色值      | 用途                        |
|--------|-----------|-----------------------------|
| Blue   | `#4285F4` | h1、h5、链接、表头背景      |
| Red    | `#EA4335` | h2、h6                      |
| Green  | `#34A853` | h3                          |
| Yellow | `#FBBC05` | h4 背景、blockquote 边框、bold 高亮底色 |

---

## 标题设计逻辑

| 标签 | 字号  | 处理方式 |
|------|-------|----------|
| h1   | 28px  | 左色条（4px solid Blue）+ 文字 Blue |
| h2   | 24px  | 左色条（4px solid Red）+ 文字 Red |
| h3   | 22px  | 左色条（4px solid Green）+ 文字 Green |
| h4   | 20px  | Yellow 背景色块（inline-block + 3px 圆角），文字黑色 |
| h5   | 18px  | 纯文字 Blue，无装饰 |
| h6   | 17px  | 纯文字 Red，无装饰 |

h1–h3 共同规则：`padding-left: 10px`，margin-top 从 1.4em 递减到 1.2em。

---

## 核心元素样式说明

**Body 文字**：18px，行高 1.25，颜色 `#1a1a1a`

**Bold**：`rgba(251, 188, 5, 0.28)` 黄色半透明高亮底色 + 2px 圆角，保留视觉节奏而不刺眼

**链接**：Blue 色，去下划线，改用 `border-bottom: 1px solid rgba(66,133,244,0.3)` 淡虚线

**Blockquote**：Yellow 左边框（4px）+ `rgba(251,188,5,0.08)` 极淡黄底，文字 `#444`

**代码块**：
- Inline code：`#f1f3f4` 灰底，14px，5px 横向 padding
- Pre block：同色灰底，12px 内边距，13px 字号，行高 1.55，6px 圆角

**表格**：Blue 表头（白字），隔行斑马纹 `#f8f9fa`，td 底线 `#e0e0e0`，14px 字号

**图片**：`max-width: 100%`，6px 圆角

**分割线**：`border-top: 2px solid #e0e0e0`

**字体栈**：优先 CJK（PingFang SC → Hiragino Sans GB → Noto Sans CJK SC → Microsoft YaHei），fallback 到系统 sans-serif

---

## 完整 CSS

```css
/* ── Google 品牌色常量 ── */
/* Blue: #4285F4 | Red: #EA4335 | Yellow: #FBBC05 | Green: #34A853 */

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans CJK SC',
               'Microsoft YaHei', -apple-system, BlinkMacSystemFont,
               'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
  font-size: 18px;
  line-height: 1.25;
  color: #1a1a1a;
  width: 390px;
  padding: 20px 18px 32px;
  word-break: break-word;
}

/* ── Headings — Google brand colors ── */
h1 {
  font-size: 28px;
  color: #4285F4;
  border-left: 4px solid #4285F4;
  padding-left: 10px;
  margin-top: 1.4em;
  margin-bottom: 0.4em;
}
h2 {
  font-size: 24px;
  color: #EA4335;
  border-left: 4px solid #EA4335;
  padding-left: 10px;
  margin-top: 1.3em;
  margin-bottom: 0.4em;
}
h3 {
  font-size: 22px;
  color: #34A853;
  border-left: 4px solid #34A853;
  padding-left: 10px;
  margin-top: 1.2em;
  margin-bottom: 0.3em;
}
h4 {
  font-size: 20px;
  background: #FBBC05;
  color: #1a1a1a;
  display: inline-block;
  padding: 0 6px 1px;
  border-radius: 3px;
  margin-top: 1.1em;
  margin-bottom: 0.3em;
}
h5 {
  font-size: 18px;
  color: #4285F4;
  margin-top: 1em;
  margin-bottom: 0.3em;
}
h6 {
  font-size: 17px;
  color: #EA4335;
  margin-top: 1em;
  margin-bottom: 0.3em;
}

/* ── Bold — yellow highlight ── */
strong, b {
  background: rgba(251, 188, 5, 0.28);
  padding: 0 2px;
  border-radius: 2px;
  font-weight: 700;
}

p { margin: 0.75em 0; }

a {
  color: #4285F4;
  text-decoration: none;
  border-bottom: 1px solid rgba(66, 133, 244, 0.3);
}

blockquote {
  border-left: 4px solid #FBBC05;
  margin: 1em 0;
  padding: 6px 12px;
  background: rgba(251, 188, 5, 0.08);
  color: #444;
}

code {
  font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
  font-size: 14px;
  background: #f1f3f4;
  padding: 1px 5px;
  border-radius: 3px;
}

pre {
  background: #f1f3f4;
  padding: 12px 14px;
  border-radius: 6px;
  overflow-x: auto;
  font-size: 13px;
  line-height: 1.55;
  margin: 1em 0;
}
pre code { background: none; padding: 0; }

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
  margin: 1em 0;
}
th {
  background: #4285F4;
  color: #fff;
  padding: 6px 8px;
  text-align: left;
}
td {
  border-bottom: 1px solid #e0e0e0;
  padding: 5px 8px;
}
tr:nth-child(even) td { background: #f8f9fa; }

ul, ol { padding-left: 1.4em; margin: 0.6em 0; }
li { margin: 0.3em 0; }

img { max-width: 100%; height: auto; border-radius: 6px; }

hr { border: none; border-top: 2px solid #e0e0e0; margin: 1.5em 0; }
```

---

## Puppeteer 关键参数

在其他项目中复现长页效果的核心配置：

```js
import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({
  args: ['--no-sandbox', '--disable-setuid-sandbox']
});
const page = await browser.newPage();

// 模拟 iPhone 视口，2x 分辨率
await page.setViewport({ width: 390, height: 800, deviceScaleFactor: 2 });

await page.setContent(html, { waitUntil: 'networkidle0' });

// 动态测量内容高度，实现长页不分页
const contentHeight = await page.evaluate(
  () => document.documentElement.scrollHeight
);

const pdfBuffer = await page.pdf({
  width:           '390px',
  height:          `${contentHeight}px`, // 自适应内容高度
  printBackground: true,
  margin:          { top: 0, right: 0, bottom: 0, left: 0 },
  pageRanges:      '1',
});

await browser.close();
```
