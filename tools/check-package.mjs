#!/usr/bin/env node
// 打包自检：不进网络、不跑 sherlock，只检查仓库自身是否干净可提交。
//
//   node tools/check-package.mjs
//
// 退出码 0 = 全部通过。

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const results = []
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? `  — ${detail}` : ''}`)
}

// 1) 必备文件
for (const file of ['README.md', 'LICENSE', '.gitignore', 'requirements.txt', 'install.ps1', 'run.cmd', 'run.sh']) {
  check(`存在 ${file}`, existsSync(join(ROOT, file)))
}

// 2) .gitignore 必须挡住大件与私人内容
const ignore = readFileSync(join(ROOT, '.gitignore'), 'utf8')
for (const rule of ['.venv/', 'upstream/', 'results/', '*.whl']) {
  check(`.gitignore 含 ${rule}`, ignore.includes(rule))
}

// 3) 脚本换行：.cmd 必须 CRLF，否则 cmd 会切碎参数
for (const file of ['run.cmd']) {
  const buf = readFileSync(join(ROOT, file))
  const crlf = buf.includes(Buffer.from('\r\n'))
  const lfOnly = buf.includes(Buffer.from('\n')) && !crlf
  check(`${file} 是 CRLF 换行`, crlf && !lfOnly)
}

// 4) requirements 覆盖上游 v0.16.2 的主依赖
const req = readFileSync(join(ROOT, 'requirements.txt'), 'utf8').toLowerCase()
for (const dep of ['certifi', 'colorama', 'pysocks', 'requests', 'requests-futures', 'stem', 'pandas', 'openpyxl', 'tomli']) {
  check(`requirements 含 ${dep}`, req.includes(dep))
}

// 5) 不许把构建产物或敏感文件带进仓库。
// 这些目录由 install.ps1 在本地生成，已被 .gitignore 挡住——存在是正常的，
// 检查的是它们「没有被 .gitignore 漏掉」，而不是「没有生成」。
const generated = new Set(['.venv', 'upstream', 'results', '__pycache__', 'node_modules'])
const patched = /\.(whl|pyc|log)$|\.egg-info($|\/)/
const offenders = []
const walk = (dir) => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    const rel = relative(ROOT, full).split(sep).join('/')
    if (entry.isDirectory() && (generated.has(entry.name) || rel.endsWith('.egg-info'))) {
      // 生成物目录：确认 .gitignore 有对应规则即可，不往里走
      continue
    }
    if (entry.isFile() && patched.test(rel)) {
      offenders.push(rel)
      continue
    }
    if (entry.isDirectory() && entry.name !== '.git') walk(full)
  }
}
walk(ROOT)
check('源码里没有混入 wheel / pyc / 日志', offenders.length === 0, offenders.slice(0, 5).join(', '))

// 生成物目录若已存在，必须被 .gitignore 覆盖（否则会被误提交）
const present = [...generated].filter((d) => existsSync(join(ROOT, d)))
const uncovered = present.filter((d) => !ignore.includes(`${d}/`))
check(
  `生成物目录均被 .gitignore 覆盖${present.length ? `（现有 ${present.join(', ')}）` : '（当前未生成）'}`,
  uncovered.length === 0,
  uncovered.join(', '),
)

// 6) README 与 LICENSE 里的项目名一致
const readme = readFileSync(join(ROOT, 'README.md'), 'utf8')
check('README 标题正确', readme.startsWith('# Sherlock-UsernameSearch-WhenNeedOSINT'))
const license = readFileSync(join(ROOT, 'LICENSE'), 'utf8')
check('LICENSE 保留上游署名', /sherlock-project/i.test(license) && /MIT License/.test(license))

// 7) run.cmd 里的路径与安装目录一致
const cmd = readFileSync(join(ROOT, 'run.cmd'), 'utf8')
check('run.cmd 指向 .venv 与 results', cmd.includes('.venv\\Scripts\\python.exe') && cmd.includes('results'))

// 汇总
const failed = results.filter((r) => !r.ok)
console.log(`\n${results.length - failed.length}/${results.length} 通过`)
process.exit(failed.length === 0 ? 0 : 1)

// 让 statSync 的导入不显得多余（供将来加尺寸检查）
void statSync
