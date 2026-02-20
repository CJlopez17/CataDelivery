from rest_framework import serializers
from apps.users.serializers import UserProfileSerializer, ClientAdressSerializer
from apps.store.serializers import StoreSerializer

from .models import Order, OrderProduct


class OrderProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderProduct
        fields = "__all__"
        read_only_fields = ["total", "name"]
        extra_kwargs = {"order": {"read_only": True}}


class OrderSerializer(serializers.ModelSerializer):
    oitems = OrderProductSerializer(many=True, required=False)

    # Nested serializers for read operations
    store_data = StoreSerializer(source='store', read_only=True)
    client_data = UserProfileSerializer(source='client', read_only=True)
    rider_data = UserProfileSerializer(source='rider', read_only=True)
    delivery_address_data = ClientAdressSerializer(source='delivery_address', read_only=True)

    class Meta:
        model = Order
        fields = [
            "id",
            "status",
            "dt",
            "payment_method",
            "subtotal",
            "delivery_fee",
            "total",
            "order_comment",
            "cancellation_reason",
            "rider",
            "store",
            "client",
            "delivery_address",
            "oitems",
            "store_data",
            "client_data",
            "rider_data",
            "delivery_address_data",
            "assignment_score",
            "assigned_at",
            "is_auto_assigned",
            "rejected_riders",
        ]
        read_only_fields = [
            "total",
            "dt",
            "store_data",
            "client_data",
            "rider_data",
            "delivery_address_data",
            "assignment_score",
            "assigned_at",
            "is_auto_assigned",
            "rejected_riders",
        ]

    def validate(self, attrs):
        client = attrs.get("client") or getattr(self.instance, "client", None)
        
        delivery_address = attrs.get("delivery_address") or getattr(
            self.instance, "delivery_address", None
        )
        if client and delivery_address and delivery_address.user_id != client.id:
            raise serializers.ValidationError(
                {"delivery_address": "Address must belong to the selected client."}
            )
        return attrs

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        order = super().create(validated_data)
        self._create_or_update_items(order, items_data)
        return order

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)

        # Validar que un rider no pueda aceptar un pedido si ya tiene uno en progreso
        rider = validated_data.get("rider")
        status = validated_data.get("status")

        # Si se está asignando un rider y cambiando a status 4 (In Route)
        if rider and status == 4 and instance.rider != rider:
            # Verificar si el rider ya tiene un pedido en progreso
            active_order = Order.objects.filter(
                rider=rider,
                status=4  # In Route
            ).exclude(id=instance.id).first()

            if active_order:
                raise serializers.ValidationError(
                    {"detail": "No puedes aceptar este pedido porque ya tienes un pedido en progreso. Debes completar el pedido actual primero."}
                )

        # Si un rider está rechazando el pedido (rider=null, status=3)
        # Trackear el rider que rechazó para no asignárselo de nuevo
        if (status == 3 and rider is None and instance.rider is not None):
            rejected_rider_id = instance.rider.id
            rejected_riders = instance.rejected_riders or []

            if rejected_rider_id not in rejected_riders:
                rejected_riders.append(rejected_rider_id)
                validated_data['rejected_riders'] = rejected_riders

        order = super().update(instance, validated_data)
        if items_data is not None:
            order.items.all().delete()
            self._upsert_items(order, items_data)
        return order
    
    def _create_or_update_items(self, order, items_data):
        """
        Inserta los items y recalcula el total.
        """
        for item in items_data:
            OrderProduct.objects.create(order=order, **item)

        items_total = sum(item.total for item in order.items.all())
        order.total = items_total + (order.delivery_fee or 0)
        order.save(update_fields=["total"])
