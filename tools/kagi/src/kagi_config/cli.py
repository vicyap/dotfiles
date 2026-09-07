"""`kagi` command line: read, plan, apply, mine."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from kagi_config import config as config_mod
from kagi_config import kagi, mine, paths
from kagi_config import plan as plan_mod


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (config_mod.ConfigError, kagi.SessionError, FileNotFoundError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except kagi.ApplyError as exc:
        print(f"apply failed: {exc}", file=sys.stderr)
        return 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="kagi", description=__doc__)
    parser.add_argument(
        "--config",
        type=Path,
        default=paths.REPO_CONFIG,
        help=f"path to kagi.toml (default: {paths.REPO_CONFIG})",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="show the browser window for read/apply",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("read", help="log in and capture live account state into the state dir")
    p.set_defaults(func=cmd_read)

    p = sub.add_parser("plan", help="diff live account state against kagi.toml")
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("apply", help="make the account match kagi.toml (deletes included)")
    p.set_defaults(func=cmd_apply)

    p = sub.add_parser("mine", help="propose config edits from Brave history")
    p.add_argument("--profile", default="Default", help="Brave profile directory name")
    p.add_argument("--history", type=Path, help="explicit path to a History sqlite file")
    p.add_argument(
        "--min-clicks",
        type=int,
        default=mine.DEFAULT_MIN_CLICKS,
        help="clicks needed for a domain to become a raise candidate",
    )
    p.set_defaults(func=cmd_mine)
    return parser


def cmd_read(args: argparse.Namespace) -> int:
    config_mod.load(args.config)
    live = kagi.read(headless=not args.headed)
    print(f"ranked={len(live.ranked)} lenses={len(live.lenses)} assistants={len(live.assistants)}")
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    cfg = config_mod.load(args.config)
    live = kagi.read(headless=not args.headed)
    print(plan_mod.render(plan_mod.plan(cfg, live)))
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    cfg = config_mod.load(args.config)
    live = kagi.read(headless=not args.headed)
    changes = plan_mod.plan(cfg, live)
    print(plan_mod.render(changes))
    if not changes:
        return 0
    after = kagi.apply(changes, live, headless=not args.headed)
    residual = plan_mod.plan(cfg, after)
    if residual:
        print("\nApply finished but the account still differs:", file=sys.stderr)
        print(plan_mod.render(residual), file=sys.stderr)
        return 2
    print("\nApply complete. Account matches kagi.toml.")
    return 0


def cmd_mine(args: argparse.Namespace) -> int:
    history = args.history or paths.brave_history(args.profile)
    report, proposal = mine.mine(history, min_clicks=args.min_clicks)
    print(f"report:   {report}\nproposal: {proposal}")
    return 0
