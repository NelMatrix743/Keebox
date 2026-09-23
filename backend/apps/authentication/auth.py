from typing import cast

from ninja_jwt.authentication import JWTAuth
from ninja_jwt.tokens import Token

from apps.authentication.models import User
from apps.authentication.services.token_services import TokenService



class VersionedJWTAuth(JWTAuth):
    """Authenticate access tokens only for the active login generation."""

    def get_user(self, validated_token: Token) -> User:
        """
        Load the token's user and reject an obsolete login generation.

        Args:
            self: Current JWT authentication instance.
            validated_token: Decoded access token submitted with a request.

        Returns:
            The active user associated with a current-version access token.

        Raises:
            InvalidToken: Raised when the token's session was superseded.
            AuthenticationFailed: Raised when the user is missing or inactive.
        """
        user: User = cast(User, super().get_user(validated_token))
        TokenService.validate_token_version(user, validated_token)
        return user
