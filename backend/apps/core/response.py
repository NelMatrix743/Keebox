from typing import Any, Literal

from ninja import Schema
from pydantic import ConfigDict



class SuccessResponse[DataType](Schema):
    """Represent a successful API response with typed dynamic data."""

    model_config = ConfigDict(extra="forbid")

    success: Literal[True] = True
    data: DataType
    error: None = None
    meta: dict[str, Any] | None = None


class ErrorData(Schema):
    """Represent structured error information returned by an API endpoint."""

    model_config = ConfigDict(extra="forbid")

    code: str
    message: str
    details: Any = None


class ErrorResponse[ErrorType](Schema):
    """Represent an unsuccessful API response with a typed dynamic error."""

    model_config = ConfigDict(extra="forbid")

    success: Literal[False] = False
    data: None = None
    error: ErrorType
    meta: dict[str, Any] | None = None


class APIResponse:
    """Build consistent response envelopes for Keebox API endpoints."""

    @staticmethod
    def success(data: Any | None = None, meta: Any | None = None) -> dict[str, Any]:
        """
        Build a successful API response envelope.

        Args:
            data: Dynamic response data returned to the frontend.
            meta: Dynamic response metadata returned to the frontend.

        Returns:
            A response envelope containing data and no error.

        Raises:
            None.
        """
        return {
            "success": True,
            "data": data,
            "error": None,
            "meta": meta,
        }

    @staticmethod
    def error(error: Any, meta: Any = None) -> dict[str, Any]:
        """
        Build an unsuccessful API response envelope.

        Args:
            error: Dynamic error details returned to the frontend.
            meta: Dynamic response metadata returned to the frontend.

        Returns:
            A response envelope containing no data and the error details.

        Raises:
            None.
        """
        return {
            "success": False,
            "data": None,
            "error": error,
            "meta": meta,
        }
