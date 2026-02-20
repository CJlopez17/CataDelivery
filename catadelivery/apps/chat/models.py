import uuid

from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.order.models import Order
from apps.users.models import UserProfile


class Conversation(models.Model):
    """
    Conversación en tiempo real entre dos participantes de un pedido.

    Casos de uso:
    - Cliente <-> Store (mientras el pedido está en status 1, 2, 3)
    - Cliente <-> Rider (mientras el pedido está en status 4)

    Vive en SQLite (fuente de verdad relacional).
    Los mensajes se almacenan en MongoDB referenciando este UUID.
    """

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="conversations",
        help_text=_("Pedido al que pertenece esta conversación."),
    )
    participant_1 = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="conversations_as_p1",
        help_text=_("Primer participante de la conversación."),
    )
    participant_2 = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="conversations_as_p2",
        help_text=_("Segundo participante de la conversación."),
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("Conversación")
        verbose_name_plural = _("Conversaciones")
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["order", "participant_1", "participant_2"],
                name="unique_order_participants_conversation",
            )
        ]

    def __str__(self):
        return (
            f"Chat {str(self.id)[:8]} | "
            f"{self.participant_1.username} <-> {self.participant_2.username}"
        )

    def user_belongs(self, user: UserProfile) -> bool:
        """Devuelve True si *user* es uno de los dos participantes."""
        return user.id in (self.participant_1_id, self.participant_2_id)
