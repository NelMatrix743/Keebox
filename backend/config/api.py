from ninja import NinjaAPI
from apps.core.info import (API_TITLE, API_VERSION, API_DESCRIPTION)



# main API entry point
api: NinjaAPI = NinjaAPI(
    title=API_TITLE,
    version=API_VERSION,
    description=API_DESCRIPTION
)
