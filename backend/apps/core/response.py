from typing import Any



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
