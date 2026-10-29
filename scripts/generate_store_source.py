#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


REPOSITORY = "likehao0522cn-gif/auto"
BUNDLE_ID = "com.shm06.TuneMetronome"


def release_url(version: str, asset: str) -> str:
    return f"https://github.com/{REPOSITORY}/releases/download/v{version}/{asset}"


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_store_source.py VERSION IPA_SIZE OUTPUT")

    version = sys.argv[1].removeprefix("v")
    ipa_size = int(sys.argv[2])
    output = Path(sys.argv[3])
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    source = {
        "name": "调音节拍器测试源",
        "identifier": "com.shm06.TuneMetronome.source",
        "subtitle": "面向盲人和低视力用户的调音与节拍器测试版本",
        "description": "通过 SideStore 或 AltStore 安装和更新调音节拍器测试包。",
        "iconURL": release_url(version, "icon.png"),
        "headerURL": release_url(version, "icon.png"),
        "website": f"https://github.com/{REPOSITORY}",
        "tintColor": "#F5BE50",
        "featuredApps": [BUNDLE_ID],
        "apps": [
            {
                "name": "调音节拍器（测试）",
                "bundleIdentifier": BUNDLE_ID,
                "developerName": "likehao0522cn-gif",
                "subtitle": "可调语速、音调和音量的无障碍调音节拍器",
                "localizedDescription": "面向盲人和低视力用户的调音器与节拍器。支持旁白标签、应用语音、旁白播报、测速打拍和可调节语音。",
                "iconURL": release_url(version, "icon.png"),
                "tintColor": "#F5BE50",
                "category": "utilities",
                "versions": [
                    {
                        "version": version,
                        "date": now,
                        "downloadURL": release_url(version, "TuneMetronome.ipa"),
                        "size": ipa_size,
                        "minOSVersion": "17.0",
                        "versionDescription": "语音语速、音调、音量和测速页大区域单击打拍。",
                    }
                ],
            }
        ],
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
