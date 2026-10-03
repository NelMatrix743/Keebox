from typing import Any

from django.http import HttpRequest, HttpResponse
from ninja import NinjaAPI
from ninja.errors import AuthenticationError, ValidationError
from ninja_jwt.exceptions import AuthenticationFailed

from apps.core.info import API_DESCRIPTION, API_TITLE, API_VERSION
from apps.core.response import ErrorData, APIResponse
from apps.authentication.api import router as authentication_router



# main API entry point
api: NinjaAPI = NinjaAPI(
    title=API_TITLE,
    version=API_VERSION,
    description=API_DESCRIPTION
)


@api.exception_handler(AuthenticationError)
def handle_missing_authentication(
    request: HttpRequest,
    exception: AuthenticationError,
) -> HttpResponse:
    """
    Return missing bearer credentials through the standard error envelope.

    Args:
        request: HTTP request without accepted authentication credentials.
        exception: Authentication failure raised by the API router.

    Returns:
        HTTP response describing the missing authentication credentials.

    Raises:
        None.
    """
    return api.create_response(
        request,
        APIResponse.error(
            ErrorData(
                code="authentication_required",
                message="Authentication is required.",
            ).model_dump(),
        ),
        status=401,
    )


@api.exception_handler(AuthenticationFailed)
def handle_invalid_authentication(
    request: HttpRequest,
    exception: AuthenticationFailed,
) -> HttpResponse:
    """
    Return rejected bearer credentials through the standard error envelope.

    Args:
        request: HTTP request with invalid or superseded credentials.
        exception: Authentication failure raised while validating the token.

    Returns:
        HTTP response describing an invalid session.

    Raises:
        None.
    """
    return api.create_response(
        request,
        APIResponse.error(
            ErrorData(
                code="invalid_session",
                message="The session is no longer valid.",
            ).model_dump(),
        ),
        status=401,
    )


@api.exception_handler(ValidationError)
def handle_validation_error(
    request: HttpRequest,
    exception: ValidationError,
) -> HttpResponse:
    """
    Return request validation failures through the standard error envelope.

    Args:
        request: HTTP request containing invalid API input.
        exception: Validation failure raised while parsing the request.

    Returns:
        HTTP response containing safe field-level validation details.

    Raises:
        None.
    """
    details: list[dict[str, Any]] = [
        {
            "location": error.get("loc", []),
            "message": error.get("msg", "The submitted value is invalid."),
            "type": error.get("type", "validation_error"),
        }
        for error in exception.errors
    ]
    return api.create_response(
        request,
        APIResponse.error(
            ErrorData(
                code="validation_error",
                message="The request contains invalid data.",
                details=details,
            ).model_dump(),
        ),
        status=422,
    )


api.add_router("/auth", authentication_router)
