"""Telegram reporter — sends pipeline results via Telegram bot."""

import os

import requests


def send_report(result: dict) -> bool:
    """Send pipeline result summary via Telegram."""
    token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.getenv("TELEGRAM_CHAT_ID", "")

    if not token or not chat_id:
        return False

    icon = "\u2705" if result["passed"] else "\u274c"
    lines = [f"{icon} *Pipeline: {result['pipeline']}*", ""]

    for step in result.get("steps", []):
        icon_map = {"passed": "\u2705", "failed": "\u274c"}
        step_icon = icon_map.get(step["status"], "\u23ed\ufe0f")
        lines.append(f"{step_icon} {step['name']}: {step['status']}")

        errors = [f for f in step.get("findings", []) if f["severity"] == "error"]
        for finding in errors[:3]:
            lines.append(f"  \U0001f534 {finding['message'][:100]}")

    text = "\n".join(lines)

    try:
        resp = requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat_id, "text": text, "parse_mode": "Markdown"},
            timeout=10,
        )
        return resp.ok
    except Exception:
        return False
