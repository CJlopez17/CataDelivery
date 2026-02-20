"""
ASGI config for catadelivery project.

Maneja:
- HTTP  → Django estándar (vía get_asgi_application).
- WS    → Django Channels con autenticación JWT.
"""

import os

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "catadelivery.settings")

# Inicializar Django ANTES de importar código que dependa del ORM.
django_asgi_app = get_asgi_application()

from apps.chat.middleware import JWTAuthMiddleware  # noqa: E402
from apps.chat.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": JWTAuthMiddleware(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
