from typing import Final



class Routes:
    """Define route paths exposed by the core application."""

    class CurrentUser:
        """Define the authenticated account retrieval route."""

        BASE: Final[str] = "/me"
