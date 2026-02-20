"""
Management command para expirar suscripciones vencidas automáticamente.

Uso:
    python manage.py expire_subscriptions

Configurar como tarea periódica con cron:
    # Ejecutar cada hora
    0 * * * * cd /path/to/project && python manage.py expire_subscriptions

    # Ejecutar cada 30 minutos
    */30 * * * * cd /path/to/project && python manage.py expire_subscriptions
"""
import logging

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.users.models import MonthSubscription

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = (
        "Verifica y desactiva suscripciones mensuales vencidas. "
        "También desactiva la disponibilidad (is_available) de los usuarios afectados."
    )

    def handle(self, *args, **options):
        now = timezone.now()
        expired = MonthSubscription.objects.filter(
            status=MonthSubscription.Status.ACTIVE,
            expires_at__lt=now,
        ).select_related("user")

        count = expired.count()
        if count == 0:
            self.stdout.write("No hay suscripciones por expirar.")
            return

        self.stdout.write(f"Se encontraron {count} suscripciones vencidas. Procesando...")

        for subscription in expired:
            subscription.expire()
            self.stdout.write(
                f"  - {subscription.user.username}: suscripción expirada "
                f"(vencida el {subscription.expires_at:%Y-%m-%d %H:%M})"
            )
            logger.info(
                "[EXPIRE_SUBSCRIPTIONS] Usuario %s: suscripción expirada",
                subscription.user.username,
            )

        self.stdout.write(self.style.SUCCESS(
            f"Proceso completado. {count} suscripciones expiradas."
        ))
