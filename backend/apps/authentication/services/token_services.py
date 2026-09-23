from typing import Final

from django.core.exceptions import ValidationError as DjangoValidationError
from ninja_jwt.exceptions import InvalidToken, TokenError
from ninja_jwt.tokens import RefreshToken, Token

from apps.authentication.models import User



TOKEN_VERSION_CLAIM: Final[str] = "token_version"


class TokenService:
    """Issue and validate JWTs against the user's active login generation."""

    @staticmethod
    def issue_tokens(user: User) -> tuple[str, str]:
        """
        Issue an access and refresh token for the current login generation.

        Args:
            user: Account receiving the authenticated token pair.

        Returns:
            The signed access token followed by the signed refresh token.

        Raises:
            None.
        """
        refresh_token: RefreshToken = RefreshToken.for_user(user)
        refresh_token[TOKEN_VERSION_CLAIM] = user.token_version
        return str(refresh_token.access_token), str(refresh_token)

    @staticmethod
    def validate_token_version(user: User, token: Token) -> None:
        """
        Require a token to belong to the user's current login generation.

        Args:
            user: Account identified by the token.
            token: Decoded access or refresh token being checked.

        Returns:
            None: A valid token permits the calling operation to continue.

        Raises:
            InvalidToken: Raised when the account or token version is invalid.
        """
        token_version: object = token.get(TOKEN_VERSION_CLAIM)
        if not user.is_active or (
            type(token_version) is not int or token_version != user.token_version
        ):
            raise InvalidToken("The session is no longer valid.")
