"""Shared session-registry helpers for gs-cr / gs-op / gs-jira. Not directly executable."""
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SESSIONS_DIR = Path.home() / ".config" / "gs"
SESSIONS_PATH = SESSIONS_DIR / "sessions.json"
SCHEMA_VERSION = 1


def now_iso() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def load_sessions() -> dict:
    """Load the session registry, creating it on first run.

    On JSON corruption, the bad file is backed up (never silently discarded)
    and a fresh empty structure is returned instead of crashing.
    """
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    if not SESSIONS_PATH.exists():
        return {"version": SCHEMA_VERSION, "sessions": []}
    try:
        data = json.loads(SESSIONS_PATH.read_text())
        data.setdefault("sessions", [])
        data.setdefault("version", SCHEMA_VERSION)
        return data
    except (json.JSONDecodeError, OSError):
        corrupt_backup = SESSIONS_PATH.with_name(
            f"sessions.json.corrupt-{int(datetime.now().timestamp())}"
        )
        SESSIONS_PATH.rename(corrupt_backup)
        print(
            f"gs: sessions.json was corrupt, backed up to {corrupt_backup}",
            file=sys.stderr,
        )
        return {"version": SCHEMA_VERSION, "sessions": []}


def save_sessions(data: dict) -> None:
    """Atomic write: write to a temp file in the same dir, then os.replace."""
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=SESSIONS_DIR, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.replace(tmp_path, SESSIONS_PATH)
    except Exception:
        os.unlink(tmp_path)
        raise


def find_session(data: dict, session_name: str, project: str | None = None) -> dict | None:
    """Match by session_name, optionally disambiguated by project path."""
    matches = [s for s in data["sessions"] if s["session_name"] == session_name]
    if project:
        narrowed = [s for s in matches if s["project"] == project]
        if narrowed:
            matches = narrowed
    return matches[0] if matches else None


def find_sessions(data: dict, session_name: str) -> list[dict]:
    """Return all sessions matching session_name, across all projects."""
    return [s for s in data["sessions"] if s["session_name"] == session_name]


def upsert_session(data: dict, session: dict) -> None:
    """Replace the existing entry matching (session_name, project), or append."""
    for i, s in enumerate(data["sessions"]):
        if s["session_name"] == session["session_name"] and s["project"] == session["project"]:
            data["sessions"][i] = session
            return
    data["sessions"].append(session)
