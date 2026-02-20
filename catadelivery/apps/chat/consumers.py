"""
WebSocket consumer para chat en tiempo real.

Flujo:
1. El cliente abre ``ws://.../ws/chat/<conversation_id>/?token=<jwt>``.
2. ``JWTAuthMiddleware`` resuelve ``scope["user"]``.
3. ``connect()`` verifica:
   a. Que el usuario esté autenticado.
   b. Que la conversación exista en SQLite.
   c. Que el usuario pertenezca a la conversación (rider o dueño del store).
4. Si pasa las validaciones, se une al grupo de Channels (por conversation_id).
5. ``receive_json()`` persiste el mensaje en MongoDB y lo emite al grupo.
6. ``disconnect()`` abandona el grupo.
"""

from __future__ import annotations

import json
import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from .models import Conversation
from . import mongo

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncWebsocketConsumer):
    """Consumer asíncrono para chat 1-a-1 entre store y rider."""

    # ------------------------------------------------------------------
    # Conexión
    # ------------------------------------------------------------------
    async def connect(self):
        self.conversation_id = self.scope["url_route"]["kwargs"]["conversation_id"]
        self.room_group = f"chat_{self.conversation_id}"
        user = self.scope.get("user")

        # 1. ¿Autenticado?
        if user is None or isinstance(user, AnonymousUser):
            logger.warning("WS rechazado: usuario no autenticado.")
            await self.close(code=4001)
            return

        # 2. ¿La conversación existe?
        conversation = await self._get_conversation(self.conversation_id)
        if conversation is None:
            logger.warning(
                "WS rechazado: conversación %s no existe.", self.conversation_id
            )
            await self.close(code=4004)
            return

        # 3. ¿El usuario pertenece a la conversación?
        belongs = await self._user_belongs(conversation, user)
        if not belongs:
            logger.warning(
                "WS rechazado: usuario %s no pertenece a conversación %s.",
                user.id,
                self.conversation_id,
            )
            await self.close(code=4003)
            return

        # Todo OK → unirse al grupo y aceptar la conexión
        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()
        logger.info(
            "WS conectado: usuario %s en conversación %s.",
            user.id,
            self.conversation_id,
        )

    # ------------------------------------------------------------------
    # Desconexión
    # ------------------------------------------------------------------
    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group, self.channel_name)

    # ------------------------------------------------------------------
    # Recepción de mensajes del cliente
    # ------------------------------------------------------------------
    async def receive(self, text_data=None, bytes_data=None):
        """
        Payload esperado del cliente::

            {"message": "Hola, ya salí del local."}
        """
        try:
            content = json.loads(text_data)
        except (json.JSONDecodeError, TypeError):
            await self.send(text_data=json.dumps({"error": "JSON inválido."}))
            return

        user = self.scope["user"]
        message_text = content.get("message", "").strip()
        if not message_text:
            await self.send(text_data=json.dumps({"error": "El mensaje no puede estar vacío."}))
            return

        # Persistir en MongoDB
        doc = await self._save_message(
            conversation_id=self.conversation_id,
            sender_id=user.id,
            message=message_text,
        )

        # Emitir al grupo (todos los participantes conectados)
        await self.channel_layer.group_send(
            self.room_group,
            {
                "type": "chat.message",
                "conversation_id": str(self.conversation_id),
                "sender_id": user.id,
                "sender_username": user.username,
                "message": message_text,
                "timestamp": doc["timestamp"].isoformat(),
            },
        )

    # ------------------------------------------------------------------
    # Handler de grupo: reenviar mensaje a cada WebSocket
    # ------------------------------------------------------------------
    async def chat_message(self, event):
        """Recibido vía channel layer; reenviado al WebSocket del cliente."""
        await self.send(text_data=json.dumps({
            "conversation_id": event["conversation_id"],
            "sender_id": event["sender_id"],
            "sender_username": event["sender_username"],
            "message": event["message"],
            "timestamp": event["timestamp"],
        }))

    # ------------------------------------------------------------------
    # Helpers async → sync
    # ------------------------------------------------------------------
    @database_sync_to_async
    def _get_conversation(self, conversation_id) -> Conversation | None:
        try:
            return Conversation.objects.get(
                pk=conversation_id
            )
        except (Conversation.DoesNotExist, ValueError):
            return None

    @database_sync_to_async
    def _user_belongs(self, conversation: Conversation, user) -> bool:
        return conversation.user_belongs(user)

    @database_sync_to_async
    def _save_message(self, conversation_id, sender_id, message):
        return mongo.save_message(
            conversation_id=conversation_id,
            sender_id=sender_id,
            message=message,
        )
