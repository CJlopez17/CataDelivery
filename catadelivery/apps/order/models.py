from django.core.exceptions import ValidationError
from django.db import models

from apps.store.models import Store, Product
from apps.users.models import ClientAddress, UserProfile


# Create your models here.
class Order(models.Model):
    STATUS_CHOICES = [
        (1, "Send"),
        (2, "Received"),
        (3, "Preparing"),
        (4, "In Route"),
        (5, "Delivered"),
        (6, "Cancelled"),
    ]
    rider = models.ForeignKey(
        UserProfile,
        on_delete=models.SET_NULL,
        related_name="orders_as_rider",
        blank=True,
        null=True,
        limit_choices_to={"role": UserProfile.Roles.RIDER},
    )
    store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name="orders",
    )
    client = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="orders_as_client",
        limit_choices_to={"role": UserProfile.Roles.CLIENT},
    )
    delivery_address = models.ForeignKey(
        ClientAddress,
        on_delete=models.PROTECT,
        related_name="orders",
    )
    
    status = models.IntegerField(
        default=1,
        choices=STATUS_CHOICES,
    )
    dt = models.DateTimeField(auto_now_add=True)

    payment_method = models.CharField(
        max_length=20,
        choices=[("cash", "Cash"), ("ahorita", "Ahorita"), ("deuna","De una"), ("megowallet","MegoWallet"), ("jetfaster", "Jep Faster")],
        default="cash"
    )
    subtotal = models.FloatField(default=0)
    delivery_fee = models.FloatField(default=0)
    total = models.FloatField(default=0)

    # Comentario del usuario sobre el pedido (entrega, preparación, etc.)
    order_comment = models.TextField(
        blank=True,
        null=True,
        help_text="Comentario del cliente sobre el pedido o la entrega"
    )

    # Motivo de cancelación del pedido (por parte del restaurante)
    cancellation_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Motivo por el cual el restaurante canceló el pedido"
    )

    # Campos para asignación automática con algoritmo húngaro
    assignment_score = models.FloatField(
        null=True,
        blank=True,
        help_text="Score de asignación calculado (distancia total en km)",
    )
    assigned_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Cuándo se asignó automáticamente el rider",
    )
    is_auto_assigned = models.BooleanField(
        default=False,
        help_text="Indica si fue asignado automáticamente",
    )
    rejected_riders = models.JSONField(
        default=list,
        blank=True,
        help_text="Lista de IDs de riders que han rechazado este pedido",
    )

    class Meta:
        verbose_name = "Order"
        verbose_name_plural = "Orders"

    def __str__(self):
        return f"Order #{self.pk} from {self.store.name}"


class OrderProduct(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(Product, on_delete=models.PROTECT)
    name = models.CharField(max_length=100, blank=True, null=True)
    price = models.FloatField(null=True, blank=True)
    quantity = models.IntegerField()
    total = models.FloatField(editable=False)
    note = models.TextField(blank=True, null=True)
    total = models.FloatField(default=0)

    class Meta:
        verbose_name = "Order Product"
        verbose_name_plural = "Order Products"

    def __str__(self):
        return f"{self.order}"

    def save(self, *args, **kwargs):
        if self.price is None and self.product:
            self.price = self.product.price
        self.total = (self.price or 0) * (self.quantity or 0)
        if self.product:
            self.name = self.product.name
        super().save(*args, **kwargs)

