from ast import Store
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.utils.translation import gettext_lazy as _
from apps.store.serializers import StoreSerializer
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import ClientAddress, FCMToken, MonthSubscription, RoleChangeRequest, UserProfile

User = get_user_model()

class MonthSuscriptionSerializer(serializers.ModelSerializer):
    days_remaining = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()
    has_pending_document = serializers.SerializerMethodField()
    document_url = serializers.SerializerMethodField()

    class Meta:
        model = MonthSubscription
        fields = [
            "id", "user", "status", "starts_at", "expires_at",
            "created_at", "document", "days_remaining", "is_expired",
            "has_pending_document", "document_url",
        ]
        read_only_fields = [
            "id", "status", "starts_at", "expires_at", "created_at",
            "days_remaining", "is_expired", "has_pending_document", "document_url",
        ]

    def get_days_remaining(self, obj):
        from django.utils import timezone
        if obj.expires_at and obj.expires_at > timezone.now():
            return (obj.expires_at - timezone.now()).days
        return 0

    def get_is_expired(self, obj):
        if obj.status == MonthSubscription.Status.PENDING:
            return False
        if obj.status == MonthSubscription.Status.EXPIRED:
            return True
        if obj.status == MonthSubscription.Status.ACTIVE and obj.expires_at:
            from django.utils import timezone
            return obj.expires_at < timezone.now()
        return obj.status == MonthSubscription.Status.REJECTED

    def get_has_pending_document(self, obj):
        return obj.status == MonthSubscription.Status.PENDING

    def get_document_url(self, obj):
        if obj.document:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.document.url)
            return obj.document.url
        return None


class ClientAdressSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClientAddress
        fields = ["id", "user", "name", "latitude", "longitude", "description"]
        read_only_fields = ["id", "user"]


class UserProfileSerializer(serializers.ModelSerializer):
    subscription = serializers.SerializerMethodField()
    addresses = ClientAdressSerializer(many=True, read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "phone_number",
            "role",
            "is_active",
            "is_available",
            "date_joined",
            "subscription",
            "addresses",
            "stores",
            "current_latitude",
            "current_longitude",
            "last_location_update",
        ]
        read_only_fields = ["id", "date_joined", "is_active", "subscription", "addresses", "last_location_update"]

    def validate_is_available(self, value):
        """
        Valida que is_available solo se pueda activar (True) si la suscripción
        mensual está activa. Desactivar (False) se permite siempre.
        """
        if not value:
            return value

        user = self.instance
        if user and user.role in {UserProfile.Roles.RIDER, UserProfile.Roles.STORE}:
            if not user.has_active_subscription():
                raise serializers.ValidationError(
                    "No se puede activar la disponibilidad sin una suscripción mensual activa."
                )
        return value

    def get_subscription(self, obj):
        sub = obj.get_current_subscription()
        if sub:
            return MonthSuscriptionSerializer(sub, context=self.context).data
        return None

    def get_store(self, obj):
        if obj.role == UserProfile.Roles.STORE:
            if hasattr(obj, "stores"):
                return StoreSerializer(obj.store).data
        return None


class RegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    password2 = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "first_name",
            "last_name",
            "password",
            "password2",
        )

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError({"password": _("Passwords do not match.")})
        validate_password(attrs["password"])
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        validated_data.pop("password2")
        user = User(**validated_data)
        user.set_password(password)
        user.role = User.Roles.CLIENT
        user.save()
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value

class CatadeliveryTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["username"] = user.username
        token["email"] = user.email
        token["role"] = user.role
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserProfileSerializer(self.user).data
        return data
    
class RoleChangeRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoleChangeRequest
        fields = [
            "id",
            "user",
            "requested_role",
            "message",
            "status",
            "resolved_by",
            "resolved_at",
            "created_at",
        ]
        read_only_fields = ["id", "user", "status", "resolved_by", "resolved_at", "created_at"]


class FCMTokenSerializer(serializers.ModelSerializer):
    """
    Serializer para registrar y actualizar tokens FCM de dispositivos.
    """
    class Meta:
        model = FCMToken
        fields = [
            "id",
            "user",
            "token",
            "device_id",
            "platform",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "user", "created_at", "updated_at"]

    def create(self, validated_data):
        """
        Crea o actualiza un token FCM.
        Si el token ya existe, lo actualiza en lugar de crear uno nuevo.
        """
        token = validated_data.get('token')
        user = validated_data.get('user')

        # Buscar si ya existe el token
        existing_token = FCMToken.objects.filter(token=token).first()

        if existing_token:
            # Actualizar token existente
            for key, value in validated_data.items():
                setattr(existing_token, key, value)
            existing_token.is_active = True
            existing_token.save()
            return existing_token

        # Crear nuevo token
        return super().create(validated_data)