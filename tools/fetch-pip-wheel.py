#!/usr/bin/env python3
"""从 PyPI 取最新 pip 的 wheel，存到指定目录（文件名保持标准格式）。

  python fetch-pip-wheel.py <目标目录>

用途：部分精简 Python 没带 ensurepip 数据，`python -m venv` 建不出带 pip 的环境，
就用这个脚本下 wheel，再用 `PYTHONPATH=<whl> python -m pip install --no-index <whl>`
把它自己装进去。
"""
import json
import os
import sys
import urllib.request

API = "https://pypi.org/pypi/pip/json"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    dest = os.path.abspath(sys.argv[1])
    os.makedirs(dest, exist_ok=True)

    try:
        with urllib.request.urlopen(API, timeout=60) as resp:
            data = json.load(resp)
    except Exception as exc:  # noqa: BLE001
        print(f"读取 {API} 失败：{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    wheels = [u for u in data.get("urls", []) if u["filename"].endswith("py3-none-any.whl")]
    if not wheels:
        print("没有找到通用的 py3-none-any.whl", file=sys.stderr)
        return 1
    wheel = wheels[0]
    target = os.path.join(dest, wheel["filename"])

    try:
        urllib.request.urlretrieve(wheel["url"], target)
    except Exception as exc:  # noqa: BLE001
        print(f"下载失败：{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    print(f"pip {data['info']['version']} -> {target} ({os.path.getsize(target)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
