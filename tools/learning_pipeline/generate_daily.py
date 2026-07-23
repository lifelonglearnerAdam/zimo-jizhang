#!/usr/bin/env python3
"""Generate / package zimo learning long-form content packs.

Examples:
  python tools/learning_pipeline/generate_daily.py pack
  python tools/learning_pipeline/generate_daily.py scaffold --id fee-awareness --title "看清费用"
  python tools/learning_pipeline/generate_daily.py validate content/dist/learning-pack-YYYYMMDD.json
  python tools/learning_pipeline/generate_daily.py generate --topic "应急金进阶"

LLM generation uses env (never hardcode secrets):
  ZIMO_LEARNING_API_BASE / ANTHROPIC_BASE_URL
  ZIMO_LEARNING_API_KEY / ANTHROPIC_AUTH_TOKEN
  ZIMO_LEARNING_MODEL (optional)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT_DIR = ROOT / "content" / "learning"
ARTICLES_DIR = CONTENT_DIR / "articles"
OUT_DIR = ROOT / "content" / "dist"
MANIFEST = CONTENT_DIR / "manifest.json"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def today() -> str:
    return date.today().isoformat()


def parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}, text
    fm_raw = parts[1].strip()
    body = parts[2].lstrip("\n")
    data: dict = {}
    current_list_key = None
    for line in fm_raw.splitlines():
        if not line.strip():
            continue
        if line.lstrip().startswith("- ") and current_list_key:
            data.setdefault(current_list_key, []).append(
                line.lstrip()[2:].strip().strip("'\"")
            )
            continue
        if ":" not in line:
            continue
        key, val = line.split(":", 1)
        key = key.strip()
        val = val.strip()
        if val == "":
            current_list_key = key
            data[key] = []
            continue
        current_list_key = None
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            data[key] = (
                [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
                if inner
                else []
            )
        else:
            data[key] = val.strip("'\"").strip()
    return data, body


def load_articles_from_content():
    if not MANIFEST.exists():
        raise SystemExit(f"missing {MANIFEST}")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    pack_id = manifest.get("pack_id") or f"core-{date.today().strftime('%Y-%m')}"
    articles = []
    for item in manifest.get("articles", []):
        rel = item.get("path")
        if not rel:
            continue
        path = CONTENT_DIR / rel
        if not path.exists():
            print(f"warn: missing {path}", file=sys.stderr)
            continue
        fm, body = parse_frontmatter(path.read_text(encoding="utf-8"))
        art = {
            "id": fm.get("id") or item.get("id"),
            "title": fm.get("title") or item.get("title"),
            "category": fm.get("category") or item.get("category") or "未分类",
            "icon": fm.get("icon") or item.get("icon") or "📘",
            "minutes": int(fm.get("minutes") or item.get("minutes") or 15),
            "summary": fm.get("summary") or item.get("summary") or "",
            "key_points": fm.get("key_points") or item.get("key_points") or [],
            "action_tip": fm.get("action_tip") or item.get("action_tip") or "",
            "tags": fm.get("tags") or item.get("tags") or [],
            "published_at": fm.get("published_at") or item.get("published_at") or today(),
            "updated_at": fm.get("updated_at") or item.get("updated_at") or today(),
            "priority": int(fm.get("priority") or item.get("priority") or 100),
            "body_md": body.strip() + "\n",
            "pack_id": pack_id,
        }
        if not art["id"] or not art["title"]:
            raise SystemExit(f"invalid article file: {path}")
        articles.append(art)
    return articles, pack_id, manifest


def write_pack(articles: list[dict], pack_id: str, out: Path) -> Path:
    payload = {
        "format": "zimo-learning-pack",
        "version": 1,
        "pack_id": pack_id,
        "generated_at": utc_now(),
        "count": len(articles),
        "articles": articles,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def cmd_pack(args: argparse.Namespace) -> int:
    articles, pack_id, _ = load_articles_from_content()
    out = (
        Path(args.out)
        if args.out
        else OUT_DIR / f"learning-pack-{date.today().strftime('%Y%m%d')}.json"
    )
    path = write_pack(articles, pack_id, out)
    print(f"packed {len(articles)} articles -> {path}")
    return 0


def cmd_scaffold(args: argparse.Namespace) -> int:
    ARTICLES_DIR.mkdir(parents=True, exist_ok=True)
    article_id = args.id
    title = args.title or article_id
    path = ARTICLES_DIR / f"{article_id}.md"
    if path.exists() and not args.force:
        raise SystemExit(f"exists: {path} (use --force)")
    body = f"""---
id: {article_id}
title: {title}
category: {args.category}
icon: {args.icon}
minutes: {args.minutes}
summary: {args.summary or "待写摘要"}
key_points:
  - 要点一
  - 要点二
  - 要点三
action_tip: 写下今天可以执行的一个小动作
tags: [{args.category}]
published_at: {today()}
updated_at: {today()}
priority: 100
---

## 导语

（说明为什么这篇重要。）

> **说明**：本文只提供通用财商教育，不构成投资、保险或借贷建议。

## 核心机制

## 案例

## 计算示例 / 对照

## 常见误区

## 今日行动

## 延伸阅读
"""
    path.write_text(body, encoding="utf-8")

    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    else:
        CONTENT_DIR.mkdir(parents=True, exist_ok=True)
        manifest = {
            "format": "zimo-learning-pack",
            "version": 1,
            "pack_id": f"core-{date.today().strftime('%Y-%m')}",
            "articles": [],
        }
    articles = manifest.setdefault("articles", [])
    if not any(a.get("id") == article_id for a in articles):
        articles.append(
            {
                "id": article_id,
                "path": f"articles/{article_id}.md",
                "title": title,
                "category": args.category,
                "icon": args.icon,
                "minutes": args.minutes,
                "summary": args.summary or "待写摘要",
                "published_at": today(),
                "updated_at": today(),
                "priority": 100,
            }
        )
        MANIFEST.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(f"scaffolded {path}")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    path = Path(args.path)
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data.get("format") in {"zimo-learning-pack", "zimo.learning.pack"}
    assert int(data.get("version") or data.get("format_version") or 0) == 1
    arts = data.get("articles") or []
    assert arts, "no articles"
    ids = set()
    for a in arts:
        assert a.get("id") and a.get("title")
        assert a["id"] not in ids
        ids.add(a["id"])
        body = a.get("body_md") or a.get("body") or ""
        if args.require_long:
            assert len(body) >= 380, f"{a['id']} body too short ({len(body)})"
            for h in ["## 导语", "## 今日行动"]:
                assert h in body, f"{a['id']} missing {h}"
    print(f"OK: {len(arts)} articles in {path}")
    return 0


def cmd_generate(args: argparse.Namespace) -> int:
    base = os.environ.get("ZIMO_LEARNING_API_BASE") or os.environ.get("ANTHROPIC_BASE_URL")
    key = os.environ.get("ZIMO_LEARNING_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")
    model = os.environ.get("ZIMO_LEARNING_MODEL") or "deepseek-v4-pro"
    if not base or not key:
        raise SystemExit(
            "Set ZIMO_LEARNING_API_BASE and ZIMO_LEARNING_API_KEY "
            "(or ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN from CC Switch env)"
        )
    topic = args.topic
    article_id = args.id or re.sub(r"[^a-z0-9]+", "-", topic.lower()).strip("-")[:48]
    prompt = f"""你是中文财商专栏作者。请写一篇面向普通人的深度长文，主题：{topic}

要求：
1. 使用中文 Markdown
2. 必须包含 frontmatter（YAML），字段：id,title,category,icon,minutes,summary,key_points(list),action_tip,tags,published_at,updated_at,priority
3. id 使用：{article_id}
4. 正文必须有：## 导语、## 核心机制、## 案例、## 计算示例 / 对照、## 常见误区、## 今日行动、## 延伸阅读
5. 加入免责声明：不构成投资建议
6. 不要荐股、不要承诺收益
7. 字数约 1800-3500 汉字
只输出完整 markdown 文件内容。"""

    url = base.rstrip("/") + "/v1/messages"
    payload = {
        "model": model,
        "max_tokens": 4500,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "Authorization": f"Bearer {key}",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"API error {e.code}: {body[:500]}") from e

    text = ""
    content = data.get("content")
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") in {"text", "output_text"}:
                text += block.get("text") or ""
    if not text and isinstance(data.get("choices"), list):
        text = data["choices"][0].get("message", {}).get("content") or ""
    if not text:
        raise SystemExit(f"unexpected API response: {str(data)[:400]}")

    ARTICLES_DIR.mkdir(parents=True, exist_ok=True)
    path = ARTICLES_DIR / f"{article_id}.md"
    path.write_text(text.strip() + "\n", encoding="utf-8")
    print(f"generated {path}")

    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    else:
        manifest = {
            "format": "zimo-learning-pack",
            "version": 1,
            "pack_id": f"core-{date.today().strftime('%Y-%m')}",
            "articles": [],
        }
    arts = manifest.setdefault("articles", [])
    if not any(a.get("id") == article_id for a in arts):
        arts.append(
            {
                "id": article_id,
                "path": f"articles/{article_id}.md",
                "title": topic,
                "category": args.category,
                "icon": args.icon,
                "minutes": args.minutes,
                "summary": topic,
                "published_at": today(),
                "updated_at": today(),
                "priority": 100,
            }
        )
        CONTENT_DIR.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print("next: python tools/learning_pipeline/generate_daily.py pack")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Zimo learning content pipeline")
    sub = p.add_subparsers(dest="cmd", required=True)

    pack = sub.add_parser("pack", help="Build learning-pack.json from content/learning")
    pack.add_argument("--out", help="Output path")
    pack.set_defaults(func=cmd_pack)

    sc = sub.add_parser("scaffold", help="Create markdown stub")
    sc.add_argument("--id", required=True)
    sc.add_argument("--title")
    sc.add_argument("--category", default="财务基础")
    sc.add_argument("--icon", default="📘")
    sc.add_argument("--minutes", type=int, default=16)
    sc.add_argument("--summary")
    sc.add_argument("--force", action="store_true")
    sc.set_defaults(func=cmd_scaffold)

    val = sub.add_parser("validate", help="Validate a pack json")
    val.add_argument("path")
    val.add_argument("--require-long", action="store_true")
    val.set_defaults(func=cmd_validate)

    gen = sub.add_parser("generate", help="LLM-generate one article (needs env keys)")
    gen.add_argument("--topic", required=True)
    gen.add_argument("--id")
    gen.add_argument("--category", default="财务基础")
    gen.add_argument("--icon", default="✨")
    gen.add_argument("--minutes", type=int, default=18)
    gen.set_defaults(func=cmd_generate)
    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
