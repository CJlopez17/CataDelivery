"""
Módulo de acceso a MongoDB para mensajes de chat.

Responsabilidades:
- Conexión lazy al servidor MongoDB mediante pymongo.
- CRUD de documentos en la colección ``chat_messages``.

Estructura del documento en MongoDB::

    {
        "conversation_id": "uuid-string",
        "sender_id":       int,
        "message":         "texto del mensaje",
        "timestamp":       datetime (UTC)
    }

No se duplican datos de usuario ni de conversación: la validación de
pertenencia ocurre en Django contra SQLite antes de llegar aquí.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from django.conf import settings
from pymongo import MongoClient, DESCENDING


# ---------------------------------------------------------------------------
# Conexión lazy (singleton)
# ---------------------------------------------------------------------------
_client: MongoClient | None = None


def _get_db():
    """Devuelve la base de datos MongoDB configurada en settings."""
    global _client
    if _client is None:
        _client = MongoClient(
            settings.MONGO_URI,
            serverSelectionTimeoutMS=5000,
        )
    return _client[settings.MONGO_DB_NAME]


def get_messages_collection():
    """Devuelve la colección ``chat_messages``."""
    return _get_db()["chat_messages"]


# ---------------------------------------------------------------------------
# Operaciones sobre mensajes
# ---------------------------------------------------------------------------
def save_message(
    conversation_id: str,
    sender_id: int,
    message: str,
) -> dict[str, Any]:
    """
    Inserta un mensaje en MongoDB y devuelve el documento guardado.

    Parameters
    ----------
    conversation_id : str
        UUID de la conversación (``Conversation.id``).
    sender_id : int
        PK del ``UserProfile`` que envía el mensaje.
    message : str
        Contenido del mensaje.

    Returns
    -------
    dict
        Documento insertado con ``_id`` convertido a string.
    """
    collection = get_messages_collection()
    doc = {
        "conversation_id": str(conversation_id),
        "sender_id": sender_id,
        "message": message,
        "timestamp": datetime.now(timezone.utc),
    }
    result = collection.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


def get_conversation_messages(
    conversation_id: str,
    limit: int = 50,
    before: datetime | None = None,
) -> list[dict[str, Any]]:
    """
    Obtiene los mensajes de una conversación con paginación por cursor.

    Parameters
    ----------
    conversation_id : str
        UUID de la conversación.
    limit : int
        Cantidad máxima de mensajes a devolver (default 50).
    before : datetime | None
        Si se proporciona, solo devuelve mensajes anteriores a este timestamp
        (útil para scroll infinito / paginación).

    Returns
    -------
    list[dict]
        Mensajes ordenados del más antiguo al más reciente.
    """
    collection = get_messages_collection()
    query: dict[str, Any] = {"conversation_id": str(conversation_id)}
    if before is not None:
        query["timestamp"] = {"$lt": before}

    cursor = (
        collection.find(query)
        .sort("timestamp", DESCENDING)
        .limit(limit)
    )
    messages = []
    for doc in cursor:
        doc["_id"] = str(doc["_id"])
        messages.append(doc)
    # Devolver en orden cronológico (antiguo → reciente)
    messages.reverse()
    return messages


def ensure_indexes() -> None:
    """Crea los índices necesarios en la colección de mensajes."""
    collection = get_messages_collection()
    collection.create_index(
        [("conversation_id", 1), ("timestamp", DESCENDING)],
        name="idx_conversation_timestamp",
    )
