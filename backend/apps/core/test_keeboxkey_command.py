from io import StringIO
from typing import Self
from unittest.mock import Mock, patch

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase
from pyperclip import PyperclipException



class KeeboxKeyCommandTests(SimpleTestCase):
    @patch("apps.core.management.commands.keeboxkey.pyperclip.copy")
    @patch(
        "apps.core.management.commands.keeboxkey.generate_kbkey",
        return_value="KBK-user-segmented-key",
    )
    def test_user_option_prints_and_copies_a_kbkey(
        self: Self,
        generate_kbkey: Mock,
        copy_to_clipboard: Mock,
    ) -> None:
        """
        Verify the user option prints and copies the generated KBKey.

        Args:
            self: Current test case instance.
            generate_kbkey: Mocked KBKey generator.
            copy_to_clipboard: Mocked operating-system clipboard writer.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the KBKey is not printed or copied.
        """
        output: StringIO = StringIO()

        call_command("keeboxkey", "--user", stdout=output)

        generate_kbkey.assert_called_once_with()
        copy_to_clipboard.assert_called_once_with("KBK-user-segmented-key")
        self.assertEqual(output.getvalue(), "KBK-user-segmented-key\n")
