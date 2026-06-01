#!/usr/bin/env python3
"""
mini-router: Telegram → tmux/opencode forwarder.

v1: 메시지 받아서 적절한 tmux 세션에 send-keys로 forwarding.
     결과 polling은 v2 (tmux pipe-pane 기반).

환경변수:
  TELEGRAM_BOT_TOKEN        필수 (또는 Keychain/secret-tool lookup)
  TELEGRAM_ALLOWED_USERS    콤마구분 user_id 리스트 (필수, 화이트리스트)
  TELEGRAM_ALLOWED_CHATS    콤마구분 chat_id 리스트 (선택, 추가 화이트리스트)
  WORKDIR_ROOT              기본 작업 디렉토리 (default: ~/dev)
  TMUX_DEFAULT_SESSION      기본 forwarding 대상 (default: oc-default)
  TOPIC_MAP_PATH            토픽 매핑 yaml (선택)
  ALLOW_RAW_SHELL_SESSIONS  "1"이면 oc-*/cc-* 외 세션 forwarding 허용 (기본: 차단)
  BOOT_WAIT_SECS            세션 cold start 시 CLI 부팅 대기 초 (default: 3)

라우팅 룰 (router SKILL의 핵심 subset):
  1. message_thread_id (Forum topic) → topic_map에서 워크디렉토리/세션 결정
  2. 명시 prefix (cc: / cc> / oc: / oc>) → 강제 하네스
  3. ulw 키워드 → 'ulw ' prepend + opencode 세션
  4. 그 외 → opencode 세션에 그대로 forwarding
"""
from __future__ import annotations
import asyncio
import logging
import os
import re
import subprocess
from pathlib import Path
from typing import Optional

import yaml
from telegram import Update
from telegram.ext import Application, ContextTypes, MessageHandler, filters, CommandHandler


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def keychain_token() -> str:
    """macOS Keychain → Linux secret-tool 순서로 토큰 lookup."""
    for cmd in (
        ["security", "find-generic-password", "-a", "hermes", "-s", "telegram-bot-token", "-w"],
        ["secret-tool", "lookup", "service", "hermes", "account", "telegram-bot-token"],
    ):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True)
        except FileNotFoundError:
            continue
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    return ""


def _expand(value: str) -> str:
    """expandvars → expanduser 순서로 확장.

    systemd EnvironmentFile은 $HOME 같은 변수를 확장하지 않으므로 여기서 직접 처리.
    """
    return os.path.expanduser(os.path.expandvars(value))


load_dotenv(Path.home() / ".hermes" / ".env")

# ─── 환경 (module-level은 안전한 기본값만 — 필수값 검증은 main()에서) ───
TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()

ALLOWED_USERS = {int(x) for x in os.environ.get("TELEGRAM_ALLOWED_USERS", "").split(",") if x.strip().lstrip("-").isdigit()}
ALLOWED_CHATS = {int(x) for x in os.environ.get("TELEGRAM_ALLOWED_CHATS", "").split(",") if x.strip().lstrip("-").isdigit()}

WORKDIR_ROOT = Path(_expand(os.environ.get("WORKDIR_ROOT", str(Path.home() / "dev"))))
TMUX_DEFAULT_SESSION = os.environ.get("TMUX_DEFAULT_SESSION", "oc-default")
TOPIC_MAP_PATH = _expand(os.environ.get("TOPIC_MAP_PATH", ""))
OPENCODE_CMD = os.environ.get("OPENCODE_CMD", "opencode")
CLAUDE_CMD = os.environ.get("CLAUDE_CMD", "claude")

try:
    BOOT_WAIT_SECS = float(os.environ.get("BOOT_WAIT_SECS", "3"))
except ValueError:
    BOOT_WAIT_SECS = 3.0


def raw_shell_allowed() -> bool:
    return os.environ.get("ALLOW_RAW_SHELL_SESSIONS", "").strip() == "1"


def is_allowed_context(user_id: int, chat_id: Optional[int]) -> bool:
    if user_id not in ALLOWED_USERS:
        return False
    if ALLOWED_CHATS and chat_id not in ALLOWED_CHATS:
        return False
    return True


# ─── 로깅 (basicConfig/파일 생성은 main()에서) ─────────
LOG_DIR = Path.home() / ".hermes" / "logs"
log = logging.getLogger("mini-router")

# ─── Topic map ─────────────────────────────────────────
# topic_map.yaml canonical 스키마 (mini-router bot.py + Hermes router 공용):
#   topics:
#     ops:                              # 사람이 읽는 토픽 이름 (키)
#       topic_id: 2                     # scripts/topic-discover.sh 로 확인한 message_thread_id
#       workdir: "~/dev/ops"            # 작업 디렉토리
#       session: "oc-ops"               # mini-router가 forwarding하는 tmux 세션 (oc-*/cc-*)
#       default_harness: "opencode"     # (선택) Hermes 라우터용 — session 없으면 mini-router가 세션 유도
#       skills_extra: []                # (선택) Hermes 라우터용
#       description: "..."              # (선택) Hermes 라우터용
#     "12": { workdir: "~/dev/<project-a>", session: "oc-project-a" }  # thread-id 숫자 문자열 직접 키도 허용
TOPIC_MAP: dict = {}


def load_topic_map() -> dict:
    if not TOPIC_MAP_PATH:
        return {}
    path = Path(TOPIC_MAP_PATH)
    if not path.exists():
        log.warning("TOPIC_MAP_PATH=%s 파일 없음 — topic 매핑 비활성화", TOPIC_MAP_PATH)
        return {}
    try:
        return yaml.safe_load(path.read_text()) or {}
    except Exception as e:
        log.warning("topic_map 읽기 실패: %s", e)
        return {}


def topic_info_for_thread(message_thread_id: Optional[int]) -> Optional[dict]:
    if message_thread_id is None or not isinstance(TOPIC_MAP, dict) or not TOPIC_MAP.get("topics"):
        return None

    topics = TOPIC_MAP["topics"]
    thread_key = str(message_thread_id)

    direct = topics.get(thread_key)
    if isinstance(direct, dict):
        return direct

    for name, info in topics.items():
        if not isinstance(info, dict):
            continue
        if str(info.get("topic_id", "")) == thread_key:
            merged = {"name": str(name)}
            merged.update(info)
            return merged

    return None


# ─── tmux helper ───────────────────────────────────────
def tmux_has_session(name: str) -> bool:
    r = subprocess.run(["tmux", "has-session", "-t", name], capture_output=True)
    return r.returncode == 0

def tmux_new_session(name: str, workdir: Path, cmd: Optional[str] = None) -> None:
    """detached 세션 생성. cmd 있으면 자동 실행."""
    workdir.mkdir(parents=True, exist_ok=True)
    args = ["tmux", "new-session", "-d", "-s", name, "-c", str(workdir)]
    if cmd:
        args.append(cmd)
    subprocess.run(args, check=True)

def tmux_send(session: str, text: str, press_enter: bool = True) -> None:
    """send-keys 리터럴 모드(-l)로 입력 후 Enter.

    -l + '--' 조합이라 '-'로 시작하는 텍스트도, 'Enter'/'C-c' 같은
    키 이름 문자열도 전부 그대로 텍스트로 전달된다.
    """
    subprocess.run(["tmux", "send-keys", "-t", session, "-l", "--", text], check=True)
    if press_enter:
        subprocess.run(["tmux", "send-keys", "-t", session, "Enter"], check=True)

def tmux_pane_command(session: str) -> str:
    """세션 active pane의 현재 실행 명령 (부팅 확인용). 실패 시 ''."""
    r = subprocess.run(
        ["tmux", "display-message", "-p", "-t", session, "#{pane_current_command}"],
        capture_output=True,
        text=True,
    )
    return r.stdout.strip() if r.returncode == 0 else ""

# ─── 라우팅 ────────────────────────────────────────────
_SHELLS = {"bash", "zsh", "sh", "dash", "fish"}


def _decision(target: str, session: str, workdir: Path, command: str, hint: str,
              reply: Optional[str] = None) -> dict:
    d = {
        "target": target,
        "session": session,
        "workdir": workdir,
        "command": command,
        "hint": hint,
        # oc-*/cc-* 하네스 세션이 아니면 bare shell로 새는 것 → 기본 차단 대상
        "raw_shell": target == "tmux" and not session.startswith(("oc-", "cc-")),
    }
    if reply is not None:
        d["reply"] = reply
    return d


def _named_session(prefix: str, topic_info: Optional[dict], fallback: str) -> str:
    name = str(topic_info.get("name", "")).strip() if topic_info else ""
    return f"{prefix}-{name}" if name else fallback


def _prefixed_session(prefix: str, topic_info: Optional[dict], topic_session: Optional[str]) -> str:
    """cc:/oc: 강제 prefix에 맞는 세션 이름 결정.

    topic 세션이 반대 하네스면 prefix 하네스로 변환한다:
      topic session 'oc-project-a' + 'cc:' → 'cc-project-a' ('cc-oc-project-a' 아님)
    이미 같은 하네스면 그대로, 둘 다 아니면 cc-<topic이름> / cc-default.
    """
    other = "oc" if prefix == "cc" else "cc"
    if topic_session:
        if topic_session.startswith(prefix + "-"):
            return topic_session
        if topic_session.startswith(other + "-"):
            return prefix + "-" + topic_session[len(other) + 1:]
    return _named_session(prefix, topic_info, f"{prefix}-default")


def route(message_text: str, message_thread_id: Optional[int]) -> dict:
    """
    라우팅 결정 반환:
      { target: 'tmux' | 'echo', session: str, workdir: Path, command: str,
        hint: str, raw_shell: bool, [reply: str] }
    """
    text = message_text.strip()

    # Topic 매핑
    topic_info = topic_info_for_thread(message_thread_id)

    topic_workdir = (
        Path(_expand(str(topic_info["workdir"])))
        if topic_info and "workdir" in topic_info
        else WORKDIR_ROOT
    )

    # topic 세션 결정 — session 필드 없으면 default_harness에서 유도
    topic_session = topic_info.get("session") if topic_info else None
    self_topic = False
    if topic_info and not topic_session:
        harness = topic_info.get("default_harness")
        name = str(topic_info.get("name", "")).strip()
        if harness == "claude-code":
            topic_session = f"cc-{name}" if name else "cc-default"
        elif harness == "opencode":
            topic_session = f"oc-{name}" if name else "oc-default"
        elif harness == "self":
            self_topic = True
        elif harness:
            # 미인식 값(오타 등)은 Default 규칙(opencode)으로 흘러감 — 조용한 오라우팅 방지용 경고
            log.warning("unknown default_harness=%r for topic %r — opencode로 fallback", harness, name)

    # Rule 1: 명시 prefix (cc:/cc> = claude, oc:/oc> = opencode)
    if text.startswith(("cc:", "cc>")):
        session = _prefixed_session("cc", topic_info, topic_session)
        return _decision("tmux", session, topic_workdir, text[3:].lstrip(), "cc forced")

    if text.startswith(("oc:", "oc>")):
        session = _prefixed_session("oc", topic_info, topic_session)
        return _decision("tmux", session, topic_workdir, text[3:].lstrip(), "oc forced")

    # Rule 2: default_harness: self → Hermes 없이 처리 불가 (bare shell forwarding 금지)
    if self_topic:
        return _decision(
            "echo", "", topic_workdir, "", "self harness",
            reply=(
                "이 토픽은 default_harness: self (Hermes가 직접 처리)로 설정돼 있습니다.\n"
                "mini-router v1은 tmux forwarding만 하므로 이 메시지는 전달하지 않았습니다.\n"
                "cc> / oc> prefix를 붙이면 해당 하네스 세션으로 강제 전달됩니다."
            ),
        )

    # Rule 3: ulw 키워드
    if re.search(r"\b(ulw|ultrawork)\b", text, re.IGNORECASE):
        session = topic_session or _named_session("oc", topic_info, "oc-default")
        return _decision(
            "tmux", session, topic_workdir,
            text if text.lower().startswith("ulw") else f"ulw {text}",
            "ulw burst",
        )

    # Rule 4: status / read-only → echo back (mini-router self response)
    if any(k in text for k in ["상태", "지금 뭐", "현재", "status"]) and len(text) < 30:
        return _decision("echo", "", topic_workdir, "", "status query")

    # Default: forward to opencode session
    session = topic_session or _named_session("oc", topic_info, TMUX_DEFAULT_SESSION)
    return _decision("tmux", session, topic_workdir, text, "default")

# ─── 핸들러 ────────────────────────────────────────────
async def on_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = update.effective_message
    user = update.effective_user
    chat = update.effective_chat

    # channel_post 등 user 없는 업데이트는 화이트리스트 검증 불가 → drop
    if msg is None or user is None:
        log.info("drop update without user (channel_post?) chat=%s",
                 chat.id if chat else "?")
        return

    chat_id = chat.id if chat else None

    # 화이트리스트
    if user.id not in ALLOWED_USERS:
        log.warning("rejected user %s (%s)", user.id, user.full_name)
        return
    if ALLOWED_CHATS and chat_id not in ALLOWED_CHATS:
        log.warning("rejected chat %s", chat_id)
        return

    text = msg.text or ""
    if not text.strip():
        return

    thread_id = msg.message_thread_id
    decision = route(text, thread_id)

    log.info("route: user=%s chat=%s thread=%s | %s | hint=%s",
             user.id, chat.id if chat else "?", thread_id, decision, decision["hint"])

    if decision["target"] == "echo":
        if decision.get("reply"):
            await msg.reply_text(decision["reply"])
        else:
            await msg.reply_text(
                f"[{decision['hint']}] mini-router v1 status:\n"
                f"- thread_id: {thread_id}\n"
                f"- allowed_users: {len(ALLOWED_USERS)}\n"
                f"- tmux sessions: see ssh\n"
                f"- log: ~/.hermes/logs/mini-router.log"
            )
        return

    # tmux forwarding
    session = decision["session"]
    workdir = decision["workdir"]
    command = decision["command"]

    # raw shell 가드: oc-*/cc-* 하네스 세션이 아니면 기본 거부
    if decision["raw_shell"] and not raw_shell_allowed():
        await msg.reply_text(
            f"✗ 세션 '{session}'은(는) oc-*/cc-* 하네스 세션이 아니라 forwarding을 거부했습니다.\n"
            "Telegram이 raw shell 원격 채널이 되는 것을 막는 기본 가드입니다.\n"
            "정말 허용하려면 ALLOW_RAW_SHELL_SESSIONS=1 을 설정하세요."
        )
        return

    cold_start = False
    try:
        if not tmux_has_session(session):
            log.info("creating tmux session: %s (workdir=%s)", session, workdir)
            # 코딩 CLI 자동 부팅 (oc-* → opencode, cc-* → claude)
            boot = None
            if session.startswith("oc-"):
                boot = OPENCODE_CMD
            elif session.startswith("cc-"):
                boot = CLAUDE_CMD  # claude CLI 없으면 그냥 빈 세션
            tmux_new_session(session, workdir, cmd=boot)
            cold_start = True
            await asyncio.sleep(BOOT_WAIT_SECS)

        tmux_send(session, command, press_enter=True)
    except Exception as e:
        log.error("tmux forwarding 실패: session=%s err=%s", session, e)
        await msg.reply_text(f"✗ tmux forwarding 실패 (session={session}):\n{e}")
        return

    cold_note = ""
    if cold_start:
        # 방금 만든 세션이면 CLI가 부팅됐는지 잠깐 확인 (짧은 poll — 완벽 보장은 아님)
        pane_cmd = ""
        for _ in range(3):
            pane_cmd = tmux_pane_command(session)
            if pane_cmd and pane_cmd not in _SHELLS:
                break
            await asyncio.sleep(1)
        cold_note = (
            f"\n  ⚠ 세션을 방금 생성함 (cold start, pane: {pane_cmd or '?'})."
            "\n    CLI가 아직 부팅 중이었다면 명령이 씹혔을 수 있음 → 그 경우 재전송하세요."
        )

    await msg.reply_text(
        f"✓ [{decision['hint']}] → tmux:{session}\n"
        f"  workdir: {workdir}\n"
        f"  cmd: `{command[:100]}{'...' if len(command) > 100 else ''}`\n"
        f"  (결과는 ssh로 attach: tmux a -t {session})"
        f"{cold_note}",
        parse_mode=None,
    )

async def on_non_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """음성/사진 등 비텍스트 메시지 — v1은 텍스트 전용임을 정직하게 답장."""
    msg = update.effective_message
    user = update.effective_user
    chat = update.effective_chat
    chat_id = chat.id if chat else None
    if msg is None or user is None:
        return
    if not is_allowed_context(user.id, chat_id):
        return
    await msg.reply_text(
        "mini-router v1은 텍스트 메시지만 처리합니다.\n"
        "음성 노트(STT)·사진 라우팅은 Hermes 경로가 필요합니다 — 텍스트로 다시 보내주세요."
    )

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    msg = update.effective_message
    chat = update.effective_chat
    chat_id = chat.id if chat else None
    if msg is None or user is None:
        return
    if not is_allowed_context(user.id, chat_id):
        return
    await msg.reply_text(
        "mini-router v1 active.\n"
        f"- allowed_users: {len(ALLOWED_USERS)}\n"
        f"- topic_map: {'loaded' if TOPIC_MAP else 'empty'}\n"
        f"- default session: {TMUX_DEFAULT_SESSION}\n"
        "\n"
        "라우팅 룰 (subset):\n"
        "  cc> 텍스트  → tmux cc-* 세션\n"
        "  oc> 텍스트  → tmux oc-* 세션\n"
        "  ulw 텍스트  → opencode + ulw prepend\n"
        "  상태        → 이 status 출력\n"
        "  그 외       → 기본 oc-default 세션에 forwarding"
    )

async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    """핸들러에서 새어나온 예외 — 로그 + (가능하면) 사용자에게 답장."""
    log.error("handler 오류: %s", context.error, exc_info=context.error)
    try:
        user = getattr(update, "effective_user", None)
        chat = getattr(update, "effective_chat", None)
        chat_id = chat.id if chat else None
        if user is None or not is_allowed_context(user.id, chat_id):
            return
        msg = getattr(update, "effective_message", None)
        if msg is not None:
            await msg.reply_text(f"✗ mini-router 내부 오류: {context.error}")
    except Exception:
        pass  # best-effort — 답장 실패는 로그로 충분

# ─── main ──────────────────────────────────────────────
def main():
    global TOPIC_MAP

    token = TOKEN or keychain_token()
    if not token:
        raise SystemExit("TELEGRAM_BOT_TOKEN 미설정 (Keychain/secret-tool 또는 ~/.hermes/.env)")
    if not ALLOWED_USERS:
        raise SystemExit("TELEGRAM_ALLOWED_USERS 미설정 (안전 가드)")

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(LOG_DIR / "mini-router.log"),
            logging.StreamHandler(),
        ],
    )

    TOPIC_MAP = load_topic_map()

    log.info("mini-router v1 시작. allowed_users=%d allowed_chats=%d topic_map=%s",
             len(ALLOWED_USERS), len(ALLOWED_CHATS), "loaded" if TOPIC_MAP else "empty")

    app = Application.builder().token(token).build()
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_message))
    app.add_handler(MessageHandler(~filters.TEXT & ~filters.COMMAND, on_non_text))
    app.add_error_handler(on_error)
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
