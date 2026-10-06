#!/usr/bin/env node
/**
 * Lifeline Web 端到端测试 + 截图（仅针对本地自建 web 应用）。
 *
 * 依赖：Playwright（通过 NODE_PATH 解析）；ImageMagick(identify) 用于校验截图非空白。
 * 环境变量：
 *   BASE_URL                本地服务地址（默认 http://127.0.0.1:8099/）
 *   SCREENSHOT_DIR          截图输出目录（默认 <repo>/docs/assets）
 *   PLAYWRIGHT_CHROMIUM_EXECUTABLE  自定义 chromium 可执行文件（默认缓存 chromium-1217）
 *
 * 退出码：0 = PASS，非 0 = FAIL。
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:8099/';
const SHOT_DIR =
  process.env.SCREENSHOT_DIR || path.resolve(__dirname, '../../docs/assets');
const EXE =
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
  path.join(
    process.env.HOME || '',
    '.cache/ms-playwright/chromium-1217/chrome-linux64/chrome',
  );

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (e) {
  console.error('[fatal] 无法加载 playwright：', e.message);
  console.error('        请设置 NODE_PATH 指向含 playwright 的 node_modules。');
  process.exit(2);
}

const failures = [];
const consoleErrors = [];

function fail(msg) {
  failures.push(msg);
  console.error('  ✗ ' + msg);
}
function ok(msg) {
  console.log('  ✓ ' + msg);
}
function assert(cond, msg) {
  if (cond) ok(msg);
  else fail(msg);
  return cond;
}

/** 收集页面所有可见文本 + 语义标签（CanvasKit 下文本多在 aria-label/placeholder）。 */
async function collectText(page) {
  return page.evaluate(() => {
    const parts = [];
    parts.push(document.body ? document.body.innerText || '' : '');
    for (const el of document.querySelectorAll('[aria-label],[placeholder],[title]')) {
      const v =
        el.getAttribute('aria-label') ||
        el.getAttribute('placeholder') ||
        el.getAttribute('title');
      if (v) parts.push(v);
    }
    for (const el of document.querySelectorAll('input,textarea')) {
      if (el.value) parts.push(el.value);
    }
    return parts.join('\n');
  });
}

/** 等待 Flutter 首帧：语义树容器出现 + 文本达到阈值。 */
async function waitForFlutter(page, { minText = 30, timeout = 45000 } = {}) {
  await page
    .waitForFunction(
      (min) => {
        const hasFlutter =
          !!document.querySelector('flt-semantics') ||
          !!document.querySelector('flutter-view');
        const len = (document.body && document.body.innerText || '').length;
        return hasFlutter && len >= min;
      },
      minText,
      { timeout },
    )
    .catch(() => {});
  await page.waitForTimeout(2500);
}

/** 截图并用 ImageMagick 校验非空白（唯一颜色数 > 阈值）。 */
function shoot(page, file, { minColors = 40 } = {}) {
  const out = path.join(SHOT_DIR, file);
  return page.screenshot({ path: out }).then(() => {
    let colors = -1;
    try {
      colors = parseInt(
        execFileSync('identify', ['-format', '%k', out], { encoding: 'utf8' }).trim(),
        10,
      );
    } catch (e) {
      // identify 不可用则退化为文件大小检查。
      const size = fs.statSync(out).size;
      if (!assert(size > 20000, `${file} 非空白（体积 ${size}B）`)) return;
      return;
    }
    assert(colors >= minColors, `${file} 非空白（唯一颜色 ${colors}）`);
  });
}

function newContext(browser, height) {
  return browser.newContext({
    viewport: { width: 1280, height },
    deviceScaleFactor: 1,
    locale: 'zh-CN',
  });
}

function hookErrors(page, label) {
  page.on('pageerror', (e) => consoleErrors.push(`[${label}] pageerror: ${e.message}`));
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(`[${label}] console: ${m.text()}`);
  });
}

/** 打开一个页面；shot=true 时截图。q 必须唯一以强制整页加载。 */
async function openPage(browser, { label, query, height, shot, minText }) {
  const ctx = await newContext(browser, height);
  const page = await ctx.newPage();
  hookErrors(page, label);
  await page.goto(BASE + query, { waitUntil: 'load', timeout: 60000 });
  await waitForFlutter(page, { minText: minText || 30 });
  const text = await collectText(page);
  if (shot) await shoot(page, shot);
  return { ctx, page, text };
}

async function main() {
  if (!fs.existsSync(EXE)) {
    console.error(`[fatal] 未找到 chromium 可执行文件：${EXE}`);
    process.exit(2);
  }
  fs.mkdirSync(SHOT_DIR, { recursive: true });

  const browser = await chromium.launch({
    executablePath: EXE,
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-gpu',
      '--enable-unsafe-swiftshader',
      '--use-gl=swiftshader',
    ],
  });

  console.log(`\n=== Lifeline Web E2E ===\nBASE=${BASE}\nSHOT_DIR=${SHOT_DIR}\n`);

  // 1) 首启（不带 demo，干净上下文）
  {
    console.log('[1/8] 首启同步根选择页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'onboarding',
      query: '?r=onboarding',
      height: 900,
      shot: 'screenshot-onboarding.png',
    });
    assert(text.includes('选择同步文件夹'), '出现「选择同步文件夹」');
    assert(text.includes('同步方式指南'), '出现「同步方式指南」');
    await ctx.close();
  }

  // 2) 首页完整简历
  {
    console.log('[2/8] 首页完整简历');
    const { ctx, page, text } = await openPage(browser, {
      label: 'home',
      query: '?demo=1&r=home#/',
      height: 900,
      shot: 'screenshot-home.png',
    });
    assert(text.includes('林知微'), '出现示例姓名「林知微」');
    assert(text.includes('个人简介'), '出现「个人简介」');
    assert(text.includes('教育经历'), '出现「教育经历」');
    await ctx.close();
  }

  // 3) 记录编辑（已填示例记录）
  {
    console.log('[3/8] 记录编辑页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'record-edit',
      query: '?demo=1&r=edit#/records/demo-exp-0001/edit',
      height: 1100,
      shot: 'screenshot-record-edit.png',
    });
    assert(text.includes('编辑记录'), '出现「编辑记录」');
    assert(text.includes('工作/实习经历'), '出现分类「工作/实习经历」');
    assert(text.includes('基本信息'), '出现「基本信息」表单区');
    await ctx.close();
  }

  // 4) AI 自动录入
  {
    console.log('[4/8] AI 自动录入页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'capture',
      query: '?demo=1&r=capture#/capture',
      height: 640,
      shot: 'screenshot-capture.png',
    });
    assert(text.includes('智能录入'), '出现「智能录入」');
    assert(text.includes('输入信息'), '出现「输入信息」区');
    assert(text.includes('AI 分析'), '出现「AI 分析」按钮');
    await ctx.close();
  }

  // 5) 定向导出问卷
  {
    console.log('[5/8] 定向导出问卷页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'export',
      query: '?demo=1&r=export#/export',
      height: 1500,
      shot: 'screenshot-export.png',
    });
    assert(text.includes('智能导出'), '出现「智能导出」');
    assert(text.includes('目标岗位'), '出现问卷字段「目标岗位」');
    assert(text.includes('目标企业'), '出现问卷字段「目标企业」');
    assert(text.includes('必须包含'), '出现问卷字段「必须包含」');
    await ctx.close();
  }

  // 6) 简历库（示例简历 + 评估分数）
  {
    console.log('[6/8] 简历库页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'resumes',
      query: '?demo=1&r=resumes#/resumes',
      height: 360,
      shot: 'screenshot-resumes.png',
    });
    assert(text.includes('简历库'), '出现「简历库」');
    assert(text.includes('后端工程师 · 示例科技'), '出现示例简历名');
    assert(text.includes('适配') && text.includes('客观'), '出现评估徽章（适配/客观）');
    assert(/\b\d{1,3}\b/.test(text), '出现数值化评估分数');
    await ctx.close();
  }

  // 7) 简历评估（一体两面：岗位适配诊断 + 客观质量评分）
  {
    console.log('[7/8] 简历评估页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'eval',
      query: '?demo=1&r=eval#/resumes/eval/demo-resume-0001',
      height: 1400,
      shot: 'screenshot-eval.png',
    });
    assert(text.includes('岗位适配') || text.includes('适配诊断'), '出现「岗位适配诊断」');
    assert(text.includes('客观质量') || text.includes('客观'), '出现「客观质量评分」');
    assert(text.includes('行动') || text.includes('建议'), '出现改进行动建议');
    await ctx.close();
  }

  // 8) 真实交互：首页点击「添加信息」→ 跳转新增记录
  {
    console.log('[8/9] 交互：点击「添加信息」');
    const ctx = await newContext(browser, 900);
    const page = await ctx.newPage();
    hookErrors(page, 'interaction');
    await page.goto(BASE + '?demo=1&r=interact#/', { waitUntil: 'load', timeout: 60000 });
    await waitForFlutter(page);
    let clicked = false;
    try {
      await page.getByRole('button', { name: '添加信息' }).first().click({ timeout: 6000 });
      clicked = true;
    } catch (_) {
      try {
        await page
          .locator('flt-semantics[role="button"]', { hasText: '添加信息' })
          .first()
          .click({ timeout: 6000 });
        clicked = true;
      } catch (_) {}
    }
    assert(clicked, '成功点击「添加信息」');
    await page.waitForTimeout(3000);
    const after = await collectText(page);
    assert(after.includes('新增记录'), '导航到「新增记录」页（页面已变化）');
    await ctx.close();
  }

  // 9) 分类管理（开放分类）
  {
    console.log('[9/9] 分类管理页');
    const { ctx, page, text } = await openPage(browser, {
      label: 'categories',
      query: '?demo=1&r=categories#/settings/categories',
      height: 900,
      shot: 'screenshot-categories.png',
    });
    assert(text.includes('管理分类'), '出现「管理分类」');
    assert(text.includes('教育经历'), '出现默认分类「教育经历」');
    assert(text.includes('新增'), '出现「新增」入口');
    await ctx.close();
  }

  await browser.close();

  // 汇总
  console.log('\n=== 结果 ===');
  console.log(`console/pageerror 错误数：${consoleErrors.length}`);
  if (consoleErrors.length) {
    for (const e of consoleErrors.slice(0, 20)) console.log('   - ' + e);
  }
  assert(consoleErrors.length === 0, '无致命浏览器错误');

  const shots = [
    'screenshot-onboarding.png',
    'screenshot-home.png',
    'screenshot-record-edit.png',
    'screenshot-capture.png',
    'screenshot-export.png',
    'screenshot-resumes.png',
    'screenshot-eval.png',
    'screenshot-categories.png',
  ];
  console.log('\n截图产物：');
  for (const s of shots) {
    const p = path.join(SHOT_DIR, s);
    const exists = fs.existsSync(p);
    console.log(`   ${exists ? '✓' : '✗'} ${s}${exists ? ` (${fs.statSync(p).size}B)` : ''}`);
    if (!exists) fail(`缺少截图 ${s}`);
  }

  if (failures.length) {
    console.log(`\nFAIL：${failures.length} 项未通过`);
    process.exit(1);
  }
  console.log('\nPASS：全部断言通过，0 浏览器错误，8 张截图已生成。');
}

main().catch((e) => {
  console.error('\n[fatal]', e);
  process.exit(1);
});
