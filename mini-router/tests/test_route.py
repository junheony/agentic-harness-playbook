"""route() 라우팅 로직 테스트 — stdlib unittest 전용.

3rd-party 의존성(python-telegram-bot, PyYAML) 없이 돌아가도록,
bot import 전에 fake 'telegram' / 'telegram.ext' / 'yaml' 모듈을
sys.modules에 주입한다 (conftest 대용).

실행 (repo 루트에서):

    python3 -m unittest discover -s mini-router/tests -v
"""
import os
import sys
import types
import unittest
from pathlib import Path

# ─── 1) bot import 전에 환경변수 고정 ─────────────────────────────
# bot.py는 import 시 env 없이도 동작해야 하지만 (side-effect-free import),
# 모듈 상수가 env를 읽으므로 테스트 재현성을 위해 미리 고정한다.
os.environ["TELEGRAM_ALLOWED_USERS"] = "1"
os.environ["TELEGRAM_ALLOWED_CHATS"] = ""
os.environ["WORKDIR_ROOT"] = "/tmp/mini-router-test/dev"
os.environ["TMUX_DEFAULT_SESSION"] = "oc-default"
os.environ["TOPIC_MAP_PATH"] = ""
os.environ["BOOT_WAIT_SECS"] = "0"
os.environ.pop("ALLOW_RAW_SHELL_SESSIONS", None)


# ─── 2) fake 모듈 주입 (import bot 이전에 반드시 실행) ────────────
class _Anything:
    """호출/속성접근/연산 전부 자기 자신을 반환하는 만능 stub."""

    def __call__(self, *args, **kwargs):
        return self

    def __getattr__(self, name):
        return self

    def __and__(self, other):
        return self

    def __or__(self, other):
        return self

    def __invert__(self):
        return self


def _install_stubs():
    telegram = types.ModuleType("telegram")

    class Update:
        ALL_TYPES = None

    telegram.Update = Update

    telegram_ext = types.ModuleType("telegram.ext")
    telegram_ext.Application = _Anything()
    telegram_ext.ContextTypes = _Anything()
    telegram_ext.MessageHandler = _Anything()
    telegram_ext.CommandHandler = _Anything()
    telegram_ext.filters = _Anything()
    telegram.ext = telegram_ext

    yaml_stub = types.ModuleType("yaml")
    yaml_stub.safe_load = lambda *_a, **_k: {}

    sys.modules["telegram"] = telegram
    sys.modules["telegram.ext"] = telegram_ext
    sys.modules["yaml"] = yaml_stub


_install_stubs()

# ─── 3) bot import (mini-router/ 를 sys.path에 추가) ──────────────
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bot  # noqa: E402


class ImportPurityTest(unittest.TestCase):
    """g) import 자체는 SystemExit/토큰 요구 없이 성공해야 한다."""

    def test_import_succeeded_without_token(self):
        self.assertTrue(callable(bot.route))
        self.assertTrue(callable(bot.topic_info_for_thread))
        self.assertTrue(callable(bot.main))
        self.assertIsInstance(bot.TOPIC_MAP, dict)

    def test_route_pure_without_topic_map(self):
        d = bot.route("hello", None)
        self.assertEqual(d["target"], "tmux")


class RouteTestCase(unittest.TestCase):
    def setUp(self):
        self._saved = bot.TOPIC_MAP
        self._saved_users = bot.ALLOWED_USERS
        self._saved_chats = bot.ALLOWED_CHATS
        bot.TOPIC_MAP = {}

    def tearDown(self):
        bot.TOPIC_MAP = self._saved
        bot.ALLOWED_USERS = self._saved_users
        bot.ALLOWED_CHATS = self._saved_chats

    def set_topics(self, topics):
        bot.TOPIC_MAP = {"topics": topics}

    # ─── allowlist gate ─────────────────────────────────────────
    def test_allowed_context_allows_user_when_chat_allowlist_empty(self):
        bot.ALLOWED_USERS = {1}
        bot.ALLOWED_CHATS = set()
        self.assertTrue(bot.is_allowed_context(1, 123))

    def test_allowed_context_rejects_unknown_user(self):
        bot.ALLOWED_USERS = {1}
        bot.ALLOWED_CHATS = set()
        self.assertFalse(bot.is_allowed_context(2, 123))

    def test_allowed_context_rejects_disallowed_chat(self):
        bot.ALLOWED_USERS = {1}
        bot.ALLOWED_CHATS = {100}
        self.assertTrue(bot.is_allowed_context(1, 100))
        self.assertFalse(bot.is_allowed_context(1, 200))
        self.assertFalse(bot.is_allowed_context(1, None))

    # ─── prefix 룰 ────────────────────────────────────────────────
    def test_cc_colon_prefix_no_topic(self):
        d = bot.route("cc: fix the login bug", None)
        self.assertEqual(d["target"], "tmux")
        self.assertEqual(d["session"], "cc-default")
        self.assertEqual(d["command"], "fix the login bug")
        self.assertEqual(d["hint"], "cc forced")
        self.assertFalse(d["raw_shell"])

    def test_cc_arrow_prefix_no_topic(self):
        d = bot.route("cc> hello there", None)
        self.assertEqual(d["session"], "cc-default")
        self.assertEqual(d["command"], "hello there")

    def test_oc_colon_prefix_no_topic(self):
        d = bot.route("oc: run tests", None)
        self.assertEqual(d["session"], "oc-default")
        self.assertEqual(d["command"], "run tests")
        self.assertEqual(d["hint"], "oc forced")

    def test_oc_arrow_prefix_no_topic(self):
        d = bot.route("oc> run tests", None)
        self.assertEqual(d["session"], "oc-default")

    # h) 하네스 전환: oc-* topic 세션 + cc: prefix → cc-* (cc-oc-* 아님)
    def test_cc_prefix_converts_oc_topic_session(self):
        self.set_topics({"project-a": {
            "topic_id": 42, "workdir": "~/dev/<project-a>", "session": "oc-project-a"}})
        d = bot.route("cc: review this", 42)
        self.assertEqual(d["session"], "cc-project-a")
        self.assertFalse(d["raw_shell"])

    def test_cc_prefix_keeps_cc_topic_session(self):
        self.set_topics({"project-a": {
            "topic_id": 42, "workdir": "~/dev/<project-a>", "session": "cc-project-a"}})
        d = bot.route("cc: go", 42)
        self.assertEqual(d["session"], "cc-project-a")

    def test_oc_prefix_converts_cc_topic_session(self):
        self.set_topics({"project-a": {
            "topic_id": 42, "workdir": "~/dev/<project-a>", "session": "cc-project-a"}})
        d = bot.route("oc: go", 42)
        self.assertEqual(d["session"], "oc-project-a")

    def test_cc_prefix_weird_topic_session_falls_back_to_topic_name(self):
        self.set_topics({"ops": {"topic_id": 7, "workdir": "~/dev/ops", "session": "myshell"}})
        d = bot.route("cc: go", 7)
        self.assertEqual(d["session"], "cc-ops")

    # ─── ulw 룰 ───────────────────────────────────────────────────
    def test_ulw_keyword_prepends(self):
        d = bot.route("please ultrawork on this", None)
        self.assertEqual(d["hint"], "ulw burst")
        self.assertEqual(d["command"], "ulw please ultrawork on this")
        self.assertEqual(d["session"], "oc-default")

    def test_ulw_prefix_not_duplicated(self):
        d = bot.route("ulw fix the tests", None)
        self.assertEqual(d["command"], "ulw fix the tests")

    def test_ulw_uses_topic_session(self):
        self.set_topics({"ops": {"topic_id": 2, "workdir": "~/dev/ops", "session": "oc-ops"}})
        d = bot.route("ulw clean the queue", 2)
        self.assertEqual(d["session"], "oc-ops")

    # ─── status echo 룰 ──────────────────────────────────────────
    def test_status_echo_english(self):
        d = bot.route("status", None)
        self.assertEqual(d["target"], "echo")
        self.assertEqual(d["hint"], "status query")
        self.assertFalse(d["raw_shell"])

    def test_status_echo_korean(self):
        d = bot.route("상태", None)
        self.assertEqual(d["target"], "echo")

    def test_long_text_with_status_word_is_forwarded(self):
        text = "status of the deployment pipeline please check everything"
        d = bot.route(text, None)
        self.assertEqual(d["target"], "tmux")

    # ─── topic_map 매칭 ──────────────────────────────────────────
    def test_thread_id_direct_string_key(self):
        self.set_topics({"42": {"workdir": "~/dev/ops", "session": "oc-ops"}})
        d = bot.route("hello", 42)
        self.assertEqual(d["session"], "oc-ops")
        self.assertEqual(d["workdir"], Path(os.path.expanduser("~/dev/ops")))

    def test_topic_id_field_match(self):
        self.set_topics({"ops": {"topic_id": 7, "workdir": "~/dev/ops", "session": "oc-ops"}})
        d = bot.route("hello", 7)
        self.assertEqual(d["session"], "oc-ops")

    def test_unknown_thread_falls_back_to_default(self):
        self.set_topics({"ops": {"topic_id": 7, "workdir": "~/dev/ops", "session": "oc-ops"}})
        d = bot.route("hello", 999)
        self.assertEqual(d["session"], bot.TMUX_DEFAULT_SESSION)
        self.assertEqual(d["workdir"], bot.WORKDIR_ROOT)

    # ─── i) default_harness fallback ─────────────────────────────
    def test_default_harness_claude_code_derives_cc_session(self):
        self.set_topics({"research": {
            "topic_id": 8, "workdir": "~/dev/research", "default_harness": "claude-code"}})
        d = bot.route("hello", 8)
        self.assertEqual(d["session"], "cc-research")
        self.assertFalse(d["raw_shell"])

    def test_default_harness_opencode_derives_oc_session(self):
        self.set_topics({"ops": {
            "topic_id": 2, "workdir": "~/dev/ops", "default_harness": "opencode"}})
        d = bot.route("hello", 2)
        self.assertEqual(d["session"], "oc-ops")

    def test_default_harness_self_is_echo_with_reply(self):
        self.set_topics({"general": {
            "topic_id": 1, "workdir": "~/dev", "default_harness": "self"}})
        d = bot.route("hello", 1)
        self.assertEqual(d["target"], "echo")
        self.assertIn("Hermes", d.get("reply", ""))
        self.assertFalse(d["raw_shell"])

    def test_default_harness_self_cc_prefix_still_forwards(self):
        self.set_topics({"general": {
            "topic_id": 1, "workdir": "~/dev", "default_harness": "self"}})
        d = bot.route("cc: go anyway", 1)
        self.assertEqual(d["target"], "tmux")
        self.assertEqual(d["session"], "cc-general")

    # ─── default forwarding ──────────────────────────────────────
    def test_default_forwarding(self):
        d = bot.route("just do something useful", None)
        self.assertEqual(d["target"], "tmux")
        self.assertEqual(d["session"], bot.TMUX_DEFAULT_SESSION)
        self.assertEqual(d["command"], "just do something useful")
        self.assertEqual(d["hint"], "default")
        self.assertEqual(d["workdir"], bot.WORKDIR_ROOT)

    # ─── c) raw shell 가드 flag ──────────────────────────────────
    def test_raw_shell_flag_true_on_non_harness_session(self):
        self.set_topics({"legacy": {"topic_id": 3, "workdir": "~/dev", "session": "myshell"}})
        d = bot.route("hello", 3)
        self.assertEqual(d["session"], "myshell")
        self.assertTrue(d["raw_shell"])

    def test_raw_shell_flag_false_on_harness_sessions(self):
        self.assertFalse(bot.route("hello", None)["raw_shell"])
        self.assertFalse(bot.route("cc: hi", None)["raw_shell"])
        self.assertFalse(bot.route("oc: hi", None)["raw_shell"])

    def test_raw_shell_allowed_env_toggle(self):
        os.environ.pop("ALLOW_RAW_SHELL_SESSIONS", None)
        self.assertFalse(bot.raw_shell_allowed())
        os.environ["ALLOW_RAW_SHELL_SESSIONS"] = "1"
        try:
            self.assertTrue(bot.raw_shell_allowed())
        finally:
            os.environ.pop("ALLOW_RAW_SHELL_SESSIONS", None)


if __name__ == "__main__":
    unittest.main()
