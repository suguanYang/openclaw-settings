#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Final, Iterable, Mapping

STATE_VERSION: Final[int] = 1
DEFAULT_QUERY_LIMIT: Final[int] = 200
DEFAULT_MAX_GROUPS_PER_MESSAGE: Final[int] = 3
DEFAULT_SUPPRESSION_MINUTES: Final[int] = 360
DEFAULT_TIMEOUT_SECONDS: Final[int] = 120
DEFAULT_STATE_PATH: Final[str] = "~/.openclaw/integrations/logfire-alerts/state.json"
DEFAULT_MCP_COMMAND: Final[str] = "uvx logfire-mcp@latest"
DEFAULT_MCP_ENDPOINT: Final[str] = ""
DEFAULT_MCP_TRANSPORT: Final[str] = "auto"
DEFAULT_AGENT_ID: Final[str] = "tracker"
DEFAULT_DISCORD_ACCOUNT: Final[str] = "tracker"
DEFAULT_PROJECT: Final[str] = "knowhere-api"
DEFAULT_SERVICE: Final[str] = ""
DEFAULT_ENVIRONMENT: Final[str] = "production"
DEFAULT_LEVEL_NAME: Final[str] = "error"
DEFAULT_AGE: Final[str] = "15m"
DEFAULT_PROJECT_URL: Final[str] = ""
DEFAULT_CHANNEL_TARGET: Final[str] = "channel:565501941510045707"
DEFAULT_MCP_HTTP_TIMEOUT_SECONDS: Final[int] = 30
DEFAULT_MCP_USER_AGENT: Final[str] = "openclaw-logfire-alert-poller/1.0"
DEFAULT_NODE_MCP_SDK_VERSION: Final[str] = "1.27.1"
DEFAULT_MCP_HELPER_PATH: Final[str] = (
    "~/.local/share/logfire-alert-poller/query-logfire.mjs"
)


class PollerError(RuntimeError):
    pass


@dataclass(frozen=True)
class Settings:
    mcp_transport: str
    mcp_command: str
    mcp_endpoint: str | None
    mcp_http_timeout_seconds: int
    read_token: str
    service_name: str
    environment_name: str
    level_name: str
    project_name: str
    project_url: str | None
    age: str
    query_limit: int
    max_groups_per_message: int
    suppression_minutes: int
    state_path: Path
    agent_id: str
    discord_target: str
    discord_account: str
    openclaw_timeout_seconds: int
    query_override: str | None

    @classmethod
    def from_env(cls, *, require_token: bool = True) -> "Settings":
        read_token = require_env("LOGFIRE_READ_TOKEN") if require_token else ""
        service_name = read_optional_env("LOGFIRE_ALERT_SERVICE", DEFAULT_SERVICE)
        environment_name = read_optional_env(
            "LOGFIRE_ALERT_ENVIRONMENT",
            DEFAULT_ENVIRONMENT,
        )
        level_name = read_optional_env(
            "LOGFIRE_ALERT_LEVEL",
            DEFAULT_LEVEL_NAME,
        )
        state_path = Path(
            os.environ.get("LOGFIRE_ALERT_STATE_PATH", DEFAULT_STATE_PATH),
        ).expanduser()
        channel_id = os.environ.get("OPENCLAW_DISCORD_CHANNEL_ID", "").strip()
        default_target = (
            f"channel:{channel_id}" if channel_id else DEFAULT_CHANNEL_TARGET
        )
        mcp_endpoint = os.environ.get("LOGFIRE_MCP_ENDPOINT", DEFAULT_MCP_ENDPOINT).strip()
        raw_transport = os.environ.get("LOGFIRE_MCP_TRANSPORT", DEFAULT_MCP_TRANSPORT).strip()
        mcp_transport = resolve_mcp_transport(raw_transport, mcp_endpoint)
        project_url = os.environ.get("LOGFIRE_ALERT_PROJECT_URL", DEFAULT_PROJECT_URL).strip()
        query_override = os.environ.get("LOGFIRE_ALERT_QUERY", "").strip()
        return cls(
            mcp_transport=mcp_transport,
            mcp_command=os.environ.get("LOGFIRE_MCP_COMMAND", DEFAULT_MCP_COMMAND).strip()
            or DEFAULT_MCP_COMMAND,
            mcp_endpoint=mcp_endpoint or None,
            mcp_http_timeout_seconds=parse_positive_int(
                os.environ.get("LOGFIRE_MCP_HTTP_TIMEOUT_SECONDS"),
                DEFAULT_MCP_HTTP_TIMEOUT_SECONDS,
                "LOGFIRE_MCP_HTTP_TIMEOUT_SECONDS",
            ),
            read_token=read_token,
            service_name=service_name,
            environment_name=environment_name,
            level_name=level_name,
            project_name=os.environ.get("LOGFIRE_ALERT_PROJECT", DEFAULT_PROJECT).strip()
            or DEFAULT_PROJECT,
            project_url=project_url or None,
            age=os.environ.get("LOGFIRE_ALERT_AGE", DEFAULT_AGE).strip() or DEFAULT_AGE,
            query_limit=parse_positive_int(
                os.environ.get("LOGFIRE_ALERT_QUERY_LIMIT"),
                DEFAULT_QUERY_LIMIT,
                "LOGFIRE_ALERT_QUERY_LIMIT",
            ),
            max_groups_per_message=parse_positive_int(
                os.environ.get("LOGFIRE_ALERT_MAX_GROUPS_PER_MESSAGE"),
                DEFAULT_MAX_GROUPS_PER_MESSAGE,
                "LOGFIRE_ALERT_MAX_GROUPS_PER_MESSAGE",
            ),
            suppression_minutes=parse_positive_int(
                os.environ.get("LOGFIRE_ALERT_SUPPRESSION_MINUTES"),
                DEFAULT_SUPPRESSION_MINUTES,
                "LOGFIRE_ALERT_SUPPRESSION_MINUTES",
            ),
            state_path=state_path,
            agent_id=os.environ.get("LOGFIRE_ALERT_AGENT_ID", DEFAULT_AGENT_ID).strip()
            or DEFAULT_AGENT_ID,
            discord_target=os.environ.get("LOGFIRE_ALERT_DISCORD_TARGET", default_target).strip()
            or default_target,
            discord_account=os.environ.get(
                "LOGFIRE_ALERT_DISCORD_ACCOUNT",
                DEFAULT_DISCORD_ACCOUNT,
            ).strip()
            or DEFAULT_DISCORD_ACCOUNT,
            openclaw_timeout_seconds=parse_positive_int(
                os.environ.get("LOGFIRE_ALERT_TIMEOUT_SECONDS"),
                DEFAULT_TIMEOUT_SECONDS,
                "LOGFIRE_ALERT_TIMEOUT_SECONDS",
            ),
            query_override=query_override or None,
        )


@dataclass(frozen=True)
class ExceptionEvent:
    created_at: dt.datetime
    service_name: str
    environment_name: str
    exception_type: str
    exception_message: str
    route: str
    method: str
    status_code: str
    trace_id: str
    fingerprint: str | None


@dataclass(frozen=True)
class AlertGroup:
    alert_key: str
    service_name: str
    environment_name: str
    exception_type: str
    exception_message: str
    route: str
    method: str
    status_code: str
    first_seen_at: dt.datetime
    last_seen_at: dt.datetime
    occurrence_count: int
    trace_ids: tuple[str, ...]
    fingerprint: str | None
    notification_reason: str


def poll_groups(settings: Settings) -> list[AlertGroup]:
    tool_result = call_logfire_query_tool(settings)
    raw_rows = extract_rows_from_tool_result(tool_result)
    events = normalize_events(raw_rows, settings)
    return group_events(events)


def call_logfire_query_tool(settings: Settings) -> dict[str, Any]:
    helper_command = build_mcp_helper_command()
    query = settings.query_override or build_default_query(settings)
    command = [
        *helper_command,
        "--query",
        query,
        "--age-minutes",
        str(parse_logfire_age_minutes(settings.age)),
    ]
    if settings.project_name:
        command.extend(["--project", settings.project_name])
    helper_env = os.environ.copy()
    helper_env.setdefault("LOGFIRE_MCP_USER_AGENT", DEFAULT_MCP_USER_AGENT)
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        env=helper_env,
        timeout=settings.mcp_http_timeout_seconds + 30,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise PollerError(
            "Logfire MCP helper failed"
            + (f": {detail}" if detail else f" with exit code {completed.returncode}"),
        )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as err:
        raise PollerError(
            "Logfire MCP helper returned invalid JSON output",
        ) from err
    if not isinstance(payload, dict):
        raise PollerError("Logfire MCP helper returned a non-object JSON payload")
    return payload


def build_mcp_helper_command() -> list[str]:
    configured = os.environ.get("LOGFIRE_MCP_HELPER_COMMAND", "").strip()
    if configured:
        parts = shlex.split(configured)
        if parts:
            return parts
        raise PollerError("LOGFIRE_MCP_HELPER_COMMAND resolved to an empty command")
    helper_path = Path(DEFAULT_MCP_HELPER_PATH).expanduser()
    if not helper_path.is_file():
        raise PollerError(
            "Logfire MCP helper script is missing; deploy "
            f"@modelcontextprotocol/sdk@{DEFAULT_NODE_MCP_SDK_VERSION} helper assets first",
        )
    return [
        resolve_node_bin(),
        str(helper_path),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Poll Logfire exceptions and hand off alerts to OpenClaw tracker.",
    )
    parser.add_argument(
        "--print-default-query",
        action="store_true",
        help="Print the default Logfire SQL query and exit.",
    )
    args = parser.parse_args()

    settings = Settings.from_env(require_token=not args.print_default_query)
    if args.print_default_query:
        print(build_default_query(settings))
        return 0

    lock_path = settings.state_path.with_suffix(".lock")
    settings.state_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        state = load_state(settings.state_path)
        groups = poll_groups(settings)
        groups_to_notify = filter_groups_for_notification(groups, state, settings)
        if not groups_to_notify:
            save_state(settings.state_path, refresh_state(state, groups))
            print("No new Logfire exception groups to notify.")
            return 0

        tracker_message = build_tracker_message(groups_to_notify, settings)
        send_tracker_alert(tracker_message, settings)
        updated_state = apply_delivered_groups(state, groups, groups_to_notify)
        save_state(settings.state_path, updated_state)
        print(
            f"Delivered Logfire alert digest for {len(groups_to_notify)} group(s) via tracker.",
        )
        return 0


def build_default_query(settings: Settings) -> str:
    service_filter = (
        f"  AND service_name = '{escape_sql_string(settings.service_name)}'\n"
        if settings.service_name
        else ""
    )
    environment_filter = (
        f"  AND deployment_environment = '{escape_sql_string(settings.environment_name)}'\n"
        if settings.environment_name
        else ""
    )
    level_filter = (
        f"    OR level = '{escape_sql_string(settings.level_name)}'\n"
        if settings.level_name
        else ""
    )
    return (
        "SELECT\n"
        "  created_at,\n"
        "  service_name,\n"
        "  deployment_environment,\n"
        "  exception_type,\n"
        "  exception_message,\n"
        "  trace_id,\n"
        "  http_route,\n"
        "  url_path,\n"
        "  http_method,\n"
        "  http_response_status_code\n"
        "FROM records\n"
        "WHERE (\n"
        "  is_exception = true\n"
        f"{level_filter}"
        ")\n"
        f"{service_filter}"
        f"{environment_filter}"
        "ORDER BY created_at DESC\n"
        f"LIMIT {settings.query_limit}"
    )


def extract_rows_from_tool_result(result: Mapping[str, Any]) -> list[dict[str, Any]]:
    structured = result.get("structuredContent")
    rows, found = extract_rows_from_value(structured)
    if found:
        return rows
    content = result.get("content")
    if isinstance(content, list):
        text_blobs: list[str] = []
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") != "text":
                continue
            text = str(item.get("text", "")).strip()
            if not text:
                continue
            text_blobs.append(text)
            parsed_json = try_parse_json(text)
            rows, found = extract_rows_from_value(parsed_json)
            if found:
                return rows
            rows = parse_markdown_table(text)
            if rows:
                return rows
        joined = "\n".join(text_blobs).strip()
        rows = parse_markdown_table(joined)
        if rows:
            return rows
    raise PollerError("unable to extract query rows from Logfire MCP response")


def extract_rows_from_value(value: Any) -> tuple[list[dict[str, Any]], bool]:
    if isinstance(value, list):
        if all(isinstance(item, dict) for item in value):
            return [dict(item) for item in value], True
        return [], False
    if not isinstance(value, dict):
        return [], False
    for key in ("rows", "records", "results", "data", "items", "exceptions"):
        if key not in value:
            continue
        candidate = value.get(key)
        if isinstance(candidate, list) and all(isinstance(item, dict) for item in candidate):
            return [dict(item) for item in candidate], True
        return [], False
    if all(not isinstance(item, (dict, list)) for item in value.values()):
        return [dict(value)], True
    return [], False


def parse_markdown_table(text: str) -> list[dict[str, str]]:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    table_start = None
    for index in range(len(lines) - 1):
        if "|" not in lines[index]:
            continue
        separator = lines[index + 1].replace("|", "").strip()
        if separator and set(separator) <= {"-", ":", " "}:
            table_start = index
            break
    if table_start is None:
        return []
    table_lines: list[str] = []
    for line in lines[table_start:]:
        if "|" not in line:
            break
        table_lines.append(line.strip())
    if len(table_lines) < 3:
        return []
    headers = parse_table_row(table_lines[0])
    if not headers:
        return []
    rows: list[dict[str, str]] = []
    for line in table_lines[2:]:
        values = parse_table_row(line)
        if not values:
            continue
        padded_values = values[: len(headers)] + [""] * max(0, len(headers) - len(values))
        row = {headers[index]: padded_values[index] for index in range(len(headers))}
        rows.append(row)
    return rows


def parse_table_row(line: str) -> list[str]:
    trimmed = line.strip().strip("|")
    if not trimmed:
        return []
    return [part.strip() for part in trimmed.split("|")]


def normalize_events(rows: Iterable[Mapping[str, Any]], settings: Settings) -> list[ExceptionEvent]:
    events: list[ExceptionEvent] = []
    for row in rows:
        created_at = parse_datetime(
            first_non_empty(
                row,
                "created_at",
                "timestamp",
                "time",
            ),
        )
        if created_at is None:
            continue
        service_name = normalize_text(
            first_non_empty(row, "service_name", "service", "service.name"),
        )
        environment_name = normalize_text(
            first_non_empty(
                row,
                "deployment_environment",
                "environment",
                "deployment.environment.name",
            ),
        )
        exception_type = normalize_text(
            first_non_empty(row, "exception_type", "type"),
        )
        exception_message = normalize_text(
            first_non_empty(row, "exception_message", "message", "exception"),
        )
        if not exception_type and not exception_message:
            continue
        route = normalize_text(
            first_non_empty(row, "http_route", "route", "url_path", "path"),
        )
        method = normalize_text(first_non_empty(row, "http_method", "method"))
        status_code = normalize_text(
            first_non_empty(
                row,
                "http_response_status_code",
                "status",
                "http.status_code",
            ),
        )
        trace_id = normalize_text(first_non_empty(row, "trace_id", "sample_trace_id"))
        fingerprint = normalize_text(
            first_non_empty(row, "fingerprint", "exception_fingerprint"),
        )
        if settings.service_name and service_name and service_name != settings.service_name:
            continue
        if (
            settings.environment_name
            and environment_name
            and environment_name != settings.environment_name
        ):
            continue
        events.append(
            ExceptionEvent(
                created_at=created_at,
                service_name=service_name or settings.service_name,
                environment_name=environment_name or settings.environment_name,
                exception_type=exception_type or "(unknown exception type)",
                exception_message=exception_message or "(no exception message)",
                route=route or "(unknown route)",
                method=method or "(unknown method)",
                status_code=status_code or "(unknown status)",
                trace_id=trace_id,
                fingerprint=fingerprint or None,
            ),
        )
    return events


def group_events(events: Iterable[ExceptionEvent]) -> list[AlertGroup]:
    grouped: dict[str, list[ExceptionEvent]] = {}
    for event in events:
        key = build_alert_key(event)
        grouped.setdefault(key, []).append(event)
    groups: list[AlertGroup] = []
    for key, entries in grouped.items():
        sorted_entries = sorted(entries, key=lambda item: item.created_at)
        first_entry = sorted_entries[0]
        last_entry = sorted_entries[-1]
        trace_ids = unique_items(
            entry.trace_id for entry in reversed(sorted_entries) if entry.trace_id
        )
        groups.append(
            AlertGroup(
                alert_key=key,
                service_name=first_entry.service_name,
                environment_name=first_entry.environment_name,
                exception_type=first_entry.exception_type,
                exception_message=first_entry.exception_message,
                route=first_entry.route,
                method=first_entry.method,
                status_code=first_entry.status_code,
                first_seen_at=first_entry.created_at,
                last_seen_at=last_entry.created_at,
                occurrence_count=len(entries),
                trace_ids=trace_ids[:3],
                fingerprint=first_entry.fingerprint,
                notification_reason="new",
            ),
        )
    return sorted(groups, key=lambda item: item.last_seen_at, reverse=True)


def filter_groups_for_notification(
    groups: list[AlertGroup],
    state: dict[str, Any],
    settings: Settings,
) -> list[AlertGroup]:
    alerts_state = state.get("alerts", {})
    if not isinstance(alerts_state, dict):
        alerts_state = {}
    threshold = dt.timedelta(minutes=settings.suppression_minutes)
    groups_to_notify: list[AlertGroup] = []
    for group in groups:
        raw_entry = alerts_state.get(group.alert_key)
        if not isinstance(raw_entry, dict):
            groups_to_notify.append(group)
            continue
        last_delivered_at = parse_datetime(raw_entry.get("lastDeliveredAt"))
        last_seen_at = parse_datetime(raw_entry.get("lastSeenAt"))
        if last_delivered_at is None:
            groups_to_notify.append(group)
            continue
        if last_seen_at is not None and group.last_seen_at <= last_seen_at:
            continue
        if group.last_seen_at - last_delivered_at >= threshold:
            groups_to_notify.append(replace(group, notification_reason="reopened"))
            continue
    if len(groups_to_notify) <= settings.max_groups_per_message:
        return groups_to_notify
    return groups_to_notify


def build_tracker_message(groups: list[AlertGroup], settings: Settings) -> str:
    heading = (
        "You are the tracker agent responding to Logfire exception detections. "
        "Send exactly one concise operator-facing Discord alert to the configured channel "
        "as the tracker bot."
    )
    guidance = [
        "Do not mention polling, cron, MCP, Oracle internals, or implementation details.",
        "State the likely impact and whether the issue looks user-caused, client-caused, or server-side when the facts support that.",
        "Keep the Discord message short and concrete.",
    ]
    lines: list[str] = [
        heading,
        "",
        f"Project: {settings.project_name}",
        f"Query window: {settings.age}",
        f"Detected groups to report: {len(groups)}",
    ]
    if settings.project_url:
        lines.append(f"Project URL: {settings.project_url}")
    lines.extend(["", "Alert groups:"])
    expanded_groups = groups[: settings.max_groups_per_message]
    for index, group in enumerate(expanded_groups, start=1):
        trace_summary = ", ".join(group.trace_ids) if group.trace_ids else "(none)"
        lines.extend(
            [
                f"{index}. state: {group.notification_reason}",
                f"   service: {group.service_name}",
                f"   environment: {group.environment_name}",
                f"   type: {group.exception_type}",
                f"   message: {truncate_text(group.exception_message, 280)}",
                f"   route: {group.method} {group.route}",
                f"   status: {group.status_code}",
                f"   occurrences_in_window: {group.occurrence_count}",
                f"   first_seen_in_window: {group.first_seen_at.isoformat()}",
                f"   last_seen_in_window: {group.last_seen_at.isoformat()}",
                f"   sample_trace_ids: {trace_summary}",
            ],
        )
        if group.fingerprint:
            lines.append(f"   fingerprint: {group.fingerprint}")
    remaining = len(groups) - len(expanded_groups)
    if remaining > 0:
        lines.append(f"Additional groups not expanded: {remaining}")
    lines.extend(["", "Operator message requirements:"])
    for item in guidance:
        lines.append(f"- {item}")
    return "\n".join(lines).strip()


def send_tracker_alert(message: str, settings: Settings) -> None:
    openclaw_bin = resolve_openclaw_bin()
    command_env = build_openclaw_command_env()
    command = [
        openclaw_bin,
        "agent",
        "--agent",
        settings.agent_id,
        "--message",
        message,
        "--deliver",
        "--reply-channel",
        "discord",
        "--reply-to",
        settings.discord_target,
        "--reply-account",
        settings.discord_account,
        "--timeout",
        str(settings.openclaw_timeout_seconds),
    ]
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        env=command_env,
        timeout=settings.openclaw_timeout_seconds + 30,
    )
    if completed.returncode != 0:
        stderr = completed.stderr.strip()
        stdout = completed.stdout.strip()
        detail = stderr or stdout or f"exit code {completed.returncode}"
        raise PollerError(f"openclaw agent handoff failed: {detail}")


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": STATE_VERSION, "alerts": {}}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as err:
        raise PollerError(f"failed to parse state file {path}: {err}") from err
    if not isinstance(payload, dict):
        raise PollerError(f"state file {path} did not contain a JSON object")
    alerts = payload.get("alerts")
    if not isinstance(alerts, dict):
        payload["alerts"] = {}
    payload["version"] = STATE_VERSION
    return payload


def refresh_state(state: dict[str, Any], groups: list[AlertGroup]) -> dict[str, Any]:
    alerts_state = state.get("alerts", {})
    if not isinstance(alerts_state, dict):
        alerts_state = {}
    for group in groups:
        entry = alerts_state.get(group.alert_key)
        if not isinstance(entry, dict):
            entry = {}
        entry.update(
            {
                "serviceName": group.service_name,
                "environmentName": group.environment_name,
                "exceptionType": group.exception_type,
                "exceptionMessage": group.exception_message,
                "route": group.route,
                "method": group.method,
                "statusCode": group.status_code,
                "lastSeenAt": group.last_seen_at.isoformat(),
                "lastCount": group.occurrence_count,
            },
        )
        alerts_state[group.alert_key] = entry
    state["version"] = STATE_VERSION
    state["alerts"] = prune_alert_state(alerts_state)
    return state


def apply_delivered_groups(
    state: dict[str, Any],
    groups: list[AlertGroup],
    delivered_groups: list[AlertGroup],
) -> dict[str, Any]:
    refreshed = refresh_state(state, groups)
    alerts_state = refreshed.get("alerts", {})
    if not isinstance(alerts_state, dict):
        alerts_state = {}
    now = utc_now().isoformat()
    delivered_keys = {group.alert_key for group in delivered_groups}
    for key in delivered_keys:
        entry = alerts_state.get(key)
        if not isinstance(entry, dict):
            entry = {}
        entry["lastDeliveredAt"] = now
        alerts_state[key] = entry
    refreshed["alerts"] = prune_alert_state(alerts_state)
    return refreshed


def prune_alert_state(alerts_state: dict[str, Any]) -> dict[str, Any]:
    cutoff = utc_now() - dt.timedelta(days=7)
    pruned: dict[str, Any] = {}
    for key, value in alerts_state.items():
        if not isinstance(value, dict):
            continue
        last_seen_at = parse_datetime(value.get("lastSeenAt"))
        if last_seen_at is None or last_seen_at >= cutoff:
            pruned[key] = value
    return pruned


def save_state(path: Path, state: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(".tmp")
    temp_path.write_text(
        json.dumps(state, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temp_path.replace(path)


def build_alert_key(event: ExceptionEvent) -> str:
    if event.fingerprint:
        return event.fingerprint
    digest = hashlib.sha256()
    digest.update(
        "\u241f".join(
            [
                event.service_name,
                event.environment_name,
                event.exception_type,
                event.exception_message,
                event.route,
                event.method,
                event.status_code,
            ],
        ).encode("utf-8"),
    )
    return digest.hexdigest()


def resolve_openclaw_bin() -> str:
    candidates = [
        os.environ.get("OPENCLAW_BIN", "").strip(),
        shutil.which("openclaw") or "",
        str(Path.home() / ".local" / "share" / "pnpm" / "openclaw"),
        str(Path.home() / ".local" / "bin" / "openclaw"),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    raise PollerError("openclaw binary not found; set OPENCLAW_BIN or add it to PATH")


def build_openclaw_command_env() -> dict[str, str]:
    node_bin = resolve_node_bin()
    env = dict(os.environ)
    existing_path = env.get("PATH", "")
    node_dir = str(Path(node_bin).parent)
    if existing_path:
        env["PATH"] = f"{node_dir}:{existing_path}"
    else:
        env["PATH"] = node_dir
    return env


def read_gateway_node_bin() -> str:
    service_path = Path.home() / ".config" / "systemd" / "user" / "openclaw-gateway.service"
    if not service_path.is_file():
        return ""
    try:
        service_text = service_path.read_text(encoding="utf-8")
    except OSError:
        return ""
    for line in service_text.splitlines():
        if not line.startswith("ExecStart="):
            continue
        exec_start = line.partition("=")[2].strip()
        if not exec_start:
            continue
        try:
            parts = shlex.split(exec_start)
        except ValueError:
            return ""
        if not parts:
            return ""
        return parts[0]
    return ""


def resolve_node_bin() -> str:
    candidates = [
        os.environ.get("NODE_BIN", "").strip(),
        shutil.which("node") or "",
        read_gateway_node_bin(),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    raise PollerError("node binary not found; set NODE_BIN or add it to PATH")


def parse_positive_int(raw: str | None, default: int, env_name: str) -> int:
    if raw is None or not raw.strip():
        return default
    try:
        value = int(raw.strip())
    except ValueError as err:
        raise PollerError(f"{env_name} must be an integer") from err
    if value <= 0:
        raise PollerError(f"{env_name} must be greater than zero")
    return value


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise PollerError(f"missing required environment variable: {name}")
    return value


def read_optional_env(name: str, default: str) -> str:
    raw_value = os.environ.get(name)
    if raw_value is None:
        return default
    return raw_value.strip()


def first_non_empty(row: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        if key not in row:
            continue
        value = row[key]
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def normalize_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def parse_datetime(value: Any) -> dt.datetime | None:
    text = normalize_text(value)
    if not text:
        return None
    normalized = text.replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def unique_items(items: Iterable[str]) -> tuple[str, ...]:
    values: list[str] = []
    seen: set[str] = set()
    for item in items:
        trimmed = item.strip()
        if not trimmed or trimmed in seen:
            continue
        seen.add(trimmed)
        values.append(trimmed)
    return tuple(values)


def truncate_text(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 3].rstrip() + "..."


def try_parse_json(text: str) -> Any:
    candidate = text.strip()
    if not candidate:
        return None
    if candidate[0] not in "[{":
        return None
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        return None


def escape_sql_string(text: str) -> str:
    return text.replace("'", "''")


def parse_logfire_age_minutes(raw_age: str) -> int:
    value = raw_age.strip().lower()
    if not value:
        raise PollerError("LOGFIRE_ALERT_AGE must not be empty")
    if value.isdigit():
        return int(value)
    suffix = value[-1]
    amount_text = value[:-1].strip()
    if not amount_text.isdigit():
        raise PollerError(
            "LOGFIRE_ALERT_AGE must be an integer number of minutes or use m/h/d suffixes",
        )
    amount = int(amount_text)
    if amount <= 0:
        raise PollerError("LOGFIRE_ALERT_AGE must be greater than zero")
    if suffix == "m":
        return amount
    if suffix == "h":
        return amount * 60
    if suffix == "d":
        return amount * 60 * 24
    raise PollerError(
        "LOGFIRE_ALERT_AGE must be an integer number of minutes or use m/h/d suffixes",
    )


def resolve_mcp_transport(raw_transport: str, endpoint: str) -> str:
    normalized = raw_transport.strip().lower() or DEFAULT_MCP_TRANSPORT
    if normalized == "auto":
        return "http" if endpoint else "stdio"
    if normalized not in {"http", "stdio"}:
        raise PollerError(
            "LOGFIRE_MCP_TRANSPORT must be one of: auto, http, stdio",
        )
    return normalized


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PollerError as err:
        print(f"error: {err}", file=sys.stderr)
        raise SystemExit(1)
