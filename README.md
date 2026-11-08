# Sherlock-UsernameSearch-WhenNeedOSINT

> 一条命令装好 [sherlock](https://github.com/sherlock-project/sherlock)：
> 按用户名在 400+ 个站点上查账号是否存在，输出可导出 CSV / TXT。
> 本仓库**不复制上游代码**，只打包安装与运行的那一层——上游按 tag 现拉，永远是最新发行版。

```
run.cmd github
  [+] GitHub: https://github.com/github
  [+] Reddit: https://www.reddit.com/user/github
  ...
  [*] Search completed with 109 results
```

- **给 Windows 用**：一条 `install.ps1`，自动建 venv、自举 pip、装依赖、editable 装本体。
- **给 macOS / Linux 用**：`run.sh` + `requirements.txt`，标准 `pip` 流程。
- **给 CI 用**：`node tools/check-package.mjs` 纯离线自检，不进网络。

---

## 1. 它解决什么

上游 sherlock 本身很好用，但它的 `pyproject.toml` 只认 Poetry；
Windows 上想「clone 下来就能跑」通常要踩四个坑：

| 坑 | 现象 | 本仓库的处理 |
|---|---|---|
| 只给 Poetry 工程，没有 `requirements.txt` | `pip install .` 拉不到 `poetry-core` | `install.ps1` 用 build isolation 装，另附 `requirements.txt` |
| 精简版 Python 缺 `ensurepip` | `python -m venv` 报 `ensurepip returned non-zero` | 失败自动退回 `--without-pip`，再用 pip wheel 自举 |
| 站点清单要联网拉 | `data.sherlockproject.xyz` 不可达时直接退出 | `run.cmd` / `run.sh` 自动加 `--local`，用上游自带的 `data.json` |
| `run.cmd` 写成 LF | cmd 把参数切碎，报 `is not recognized` | `tools/check-package.mjs` 会检查换行必须是 CRLF |

## 2. 文件

| 文件 | 作用 |
|---|---|
| [install.ps1](install.ps1) | Windows 一键装机：拉 tag → venv → pip → 依赖 → editable 本体 |
| [run.cmd](run.cmd) | Windows 日常入口，自动补 `--local`，输出落在 `results/` |
| [run.sh](run.sh) | 同上，macOS / Linux |
| [requirements.txt](requirements.txt) | 对应上游 v0.16.2 `pyproject` 的主依赖（不含 dev / ci 组） |
| [tools/check-package.mjs](tools/check-package.mjs) | 离线自检：必备文件、忽略规则、换行、依赖清单、不夹带产物 |
| [.gitignore](.gitignore) | 挡住 `.venv/`、`upstream/`、`results/`、`*.whl` |

运行时产生的三个目录**都不入库**，装完才出现：

```
upstream/sherlock-<tag>/   上游源码（install.ps1 现拉）
.venv/                     虚拟环境
results/                   查询输出
```

## 3. 先跑自检（10 秒，不需要装任何东西）

```powershell
node tools/check-package.mjs
```

```
PASS  存在 README.md
PASS  .gitignore 含 .venv/
PASS  run.cmd 是 CRLF 换行
...
27/27 通过
```

## 4. 安装

### Windows

```powershell
cd <clone 下来的目录>
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

（`-ExecutionPolicy Bypass` 是因为默认策略会拦 `.ps1`，报 `AuthorizationManager 检查失败`。）

可调参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `-Python` | 自动探测 `py -3` / `python3` / `python` | 指定解释器 |
| `-Tag` | `v0.16.2` | 换上游版本，例如 `-Tag v0.16.0` |
| `-SkipFetch` | 关 | 已有 `upstream/` 时不重新下载 |

### macOS / Linux

```bash
git clone https://github.com/sherlock-project/sherlock.git upstream/sherlock-master
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/pip install --no-deps -e upstream/sherlock-master
chmod +x run.sh
```

## 5. 用法

```powershell
.\run.cmd github              # 查用户名
.\run.cmd github octocat      # 一次查多个
.\run.cmd github --print-all  # 连未命中的站点也打印
.\run.cmd github --csv --txt  # 导出到 results/（github.csv、github.txt）
.\run.cmd github --site GitHub --site Reddit   # 只查指定站点
```

`sherlock --help` 的完整参数同样可用，`run.cmd` 会原样透传。

## 6. 参数速查

| 参数 | 作用 |
|---|---|
| `--local` | 用本地 `data.json`，不联网拉清单（脚本已自动加） |
| `--timeout N` | 单站点超时秒数，默认 60 |
| `--site NAME` | 只查指定站点，可重复 |
| `--csv` / `--txt` | 导出 CSV / 纯 URL 列表 |
| `-j N` | 导出 JSON，**N 是必填数字**（PR 号；用自身清单填 `2`） |
| `--print-all` | 连未命中站点也打印 |
| `--nsfw` | 包含 NSFW 站点 |
| `--proxy URL` | 走代理 |

## 7. 已知边界

- 结果依赖上游自带 `data.json` 的站点集合，不会自动更新；要更新就带 `-Tag` 重跑 `install.ps1`。
- 查询要逐个访问目标站点，部分站点不可达会表现为未命中或超时，**不等同于「账号不存在」**；
  需要时可加 `--print-all` 或调大 `--timeout` 复核。
- 只做用户名存在性探测，不抓取账号内容。请只对你有权调查的目标使用。

## 8. 许可

本仓库自己的脚本按 MIT 发布，见 [LICENSE](LICENSE)。
上游 sherlock 同样为 MIT（Copyright © 2018 Siddharth Dushantha 及 sherlock-project contribors），
安装时按 tag 下载，不随本仓库分发。
