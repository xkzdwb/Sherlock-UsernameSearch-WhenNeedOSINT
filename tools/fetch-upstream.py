#!/usr/bin/env python3
"""下载上游 sherlock 的 tag zip 包，解压到目标目录。

  python fetch-upstream.py <目标目录> <tag>      例：fetch-upstream.py upstream v0.16.2

不解压时传 --zip-only 只留 zip。供 install.ps1 调用，也可单独跑。
"""
import os
import sys
import urllib.request
import zipfile

REPO = "https://codeload.github.com/sherlock-project/sherlock/zip/refs/tags/{}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    dest = os.path.abspath(sys.argv[1])
    tag = sys.argv[2]
    slug = tag.lstrip("v")
    os.makedirs(dest, exist_ok=True)

    zip_path = os.path.join(dest, f"sherlock-{tag}.zip")
    url = REPO.format(tag)
    print(f"GET {url}")
    try:
        urllib.request.urlretrieve(url, zip_path)
    except Exception as exc:  # noqa: BLE001 - 网络问题统一报出来
        print(f"下载失败：{type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    size = os.path.getsize(zip_path)
    print(f"saved {zip_path} ({size} bytes)")
    if size < 100_000:
        print("文件过小，疑似不是有效的 tag 包", file=sys.stderr)
        return 1

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        expected = f"sherlock-{slug}/"
        if not any(n.startswith(expected) for n in names):
            print(f"包里没有 {expected}，tag 可能写错了", file=sys.stderr)
            return 1
        zf.extractall(dest)
    os.remove(zip_path)

    src = os.path.join(dest, f"sherlock-{slug}")
    print(f"extracted -> {src}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
