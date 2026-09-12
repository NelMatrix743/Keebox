from typing import Any, Self

from django.core.management.base import BaseCommand, CommandError, CommandParser
import pyperclip

from apps.core.key_utils import generate_kbkey, generate_kmkey



class Command(BaseCommand):
    """Generate a Keebox key and write it to the operating-system clipboard."""

    help: str = "Generate a KBKey or KMKey and copy it to the clipboard."

    def add_arguments(self: Self, parser: CommandParser) -> None:
        """
        Register the mutually exclusive Keebox key type options.

        Args:
            self: Current management command instance.
            parser: Django command-line argument parser.

        Returns:
            None: This method only configures command arguments.

        Raises:
            None.
        """
        key_type_group: Any = parser.add_mutually_exclusive_group(required=True)
        key_type_group.add_argument(
            "--user",
            action="store_true",
            help="Generate a Keebox user key",
        )
        key_type_group.add_argument(
            "--master",
            action="store_true",
            help="Generate a Keebox master key.",
        )
