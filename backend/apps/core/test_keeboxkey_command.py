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

    @patch("apps.core.management.commands.keeboxkey.pyperclip.copy")
    @patch(
        "apps.core.management.commands.keeboxkey.generate_kmkey",
        return_value="KMK-master-segmented-key",
    )
    def test_master_option_prints_and_copies_a_kmkey(
        self: Self,
        generate_kmkey: Mock,
        copy_to_clipboard: Mock,
    ) -> None:
        """
        Verify the master option prints and copies the generated KMKey.

        Args:
            self: Current test case instance.
            generate_kmkey: Mocked KMKey generator.
            copy_to_clipboard: Mocked operating-system clipboard writer.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the KMKey is not printed or copied.
        """
        output: StringIO = StringIO()

        call_command("keeboxkey", "--master", stdout=output)

        generate_kmkey.assert_called_once_with()
        copy_to_clipboard.assert_called_once_with("KMK-master-segmented-key")
        self.assertEqual(output.getvalue(), "KMK-master-segmented-key\n")

    def test_command_requires_a_key_type_option(self: Self) -> None:
        """
        Verify the command rejects invocations without a key type.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an optionless invocation is accepted.
        """
        with self.assertRaises(CommandError):
            call_command("keeboxkey")
