"""
Servicio de notificaciones push usando Firebase Cloud Messaging (FCM).
Permite enviar notificaciones a usuarios cuando cambia el estado de sus pedidos.
"""
import logging
from typing import List, Optional, Dict, Any
from django.conf import settings

logger = logging.getLogger(__name__)


class FCMNotificationService:
    """
    Servicio para enviar notificaciones push vía Firebase Cloud Messaging.

    IMPORTANTE: Requiere configuración de firebase-admin en settings.py
    """

    def __init__(self):
        """
        Inicializa el servicio FCM.
        Intenta importar firebase_admin, si no está disponible, desactiva el servicio.
        """
        self.enabled = False
        self.firebase_app = None

        try:
            import firebase_admin
            from firebase_admin import credentials, messaging

            # Verificar si ya está inicializado
            try:
                self.firebase_app = firebase_admin.get_app()
                self.enabled = True
                logger.info("✓ [FCM] Firebase ya estaba inicializado")
            except ValueError:
                # No está inicializado, intentar inicializar
                if hasattr(settings, 'FIREBASE_CREDENTIALS_PATH'):
                    cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                    self.firebase_app = firebase_admin.initialize_app(cred)
                    self.enabled = True
                    logger.info("✓ [FCM] Firebase inicializado correctamente")
                else:
                    logger.warning("⚠️ [FCM] FIREBASE_CREDENTIALS_PATH no configurado en settings.py")

            # Guardar referencia al módulo messaging
            if self.enabled:
                self.messaging = messaging

        except ImportError:
            logger.warning("⚠️ [FCM] firebase-admin no instalado. Instalar: pip install firebase-admin")
        except Exception as e:
            logger.error(f"❌ [FCM] Error al inicializar Firebase: {str(e)}")

    def send_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        image_url: Optional[str] = None,
    ) -> bool:
        """
        Envía una notificación push a un dispositivo específico.

        Args:
            token: Token FCM del dispositivo
            title: Título de la notificación
            body: Cuerpo/mensaje de la notificación
            data: Datos adicionales (dict con valores string)
            image_url: URL de imagen para la notificación (opcional)

        Returns:
            True si se envió exitosamente, False si hubo error
        """
        if not self.enabled:
            logger.warning(f"⚠️ [FCM] Servicio deshabilitado. No se puede enviar: {title}")
            return False

        try:
            # Construir el mensaje
            notification = self.messaging.Notification(
                title=title,
                body=body,
                image=image_url if image_url else None,
            )

            # Configuración Android
            android_config = self.messaging.AndroidConfig(
                priority='high',
                notification=self.messaging.AndroidNotification(
                    sound='default',
                    color='#2563EB',  # Color azul principal de la app
                    channel_id='order_updates',
                ),
            )

            # Configuración iOS
            apns_config = self.messaging.APNSConfig(
                payload=self.messaging.APNSPayload(
                    aps=self.messaging.Aps(
                        sound='default',
                        badge=1,
                    ),
                ),
            )

            message = self.messaging.Message(
                notification=notification,
                data=data if data else {},
                token=token,
                android=android_config,
                apns=apns_config,
            )

            # Enviar mensaje
            response = self.messaging.send(message)
            logger.info(f"✓ [FCM] Notificación enviada: {title} → {token[:20]}... (Response: {response})")
            return True

        except self.messaging.UnregisteredError:
            logger.warning(f"⚠️ [FCM] Token no registrado o inválido: {token[:20]}...")
            # Marcar token como inactivo
            self._deactivate_token(token)
            return False

        except Exception as e:
            logger.error(f"❌ [FCM] Error al enviar notificación: {str(e)}")
            return False

    def send_to_user(
        self,
        user_id: int,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        image_url: Optional[str] = None,
    ) -> int:
        """
        Envía una notificación a todos los dispositivos de un usuario.

        Args:
            user_id: ID del usuario
            title: Título de la notificación
            body: Cuerpo de la notificación
            data: Datos adicionales
            image_url: URL de imagen (opcional)

        Returns:
            Número de notificaciones enviadas exitosamente
        """
        if not self.enabled:
            logger.warning(f"⚠️ [FCM] Servicio deshabilitado")
            return 0

        try:
            from .models import FCMToken

            # Obtener todos los tokens activos del usuario
            tokens = FCMToken.objects.filter(
                user_id=user_id,
                is_active=True
            ).values_list('token', flat=True)

            if not tokens:
                logger.info(f"ℹ️ [FCM] Usuario #{user_id} no tiene tokens FCM activos")
                return 0

            logger.info(f"📤 [FCM] Enviando a usuario #{user_id} ({len(tokens)} dispositivos)")

            sent_count = 0
            for token in tokens:
                if self.send_notification(token, title, body, data, image_url):
                    sent_count += 1

            logger.info(f"✓ [FCM] Enviadas {sent_count}/{len(tokens)} notificaciones a usuario #{user_id}")
            return sent_count

        except Exception as e:
            logger.error(f"❌ [FCM] Error al enviar a usuario #{user_id}: {str(e)}")
            return 0

    def send_order_status_notification(
        self,
        user_id: int,
        order_id: int,
        old_status: int,
        new_status: int,
    ) -> int:
        """
        Envía notificación cuando cambia el estado de un pedido.

        Args:
            user_id: ID del usuario (cliente que hizo el pedido)
            order_id: ID del pedido
            old_status: Estado anterior
            new_status: Estado nuevo

        Returns:
            Número de notificaciones enviadas
        """
        # Mapeo de estados a mensajes
        status_messages = {
            1: {
                'title': '📦 Pedido Enviado',
                'body': f'Tu pedido #{order_id} ha sido enviado al comercio',
                'emoji': '📦',
            },
            2: {
                'title': '✅ Pedido Recibido',
                'body': f'El comercio ha recibido tu pedido #{order_id}',
                'emoji': '✅',
            },
            3: {
                'title': '👨‍🍳 Preparando tu Pedido',
                'body': f'Tu pedido #{order_id} está siendo preparado',
                'emoji': '👨‍🍳',
            },
            4: {
                'title': '🚴 Pedido en Camino',
                'body': f'Un rider está llevando tu pedido #{order_id}',
                'emoji': '🚴',
            },
            5: {
                'title': '🎉 Pedido Entregado',
                'body': f'Tu pedido #{order_id} ha sido entregado. ¡Buen provecho!',
                'emoji': '🎉',
            },
            6: {
                'title': '❌ Pedido Cancelado',
                'body': f'Lo sentimos, tu pedido #{order_id} ha sido cancelado',
                'emoji': '❌',
            },
        }

        notification_info = status_messages.get(new_status)

        if not notification_info:
            logger.warning(f"⚠️ [FCM] Estado desconocido: {new_status}")
            return 0

        # Datos adicionales para la app
        data = {
            'type': 'order_status_change',
            'order_id': str(order_id),
            'old_status': str(old_status),
            'new_status': str(new_status),
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'route': f'/order-tracking/{order_id}',
        }

        logger.info(f"🔔 [FCM] Cambio de estado: Pedido #{order_id}: {old_status} → {new_status}")

        return self.send_to_user(
            user_id=user_id,
            title=notification_info['title'],
            body=notification_info['body'],
            data=data,
        )

    def _deactivate_token(self, token: str):
        """
        Marca un token como inactivo cuando falla el envío.
        """
        try:
            from .models import FCMToken
            FCMToken.objects.filter(token=token).update(is_active=False)
            logger.info(f"ℹ️ [FCM] Token desactivado: {token[:20]}...")
        except Exception as e:
            logger.error(f"❌ [FCM] Error al desactivar token: {str(e)}")


# Instancia global del servicio
fcm_service = FCMNotificationService()
