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

    # SideStore compares the installed version against this list. Keeping a
    # short history (newest first) makes updates show up reliably even when the
    # installed build sits a few versions behind.
    version_history = [
        ("0.6.7", "2026-11-03T06:57:54Z", 625174,
         "降低单音误判为多音的几率并加入环境降噪；节拍器运行中切拍号不再抢读；调音播报打断后不再少字。"),
        ("0.6.6", "2026-11-03T04:28:58Z", 620384,
         "语音语速、音调、音量改为百分比显示，并支持旁白上下清扫；调音设置同样支持清扫。"),
        ("0.6.5", "2026-11-03T02:22:58Z", 622532,
         "调音器音频兼容旁白，失败提示改为中文；乐器支持旁白上下清扫或点选；换音时立即打断旧播报。"),
    ]

    def version_entry(entry_version, entry_date, entry_size, entry_note):
        return {
            "version": entry_version,
            "date": entry_date,
            "downloadURL": release_url(entry_version, "TuneMetronome.ipa"),
            "size": entry_size,
            "minOSVersion": "17.0",
            "versionDescription": entry_note,
        }

    listed_versions = [version_entry(*item) for item in version_history]
    # Guarantee the version being built is present and first, even if the
    # hard-coded history above is stale.
    listed_versions = [
        entry for entry in listed_versions if entry["version"] != version
    ]
    listed_versions.insert(0, version_entry(
        version,
        now,
        ipa_size,
        "降低单音误判为多音的几率并加入环境降噪；节拍器运行中切拍号不再抢读；调音播报打断后不再少字。",
    ))

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
                "versions": listed_versions,
            }
        ],
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
