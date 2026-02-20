"""
Endpoints REST para el módulo de chat.

- POST /api/chat/conversations/              → Crear conversación.
- GET  /api/chat/conversations/              → Listar conversaciones del usuario.
- GET  /api/chat/conversations/<id>/         → Detalle de una conversación.
- GET  /api/chat/conversations/<id>/messages → Historial de mensajes (MongoDB).
- POST /api/chat/conversations/get_or_create → Obtener o crear conversación por order_id + other_user_id.
"""

from __future__ import annotations

from datetime import datetime, timezone

from django.db.models import Q
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from . import mongo
from .models import Conversation
from .serializers import ConversationSerializer, MessageSerializer


class ConversationViewSet(viewsets.ModelViewSet):
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ["get", "post", "head", "options"]

    # ------------------------------------------------------------------
    # Queryset: solo conversaciones del usuario autenticado
    # ------------------------------------------------------------------
    def get_queryset(self):
        user = self.request.user
        return (
            Conversation.objects.select_related(
                "order", "participant_1", "participant_2"
            )
            .filter(Q(participant_1=user) | Q(participant_2=user))
            .order_by("-created_at")
        )

    # ------------------------------------------------------------------
    # get_or_create — endpoint principal para los frontends
    # ------------------------------------------------------------------
    @action(detail=False, methods=["post"], url_path="get_or_create")
    def get_or_create(self, request):
        """
        POST /api/chat/conversations/get_or_create/
        Body: {"order_id": 123, "other_user_id": 5}

        Devuelve la conversación existente o crea una nueva.
        Valida que el usuario autenticado sea participante del pedido.
        """
        order_id = request.data.get("order_id")
        other_user_id = request.data.get("other_user_id")

        if not order_id or not other_user_id:
            return Response(
                {"detail": "order_id y other_user_id son requeridos."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = request.user

        # Normalizar: participant_1 siempre es el de menor ID
        ids = sorted([user.id, int(other_user_id)])

        conversation, created = Conversation.objects.get_or_create(
            order_id=order_id,
            participant_1_id=ids[0],
            participant_2_id=ids[1],
        )

        serializer = self.get_serializer(conversation)
        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    # ------------------------------------------------------------------
    # Historial de mensajes (paginación por cursor con ?before=)
    # ------------------------------------------------------------------
    @action(detail=True, methods=["get"], url_path="messages")
    def messages(self, request, pk=None):
        """
        GET /api/chat/conversations/<uuid>/messages/?limit=50&before=<iso-ts>
        """
        conversation = self.get_object()
        user = request.user

        if not conversation.user_belongs(user):
            return Response(
                {"detail": "No perteneces a esta conversación."},
                status=status.HTTP_403_FORBIDDEN,
            )

        limit = min(int(request.query_params.get("limit", 50)), 100)
        before_raw = request.query_params.get("before")
        before = None
        if before_raw:
            try:
                before = datetime.fromisoformat(before_raw)
                if before.tzinfo is None:
                    before = before.replace(tzinfo=timezone.utc)
            except ValueError:
                return Response(
                    {"detail": "Formato de 'before' inválido. Usar ISO-8601."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        docs = mongo.get_conversation_messages(
            conversation_id=str(conversation.id),
            limit=limit,
            before=before,
        )

        serializer = MessageSerializer(docs, many=True)
        return Response(serializer.data)
