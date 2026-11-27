"""xcresult attachments are authoritative; simulator test runner cannot always write host SHOTS_DIR."""
import json
import pathlib
import re
import shutil
import subprocess
import sys


def copy_store_screenshots(folder):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    store_name = re.compile(r"(store-(?:zh-Hans|en|zh-Hant|ja)-\d{2}-[a-z0-9-]+)(?:_\d+_[\da-fA-F-]+)?(?:\.png)?")
    names = set()
    for test in manifest:
        for attachment in test["attachments"]:
            match = store_name.fullmatch(attachment["suggestedHumanReadableName"])
            source = folder / attachment["exportedFileName"]
            if not match or source.suffix.lower() != ".png":
                continue
            target = folder / (match[1] + ".png")
            if source != target:
                shutil.copy2(source, target)
            names.add(target.name)
    return len(names)


def main():
    result, output = sys.argv[1:3]
    folder = pathlib.Path(output)
    folder.mkdir(parents=True, exist_ok=True)
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result,
                    "--output-path", str(folder)], check=True)
    pngs = sorted(folder.glob("**/*.png"))
    if not pngs:
        sys.exit("界面测试没有导出 PNG 截图")
    for index, path in enumerate(pngs, 1):
        if path.parent != folder:
            shutil.copy2(path, folder / f"{index:03d}-{path.name}")
    store_count = copy_store_screenshots(folder)
    print(f"已导出 {len(pngs)} 张界面测试截图到 {folder}，其中商店截图按语言命名 {store_count} 张")


if __name__ == "__main__":
    main()
