from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.core.mail import send_mail
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from apps.store.serializers import StoreSerializer
from rest_framework.generics import GenericAPIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework import permissions, serializers, viewsets, status
from rest_framework.decorators import action

from .models import ClientAddress, FCMToken, MonthSubscription, RoleChangeRequest, UserProfile
from .serializers import (
    CatadeliveryTokenObtainPairSerializer,
    ChangePasswordSerializer,
    ClientAdressSerializer,
    FCMTokenSerializer,
    ForgotPasswordSerializer,
    MonthSuscriptionSerializer,
    RegistrationSerializer,
    ResetPasswordSerializer,
    RoleChangeRequestSerializer,
    UserProfileSerializer,
)

User = get_user_model()


class UserProfileViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all().order_by("-date_joined")
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = (
            User.objects.prefetch_related("subscriptions", "addresses", "stores")
            .order_by("-date_joined")
        )
        user = self.request.user
        if user.is_staff:
            return queryset

        # Los riders pueden ver información de clientes de sus pedidos
        if user.role == UserProfile.Roles.RIDER:
            from apps.order.models import Order
            from django.db.models import Q
            # Obtener IDs de clientes de órdenes asignadas o disponibles
            client_ids = Order.objects.filter(
                Q(rider=user) | Q(status=3, rider__isnull=True)
            ).values_list('client_id', flat=True).distinct()
            return queryset.filter(Q(pk=user.pk) | Q(pk__in=client_ids))

        return queryset.filter(pk=user.pk)

    def perform_update(self, serializer):
        if not self.request.user.is_staff:
            serializer.save(role=serializer.instance.role)
        else:
            serializer.save()
    
    def get_store(self, obj):
        if obj.role != UserProfile.Roles.STORE:
            return None

        if hasattr(obj, "stores"):
            return StoreSerializer(obj.store).data

    @action(detail=False, methods=["get"], permission_classes=[permissions.IsAuthenticated])
    def my_subscription(self, request):
        """
        Endpoint para que riders y stores consulten su propia suscripción.
        Retorna la suscripción del usuario actual con días restantes y estado.
        """
        user = request.user

        # Verificar que el usuario sea rider o store
        if user.role not in {UserProfile.Roles.RIDER, UserProfile.Roles.STORE}:
            return Response(
                {"detail": "Solo riders y stores tienen suscripción mensual."},
                status=status.HTTP_403_FORBIDDEN
            )

        subscription = user.get_current_subscription()
        if not subscription:
            return Response(
                {
                    "has_subscription": False,
                    "message": "No tienes una suscripción activa. Contacta al administrador."
                },
                status=status.HTTP_200_OK
            )

        return Response(
            {
                "has_subscription": True,
                "subscription": MonthSuscriptionSerializer(subscription, context={'request': request}).data
            },
            status=status.HTTP_200_OK
        )

    @action(detail=False, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def upload_payment_proof(self, request):
        """
        Endpoint para que riders y stores suban su comprobante de pago.
        El administrador debe aprobar el pago desde el panel de Django.
        """
        user = request.user

        # Verificar que el usuario sea rider o store
        if user.role not in {UserProfile.Roles.RIDER, UserProfile.Roles.STORE}:
            return Response(
                {"detail": "Solo riders y stores pueden subir comprobantes de pago."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Verificar que se haya enviado un archivo
        if 'document' not in request.FILES:
            return Response(
                {"detail": "Debe enviar un archivo en el campo 'document'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        document = request.FILES['document']

        # Siempre crear una nueva suscripción con status=pending
        subscription = MonthSubscription.objects.create(
            user=user,
            document=document,
        )

        return Response(
            {
                "detail": "Comprobante de pago enviado exitosamente. El administrador revisará y activará tu suscripción.",
                "subscription": MonthSuscriptionSerializer(subscription, context={'request': request}).data
            },
            status=status.HTTP_201_CREATED
        )

    @action(detail=False, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def update_location(self, request):
        """
        Endpoint para que los riders actualicen su ubicación actual.
        Esta ubicación se usa para el algoritmo de asignación automática de pedidos.

        Body params:
            latitude (float): Latitud actual
            longitude (float): Longitud actual
        """
        import logging
        logger = logging.getLogger(__name__)

        user = request.user
        logger.info(f"📍 [LOCATION UPDATE] Rider {user.username} (ID: {user.id}) solicitando actualizar ubicación")

        # Verificar que el usuario sea rider
        if user.role != UserProfile.Roles.RIDER:
            logger.warning(f"⚠️ [LOCATION UPDATE] Usuario {user.username} no es rider (role: {user.role})")
            return Response(
                {"detail": "Solo los riders pueden actualizar su ubicación."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Obtener coordenadas del request
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')

        # Validar que se proporcionaron las coordenadas
        if latitude is None or longitude is None:
            logger.error(f"❌ [LOCATION UPDATE] Rider {user.username}: coordenadas faltantes")
            return Response(
                {"detail": "Debe proporcionar latitude y longitude."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validar que sean números válidos
        try:
            latitude = float(latitude)
            longitude = float(longitude)
        except (ValueError, TypeError):
            logger.error(f"❌ [LOCATION UPDATE] Rider {user.username}: coordenadas inválidas (lat={latitude}, lon={longitude})")
            return Response(
                {"detail": "Las coordenadas deben ser números válidos."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validar rangos de coordenadas
        if not (-90 <= latitude <= 90):
            logger.error(f"❌ [LOCATION UPDATE] Rider {user.username}: latitud fuera de rango ({latitude})")
            return Response(
                {"detail": "La latitud debe estar entre -90 y 90."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not (-180 <= longitude <= 180):
            logger.error(f"❌ [LOCATION UPDATE] Rider {user.username}: longitud fuera de rango ({longitude})")
            return Response(
                {"detail": "La longitud debe estar entre -180 y 180."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Ubicación anterior (para logging)
        prev_lat = user.current_latitude
        prev_lon = user.current_longitude

        # Actualizar ubicación
        user.current_latitude = latitude
        user.current_longitude = longitude
        user.last_location_update = timezone.now()
        user.save(update_fields=['current_latitude', 'current_longitude', 'last_location_update'])

        if prev_lat and prev_lon:
            logger.info(f"✅ [LOCATION UPDATE] Rider {user.username}: ({prev_lat:.4f}, {prev_lon:.4f}) → ({latitude:.4f}, {longitude:.4f})")
        else:
            logger.info(f"✅ [LOCATION UPDATE] Rider {user.username}: Primera ubicación guardada ({latitude:.4f}, {longitude:.4f})")

        return Response(
            {
                "detail": "Ubicación actualizada exitosamente.",
                "latitude": latitude,
                "longitude": longitude,
                "updated_at": user.last_location_update.isoformat()
            },
            status=status.HTTP_200_OK
        )

    @action(detail=False, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def register_fcm_token(self, request):
        """
        Endpoint para registrar o actualizar el token FCM de un dispositivo.
        Permite enviar notificaciones push al usuario.

        Body params:
            token (string): Token FCM del dispositivo
            device_id (string, opcional): ID único del dispositivo
            platform (string, opcional): 'android', 'ios' o 'web'
        """
        import logging
        logger = logging.getLogger(__name__)

        user = request.user
        token = request.data.get('token')

        if not token:
            return Response(
                {"detail": "El campo 'token' es requerido."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Crear o actualizar token
        serializer = FCMTokenSerializer(data={
            'user': user.id,
            'token': token,
            'device_id': request.data.get('device_id'),
            'platform': request.data.get('platform', 'android'),
        })

        if serializer.is_valid():
            fcm_token = serializer.save()
            logger.info(f"✓ [FCM] Token registrado para {user.username}: {token[:20]}...")
            return Response({
                "detail": "Token FCM registrado exitosamente.",
                "token_id": fcm_token.id,
            }, status=status.HTTP_201_CREATED)
        else:
            logger.error(f"❌ [FCM] Error al registrar token para {user.username}: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def unregister_fcm_token(self, request):
        """
        Endpoint para eliminar/desactivar un token FCM.
        Útil cuando el usuario cierra sesión o desinstala la app.

        Body params:
            token (string): Token FCM a eliminar
        """
        import logging
        logger = logging.getLogger(__name__)

        user = request.user
        token = request.data.get('token')

        if not token:
            return Response(
                {"detail": "El campo 'token' es requerido."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Eliminar o desactivar token
        deleted_count = FCMToken.objects.filter(
            user=user,
            token=token
        ).delete()[0]

        if deleted_count > 0:
            logger.info(f"✓ [FCM] Token eliminado para {user.username}: {token[:20]}...")
            return Response({
                "detail": "Token FCM eliminado exitosamente.",
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                "detail": "Token no encontrado.",
            }, status=status.HTTP_404_NOT_FOUND)


class MonthSubscriptionViewSet(viewsets.ModelViewSet):
    queryset = MonthSubscription.objects.all().order_by("-created_at")
    serializer_class = MonthSuscriptionSerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        return MonthSubscription.objects.select_related("user").order_by("-created_at")

    def perform_create(self, serializer):
        user = serializer.validated_data["user"]
        if user.role not in {User.Roles.RIDER, User.Roles.STORE}:
            raise serializers.ValidationError(
                {"user": "Subscriptions are only required for store or rider users."}
            )
        serializer.save()

    def perform_update(self, serializer):
        user = serializer.instance.user
        if user.role not in {User.Roles.RIDER, User.Roles.STORE}:
            raise serializers.ValidationError(
                {"user": "Subscriptions are only required for store or rider users."}
            )
        serializer.save()


class ClientAddressViewSet(viewsets.ModelViewSet):
    queryset = ClientAddress.objects.all().order_by("name")
    serializer_class = ClientAdressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = ClientAddress.objects.order_by("name")
        user = self.request.user
        if user.is_staff:
            return queryset

        # Los riders pueden ver direcciones de clientes de sus pedidos
        if user.role == UserProfile.Roles.RIDER:
            from apps.order.models import Order
            from django.db.models import Q
            # Obtener IDs de clientes de órdenes asignadas o disponibles
            client_ids = Order.objects.filter(
                Q(rider=user) | Q(status=3, rider__isnull=True)
            ).values_list('client_id', flat=True).distinct()
            return queryset.filter(Q(user=user) | Q(user_id__in=client_ids))

        return queryset.filter(user=user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class RoleChangeRequestViewSet(viewsets.ModelViewSet):
    serializer_class = RoleChangeRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = RoleChangeRequest.objects.select_related("user", "resolved_by")
        if self.request.user.is_staff:
            return queryset
        return queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        requested_role = serializer.validated_data["requested_role"]
        if requested_role == self.request.user.role:
            raise serializers.ValidationError(
                {"requested_role": "You already have this role."}
            )
        if self.request.user.role != User.Roles.CLIENT:
            raise serializers.ValidationError(
                {"requested_role": "Only client users can request a role change."}
            )
        if requested_role not in {User.Roles.RIDER, User.Roles.STORE}:
            raise serializers.ValidationError(
                {"requested_role": "You can request to become a rider or store only."}
            )
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        if not self.request.user.is_staff:
            raise permissions.PermissionDenied("Only administrators can resolve requests.")
        status_value = serializer.validated_data.get("status", serializer.instance.status)
        resolved_at = None
        resolved_by = None
        if status_value != RoleChangeRequest.Status.PENDING:
            resolved_at = timezone.now()
            resolved_by = self.request.user
        instance = serializer.save(resolved_by=resolved_by, resolved_at=resolved_at)
        if instance.status == RoleChangeRequest.Status.APPROVED:
            instance.user.role = instance.requested_role
            instance.user.is_available = False
            instance.user.save(update_fields=["role", "is_available"])

class CatadeliveryTokenObtainPairView(TokenObtainPairView):
    serializer_class = CatadeliveryTokenObtainPairSerializer
    permission_classes = [permissions.AllowAny]


class RegistrationView(GenericAPIView):
    serializer_class = RegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        data = {
            "user": UserProfileSerializer(user).data,
            "refresh": str(refresh),
            "access": str(refresh.access_token),
        }
        return Response(data, status=status.HTTP_201_CREATED)


class ChangePasswordView(GenericAPIView):
    serializer_class = ChangePasswordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data["old_password"]):
            return Response({"old_password": ["Incorrect password."]}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(serializer.validated_data["new_password"])
        user.save()
        return Response({"detail": "Password updated successfully."})


class ForgotPasswordView(GenericAPIView):
    serializer_class = ForgotPasswordSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({"detail": "If an account with that email exists, a reset link has been sent."})

        token_generator = PasswordResetTokenGenerator()
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = token_generator.make_token(user)
        reset_path = f"{uid}/{token}"
        base_url = getattr(settings, "FRONTEND_URL", "http://localhost:8000/reset-password")
        reset_url = f"{base_url.rstrip('/')}/{reset_path}"
        message = (
            "Use the following link to reset your Catadelivery password:\n"
            f"{reset_url}\n\n"
            "If you did not request a password reset, you can ignore this email."
        )
        send_mail(
            subject="Catadelivery password reset",
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
        )
        return Response({"detail": "Password reset email sent."})


class ResetPasswordView(GenericAPIView):
    serializer_class = ResetPasswordSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        uid = serializer.validated_data["uid"]
        token = serializer.validated_data["token"]
        try:
            uid_int = force_str(urlsafe_base64_decode(uid))
            user = User.objects.get(pk=uid_int)
        except (User.DoesNotExist, ValueError, TypeError):
            return Response({"detail": "Invalid token."}, status=status.HTTP_400_BAD_REQUEST)

        token_generator = PasswordResetTokenGenerator()
        if not token_generator.check_token(user, token):
            return Response({"detail": "Invalid token."}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(serializer.validated_data["new_password"])
        user.save()
        return Response({"detail": "Password has been reset."})


class LogoutView(GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return Response({"detail": "Refresh token is required."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except Exception:  # noqa: BLE001
            return Response({"detail": "Invalid token."}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"detail": "Logged out successfully."}, status=status.HTTP_205_RESET_CONTENT)


class ToggleActiveStatusView(GenericAPIView):
    """
    Permite a riders y stores cambiar su disponibilidad para recibir pedidos.
    Cuando están no disponibles, no pueden recibir nuevos pedidos.
    Requiere suscripción activa y vigente para activarse.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        user = request.user

        # Solo riders y stores pueden cambiar su disponibilidad
        if user.role not in {User.Roles.RIDER, User.Roles.STORE}:
            return Response(
                {"detail": "Solo repartidores y tiendas pueden cambiar su disponibilidad."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Si intenta activarse (pasar de no disponible a disponible)
        if not user.is_available:
            if not user.has_active_subscription():
                return Response(
                    {
                        "detail": "No puedes activarte porque no tienes una suscripción vigente. Por favor, sube tu comprobante de pago.",
                        "is_available": False,
                        "subscription_expired": True
                    },
                    status=status.HTTP_403_FORBIDDEN
                )

        # Cambiar la disponibilidad
        user.is_available = not user.is_available
        user.save(update_fields=["is_available"])

        status_text = "disponible" if user.is_available else "no disponible"
        return Response({
            "detail": f"Estado cambiado a {status_text}.",
            "is_available": user.is_available
        })


