from django.urls import path
from django.urls.resolvers import URLResolver
from .api import api



urlpatterns: list[URLResolver] = [

    # API entry point
    path("api/", api.urls)

]
