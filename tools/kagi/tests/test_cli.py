from kagi_config.cli import build_parser


def test_parser_subcommands() -> None:
    parser = build_parser()
    args = parser.parse_args(["mine", "--profile", "Profile 1", "--min-clicks", "5"])
    assert args.command == "mine"
    assert args.profile == "Profile 1"
    assert args.min_clicks == 5
    args = parser.parse_args(["--config", "x.toml", "plan"])
    assert str(args.config) == "x.toml"
