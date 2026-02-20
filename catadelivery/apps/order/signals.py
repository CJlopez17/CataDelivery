"""
Signals para el modelo Order.
Se ejecutan automáticamente cuando ciertos eventos ocurren.
"""
import logging
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
from django.utils import timezone
from .models import Order
from .utils import assign_orders_to_riders
from apps.users.models import UserProfile
from apps.users.notifications import fcm_service

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Order)
def auto_assign_on_preparing(sender, instance, created, **kwargs):
    """
    Signal que se ejecuta automáticamente cuando un pedido cambia a status=3 (Preparing).
    Ejecuta el algoritmo húngaro para asignar riders disponibles.
    """
    # Solo ejecutar si el pedido cambió a status=3 (Preparing) y no tiene rider asignado
    if instance.status == 3 and instance.rider is None:
        logger.info("="*80)
        logger.info(f"🔔 [AUTO TRIGGER] Orden #{instance.id} cambió a status=3 (Preparing)")
        logger.info("🚀 [AUTO TRIGGER] Iniciando asignación automática...")

        try:
            # Obtener riders disponibles con ubicación actualizada
            # EXCLUIR riders que ya han rechazado este pedido
            rejected_riders = instance.rejected_riders or []

            riders = UserProfile.objects.filter(
                role=UserProfile.Roles.RIDER,
                is_active=True,
                is_available=True,
                current_latitude__isnull=False,
                current_longitude__isnull=False,
            ).exclude(
                id__in=rejected_riders  # Excluir riders que rechazaron
            ).values(
                'id', 'username', 'current_latitude', 'current_longitude'
            )

            riders_list = list(riders)
            logger.info(f"🚴 [AUTO TRIGGER] Riders disponibles con GPS: {len(riders_list)}")
            if rejected_riders:
                logger.info(f"⛔ [AUTO TRIGGER] Riders excluidos (rechazaron): {rejected_riders}")

            if not riders_list:
                logger.warning(f"⚠️ [AUTO TRIGGER] No hay riders disponibles para asignar Orden #{instance.id}")
                return

            # Obtener todas las órdenes pendientes (status=3, sin rider)
            # Incluye la orden que acaba de cambiar a status=3
            orders = Order.objects.filter(
                status=3,
                rider__isnull=True
            ).select_related('store', 'delivery_address').values(
                'id',
                'store__latitude',
                'store__longitude',
                'delivery_address__latitude',
                'delivery_address__longitude'
            )

            orders_list = [
                {
                    'id': o['id'],
                    'store_latitude': o['store__latitude'],
                    'store_longitude': o['store__longitude'],
                    'delivery_latitude': o['delivery_address__latitude'],
                    'delivery_longitude': o['delivery_address__longitude'],
                }
                for o in orders
            ]

            logger.info(f"📦 [AUTO TRIGGER] Órdenes pendientes de asignación: {len(orders_list)}")

            if not orders_list:
                logger.warning(f"⚠️ [AUTO TRIGGER] No hay órdenes pendientes (esto no debería pasar)")
                return

            # Ejecutar algoritmo húngaro
            logger.info("🧮 [AUTO TRIGGER] Ejecutando algoritmo húngaro...")
            assignments = assign_orders_to_riders(riders_list, orders_list)

            if not assignments:
                logger.error(f"❌ [AUTO TRIGGER] No se pudieron generar asignaciones para Orden #{instance.id}")
                return

            logger.info(f"✅ [AUTO TRIGGER] Algoritmo completado. {len(assignments)} asignaciones generadas")

            # Aplicar las asignaciones
            total_distance = 0
            assigned_count = 0

            for rider_id, order_id, distance in assignments:
                try:
                    order = Order.objects.get(pk=order_id)
                    rider = UserProfile.objects.get(pk=rider_id)

                    order.rider = rider
                    order.assignment_score = distance
                    order.assigned_at = timezone.now()
                    order.is_auto_assigned = True
                    order.save(update_fields=['rider', 'assignment_score', 'assigned_at', 'is_auto_assigned'])

                    logger.info(f"   ✓ Orden #{order_id} → Rider {rider.username} (Distancia: {distance:.2f} km)")

                    assigned_count += 1
                    total_distance += distance

                except (Order.DoesNotExist, UserProfile.DoesNotExist) as e:
                    logger.error(f"   ✗ Error asignando orden #{order_id}: {str(e)}")
                    continue

            avg_distance = total_distance / assigned_count if assigned_count else 0

            logger.info("="*80)
            logger.info(f"📊 [AUTO TRIGGER] RESUMEN:")
            logger.info(f"   • Trigger disparado por: Orden #{instance.id}")
            logger.info(f"   • Asignaciones realizadas: {assigned_count}")
            logger.info(f"   • Distancia total: {total_distance:.2f} km")
            logger.info(f"   • Distancia promedio: {avg_distance:.2f} km")
            logger.info("="*80)

        except Exception as e:
            logger.error(f"❌ [AUTO TRIGGER] Error en asignación automática: {str(e)}")
            logger.exception(e)


@receiver(post_save, sender=Order)
def send_order_status_notification(sender, instance, created, **kwargs):
    """
    Signal que envía notificaciones push al cliente cuando cambia el estado del pedido.
    Se ejecuta después de guardar el pedido.
    """
    # No enviar notificación si el pedido se acaba de crear
    if created:
        return

    # Obtener el estado anterior del caché (guardado en pre_save)
    old_status = getattr(instance, '_old_status', None)

    # Si no hay estado anterior o no cambió, no hacer nada
    if old_status is None or old_status == instance.status:
        return

    # Enviar notificación al cliente del pedido
    try:
        logger.info(f"🔔 [NOTIFICATION] Pedido #{instance.id}: Estado {old_status} → {instance.status}")

        sent_count = fcm_service.send_order_status_notification(
            user_id=instance.client.id,
            order_id=instance.id,
            old_status=old_status,
            new_status=instance.status,
        )

        if sent_count > 0:
            logger.info(f"✓ [NOTIFICATION] {sent_count} notificaciones enviadas para Pedido #{instance.id}")
        else:
            logger.info(f"ℹ️ [NOTIFICATION] No se enviaron notificaciones para Pedido #{instance.id} (sin tokens FCM)")

    except Exception as e:
        logger.error(f"❌ [NOTIFICATION] Error al enviar notificación para Pedido #{instance.id}: {str(e)}")


@receiver(pre_save, sender=Order)
def cache_old_status(sender, instance, **kwargs):
    """
    Signal que se ejecuta ANTES de guardar el pedido.
    Guarda el estado anterior para poder detectar cambios.
    """
    if instance.pk:  # Solo si el pedido ya existe
        try:
            old_instance = Order.objects.get(pk=instance.pk)
            instance._old_status = old_instance.status
        except Order.DoesNotExist:
            instance._old_status = None
    else:
        instance._old_status = None
