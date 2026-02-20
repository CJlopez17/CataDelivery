from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from django.core.validators import FileExtensionValidator
import calendar


class UserProfile(AbstractUser):
    """Custom user model with role management for Catadelivery."""

    class Roles(models.TextChoices):
        CLIENT = "client", _("Client")
        RIDER = "rider", _("Rider")
        STORE = "store", _("Store")

    role = models.CharField(
        max_length=20,
        choices=Roles.choices,
        default=Roles.CLIENT,
        help_text=_("Determines the capabilities available to the user inside Catadelivery."),
    )

    phone_number = models.CharField(
        max_length=15,
        blank=True,
        null=True,
        help_text=_("Número de teléfono para contacto"),
    )

    is_available = models.BooleanField(
        default=False,
        help_text=_("Indica si el rider/store está disponible para recibir pedidos."),
    )

    current_latitude = models.FloatField(
        null=True,
        blank=True,
        help_text=_("Latitud actual del rider (actualizada desde la app móvil)"),
    )
    current_longitude = models.FloatField(
        null=True,
        blank=True,
        help_text=_("Longitud actual del rider (actualizada desde la app móvil)"),
    )
    last_location_update = models.DateTimeField(
        null=True,
        blank=True,
        help_text=_("Última vez que el rider actualizó su ubicación"),
    )

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        return self.username

    @property
    def is_client(self):
        return self.role == self.Roles.CLIENT

    @property
    def is_rider(self):
        return self.role == self.Roles.RIDER

    @property
    def is_store(self):
        return self.role == self.Roles.STORE

    def has_active_subscription(self):
        """Verifica si el usuario tiene una suscripción activa y vigente."""
        return self.subscriptions.filter(
            status=MonthSubscription.Status.ACTIVE,
            expires_at__gte=timezone.now(),
        ).exists()

    def get_current_subscription(self):
        """
        Retorna la suscripción más relevante:
        1. Activa y vigente  2. Pendiente  3. La más reciente
        """
        return (
            self.subscriptions.filter(
                status=MonthSubscription.Status.ACTIVE,
                expires_at__gte=timezone.now(),
            ).first()
            or self.subscriptions.filter(
                status=MonthSubscription.Status.PENDING,
            ).first()
            or self.subscriptions.first()
        )

    def clean(self):
        super().clean()
        if (
            self.is_available
            and self.role in {self.Roles.RIDER, self.Roles.STORE}
            and self.pk
        ):
            if not self.has_active_subscription():
                raise ValidationError({
                    "is_available": _(
                        "No se puede activar la disponibilidad sin una suscripción mensual activa."
                    )
                })


def _add_one_month(dt):
    """Suma exactamente un mes a un datetime."""
    month = dt.month % 12 + 1
    year = dt.year + (dt.month // 12)
    day = min(dt.day, calendar.monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


class MonthSubscription(models.Model):
    """Suscripción mensual requerida para que riders y stores reciban pedidos."""

    class Status(models.TextChoices):
        PENDING = "pending", _("Pendiente")
        ACTIVE = "active", _("Activa")
        EXPIRED = "expired", _("Vencida")
        REJECTED = "rejected", _("Rechazada")

    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="subscriptions",
    )
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING,
    )
    starts_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    document = models.FileField(
        upload_to="subscriptions_docs/",
        validators=[FileExtensionValidator(allowed_extensions=["jpg", "jpeg", "png", "pdf"])],
        blank=True,
        null=True,
    )

    class Meta:
        verbose_name = "Suscripción Mensual"
        verbose_name_plural = "Suscripciones Mensuales"
        ordering = ["-created_at"]

    def __str__(self):
        date = self.created_at.strftime("%Y-%m-%d") if self.created_at else "nueva"
        return f"{self.user.username} - {self.get_status_display()} ({date})"

    @property
    def is_vigent(self):
        """True si la suscripción está activa y no ha vencido."""
        return (
            self.status == self.Status.ACTIVE
            and self.expires_at is not None
            and self.expires_at >= timezone.now()
        )

    def approve(self):
        """El admin aprueba la suscripción: calcula fechas automáticamente."""
        now = timezone.now()
        self.status = self.Status.ACTIVE
        self.starts_at = now
        self.expires_at = _add_one_month(now)
        self.save(update_fields=["status", "starts_at", "expires_at"])

    def reject(self):
        """El admin rechaza la suscripción."""
        self.status = self.Status.REJECTED
        self.save(update_fields=["status"])

    def expire(self):
        """Marca como vencida y fuerza is_available=False si no hay otra vigente."""
        self.status = self.Status.EXPIRED
        self.save(update_fields=["status"])
        if self.user.role in {UserProfile.Roles.RIDER, UserProfile.Roles.STORE}:
            if not self.user.has_active_subscription() and self.user.is_available:
                self.user.is_available = False
                self.user.save(update_fields=["is_available"])


class ClientAddress(models.Model):
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="addresses",
    )
    name = models.CharField(max_length=120)
    latitude = models.FloatField()
    longitude = models.FloatField()
    description = models.TextField()

    class Meta:
        verbose_name = "Dirección"
        verbose_name_plural = "Direcciones"
        unique_together = ("user", "name")

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class RoleChangeRequest(models.Model):
    """Stores admin-facing notifications when a client wants extended privileges."""

    class Status(models.TextChoices):
        PENDING = "pending", _("Pending")
        APPROVED = "approved", _("Approved")
        REJECTED = "rejected", _("Rejected")

    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="role_change_requests",
    )
    requested_role = models.CharField(max_length=20, choices=UserProfile.Roles.choices)
    message = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )
    resolved_by = models.ForeignKey(
        UserProfile,
        on_delete=models.SET_NULL,
        related_name="handled_role_change_requests",
        null=True,
        blank=True,
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("Role change request")
        verbose_name_plural = _("Role change requests")
        ordering = ["-created_at"]

    def __str__(self):
       return f"{self.user.username} → {self.get_requested_role_display()}"

    def mark_resolved(self, status, resolver=None):
        self.status = status
        self.resolved_by = resolver
        self.resolved_at = timezone.now()
        self.save(update_fields=["status", "resolved_by", "resolved_at"])


class FCMToken(models.Model):
    """
    Almacena los tokens de Firebase Cloud Messaging para enviar notificaciones push.
    Un usuario puede tener múltiples tokens (múltiples dispositivos).
    """
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="fcm_tokens",
        help_text="Usuario dueño del token FCM",
    )
    token = models.CharField(
        max_length=255,
        unique=True,
        help_text="Token FCM del dispositivo",
    )
    device_id = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="ID único del dispositivo (opcional)",
    )
    platform = models.CharField(
        max_length=20,
        choices=[
            ('android', 'Android'),
            ('ios', 'iOS'),
            ('web', 'Web'),
        ],
        default='android',
        help_text="Plataforma del dispositivo",
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Si el token es válido y activo",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "FCM Token"
        verbose_name_plural = "FCM Tokens"
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user.username} - {self.platform} ({self.token[:20]}...)"