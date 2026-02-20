"""
Middleware de autenticación JWT para conexiones WebSocket.

Django Channels no recibe headers HTTP convencionales en el handshake WS,
por lo que el token JWT se envía como query-string:

    ws://host/ws/chat/<conversation_id>/?token=<jwt_access_token>

Este middleware:
1. Extrae el token de la query-string.
2. Lo valida con SimpleJWT.
3. Asigna ``scope["user"]`` con el UserProfile correspondiente.
4. Si el token es inválido o ausente, asigna AnonymousUser.
"""

from __future__ import annotations

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()


@database_sync_to_async
def _get_user(token_str: str):
    """Valida el JWT y devuelve el usuario o AnonymousUser."""
    try:
        validated = AccessToken(token_str)
        user_id = validated["user_id"]
        return User.objects.get(pk=user_id)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """Inyecta ``scope['user']`` a partir del token JWT en la query-string."""

    async def __call__(self, scope, receive, send):
        qs = parse_qs(scope.get("query_string", b"").decode())
        token_list = qs.get("token", [])
        token = token_list[0] if token_list else None

        if token:
            scope["user"] = await _get_user(token)
        else:
            scope["user"] = AnonymousUser()

        return await super().__call__(scope, receive, send)
