from typing import Any

from django.http import HttpRequest
from ninja import Router

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import User
from apps.authentication.schemas import CurrentUserResponse
from apps.core.response import APIResponse, ErrorData, ErrorResponse, SuccessResponse
from apps.core.routes import Routes



router: Router = Router(tags=["Account"])


@router.get(
    Routes.CurrentUser.BASE,
    auth=VersionedJWTAuth(),
    response={
        200: SuccessResponse[CurrentUserResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def get_current_user(request: HttpRequest) -> tuple[int, dict[str, Any]]:
    """
    Return the authenticated user's approved public account data.

    Args:
        request: HTTP request authenticated with the current session's access token.

    Returns:
        HTTP status and the standard success envelope containing public account data.

    Raises:
        ValidationError: Raised when account values violate the response schema.
    """
    user: User = request.auth
    response_data: CurrentUserResponse = CurrentUserResponse.from_user(user)
    return 200, APIResponse.success(response_data.model_dump())
