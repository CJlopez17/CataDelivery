from datetime import datetime, timedelta
from django.utils import timezone
from django.db.models import Q

from apps.store.models import Product
from rest_framework import permissions, serializers, viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.users.models import UserProfile

from .models import Order, OrderProduct
from .serializers import OrderProductSerializer, OrderSerializer
from .utils import assign_orders_to_riders, calculate_assignment_score, calculate_delivery_fee


class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.select_related("rider", "store", "client").prefetch_related("items")
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        print( "DATA RECEIVED:", data)

        items_data = data.pop("items", None)
        if not items_data:
            raise serializers.ValidationError(
                {"error": "You must submit at least one product."},
            )

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        order = serializer.save()

        total_products = 0
        for item in items_data:
            product_id = item.get("product")
            quantity = item.get("quantity")
            price = item.get("price")
            note = item.get("note", "")

            if not product_id or not quantity:
                raise serializers.ValidationError(
                   {"error": "Each product must have product and quantity"},
                )

            product_obj = Product.objects.get(pk=product_id)

            # Validar tienda del producto
            if product_obj.store_id != order.store_id:
                raise serializers.ValidationError(
                   {"error": f"The product {product_obj.name} does not belong to this store."},
                )

            # Crear el OrderProduct
            OrderProduct.objects.create(
                order=order,
                product=product_obj,
                price=price,
                quantity=quantity,
                note=note
            )

            total_products += price * quantity

        # Calcular delivery_fee dinámicamente basándose en la distancia
        # Regla: $0.10 USD por cada 100 metros (store → delivery_address)
        delivery_fee = calculate_delivery_fee(
            store_lat=order.store.latitude,
            store_lon=order.store.longitude,
            delivery_lat=order.delivery_address.latitude,
            delivery_lon=order.delivery_address.longitude
        )

        # Actualizar subtotal, delivery_fee y total de la orden
        order.subtotal = total_products
        order.delivery_fee = delivery_fee
        order.total = total_products + delivery_fee
        order.save()

        print(f"✅ [ORDER CREATE] Orden #{order.pk} creada exitosamente")
        print(f"   • Subtotal: ${total_products:.2f}")
        print(f"   • Delivery Fee: ${delivery_fee:.2f}")
        print(f"   • Total: ${order.total:.2f}")
        print(f"   • Distancia calculada: {delivery_fee / 0.10 * 100 / 1000:.2f} km")

        return Response(self.get_serializer(order).data, status=status.HTTP_201_CREATED)

    def get_queryset(self):
        queryset = (
            Order.objects.select_related(
                "rider", "store", "client", "delivery_address", "store__userprofile"
            )
            .prefetch_related("items")
            .order_by("-dt")
        )
        user = self.request.user
        store = self.request.query_params.get("store")
        date_filter = self.request.query_params.get("date_filter")  # today, yesterday, week, all
        status_filter = self.request.query_params.get("status")  # Filtro por estado

        # Aplicar filtro de estado si se proporciona
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        # Aplicar filtro de fecha si se proporciona
        if date_filter:
            now = timezone.now()
            if date_filter == "today":
                # Pedidos de hoy
                start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
                queryset = queryset.filter(dt__gte=start_of_day)
            elif date_filter == "yesterday":
                # Pedidos de ayer
                start_of_yesterday = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
                end_of_yesterday = now.replace(hour=0, minute=0, second=0, microsecond=0)
                queryset = queryset.filter(dt__gte=start_of_yesterday, dt__lt=end_of_yesterday)
            elif date_filter == "week":
                # Pedidos de la última semana
                start_of_week = now - timedelta(days=7)
                queryset = queryset.filter(dt__gte=start_of_week)

        if user.is_staff:
            if store:
                queryset = queryset.filter(store_id=store)
            return queryset
        if user.role == UserProfile.Roles.CLIENT:
            return queryset.filter(client=user)
        if user.role == UserProfile.Roles.STORE:
            queryset = queryset.filter(store__userprofile=user)
            if store:
                queryset = queryset.filter(store_id=store)
            return queryset
        if user.role == UserProfile.Roles.RIDER:
            # Los riders solo pueden ver:
            # 1. Pedidos que tienen asignados (rider=user)
            # Incluye tanto pedidos asignados automáticamente como manualmente
            return queryset.filter(rider=user)
        if store:
            return queryset.filter(store_id=store)
        return queryset.none()

    def perform_create(self, serializer):
        user = self.request.user
        client = serializer.validated_data.get("client")
        if user.role == UserProfile.Roles.CLIENT and client != user:
            raise serializers.ValidationError(
                {"client": "Clients can only create orders for themselves."}
            )
        serializer.save()

    @action(detail=False, methods=["get"], permission_classes=[permissions.IsAuthenticated])
    def active_order(self, request):
        """
        Endpoint para obtener el pedido activo del rider (status=4, In Route).
        Retorna el pedido si existe, o null si no tiene pedido activo.
        """
        user = request.user

        # Verificar que el usuario sea un rider
        if user.role != UserProfile.Roles.RIDER:
            return Response(
                {"detail": "Solo los riders pueden consultar su pedido activo."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Buscar pedido activo
        active_order = Order.objects.filter(
            rider=user,
            status=4  # In Route
        ).select_related(
            "rider", "store", "client", "delivery_address", "store__userprofile"
        ).prefetch_related("items").first()

        if active_order:
            return Response(
                {
                    "has_active_order": True,
                    "order": self.get_serializer(active_order).data
                },
                status=status.HTTP_200_OK
            )
        else:
            return Response(
                {
                    "has_active_order": False,
                    "order": None
                },
                status=status.HTTP_200_OK
            )

    @action(detail=True, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def mark_delivered(self, request, pk=None):
        """
        Endpoint para que un rider marque un pedido como entregado.
        Solo puede marcar como entregado si es el rider asignado y el pedido está en ruta (status=4).
        """
        order = self.get_object()
        user = request.user

        # Verificar que el usuario sea un rider
        if user.role != UserProfile.Roles.RIDER:
            return Response(
                {"detail": "Solo los riders pueden marcar pedidos como entregados."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Verificar que el rider esté asignado a este pedido
        if order.rider != user:
            return Response(
                {"detail": "Solo puedes marcar como entregado tus propios pedidos."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Verificar que el pedido esté en ruta (status=4)
        if order.status != 4:
            return Response(
                {"detail": "Solo puedes marcar como entregado pedidos que estén en ruta."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Marcar como entregado
        order.status = 5  # Delivered
        order.save(update_fields=["status"])

        return Response(
            {
                "detail": "Pedido marcado como entregado exitosamente.",
                "order": self.get_serializer(order).data
            },
            status=status.HTTP_200_OK
        )

    @action(detail=False, methods=["post"], permission_classes=[permissions.IsAdminUser])
    def auto_assign(self, request):
        """
        Endpoint para ejecutar la asignación automática de pedidos a riders
        usando el algoritmo húngaro.

        Solo accesible para administradores.

        El algoritmo considera:
        1. Distancia entre rider y store
        2. Distancia entre store y cliente

        Asigna automáticamente los pedidos a los riders óptimos.
        """
        import logging
        logger = logging.getLogger(__name__)

        logger.info("="*80)
        logger.info("🚀 [AUTO ASSIGN] Iniciando proceso de asignación automática")
        logger.info(f"👤 [AUTO ASSIGN] Solicitado por admin: {request.user.username} (ID: {request.user.id})")

        # Obtener riders disponibles con ubicación actualizada
        riders = UserProfile.objects.filter(
            role=UserProfile.Roles.RIDER,
            is_active=True,
            is_available=True,
            current_latitude__isnull=False,
            current_longitude__isnull=False,
        ).values(
            'id', 'username', 'current_latitude', 'current_longitude'
        )

        riders_list = list(riders)
        logger.info(f"🚴 [AUTO ASSIGN] Riders disponibles con GPS: {len(riders_list)}")

        if not riders_list:
            logger.warning("⚠️ [AUTO ASSIGN] No hay riders disponibles con ubicación actualizada")
            return Response(
                {"detail": "No hay riders disponibles con ubicación actualizada."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Log detalles de riders
        for rider in riders_list:
            logger.info(f"   • Rider: {rider['username']} (ID: {rider['id']}) @ ({rider['current_latitude']:.4f}, {rider['current_longitude']:.4f})")

        # Obtener pedidos pendientes de asignación (status=3, Preparing, sin rider)
        orders = Order.objects.filter(
            status=3,  # Preparing
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

        logger.info(f"📦 [AUTO ASSIGN] Órdenes pendientes (status=3, sin rider): {len(orders_list)}")

        if not orders_list:
            logger.warning("⚠️ [AUTO ASSIGN] No hay pedidos pendientes de asignación")
            return Response(
                {"detail": "No hay pedidos pendientes de asignación."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Log detalles de órdenes
        for order in orders_list:
            logger.info(f"   • Orden #{order['id']}: Store({order['store_latitude']:.4f}, {order['store_longitude']:.4f}) → Cliente({order['delivery_latitude']:.4f}, {order['delivery_longitude']:.4f})")

        # Ejecutar algoritmo húngaro
        logger.info("🧮 [AUTO ASSIGN] Ejecutando algoritmo húngaro...")
        assignments = assign_orders_to_riders(riders_list, orders_list)

        if not assignments:
            logger.error("❌ [AUTO ASSIGN] No se pudieron generar asignaciones óptimas")
            return Response(
                {"detail": "No se pudieron generar asignaciones óptimas."},
                status=status.HTTP_400_BAD_REQUEST
            )

        logger.info(f"✅ [AUTO ASSIGN] Algoritmo completado. {len(assignments)} asignaciones generadas")

        # Aplicar las asignaciones
        assigned_orders = []
        total_distance = 0

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

                assigned_orders.append({
                    'order_id': order_id,
                    'rider_id': rider_id,
                    'rider_name': rider.username,
                    'distance_km': round(distance, 2)
                })

                total_distance += distance

            except (Order.DoesNotExist, UserProfile.DoesNotExist) as e:
                logger.error(f"   ✗ Error asignando orden #{order_id}: {str(e)}")
                continue

        avg_distance = total_distance / len(assigned_orders) if assigned_orders else 0

        logger.info("="*80)
        logger.info(f"📊 [AUTO ASSIGN] RESUMEN:")
        logger.info(f"   • Asignaciones realizadas: {len(assigned_orders)}")
        logger.info(f"   • Distancia total: {total_distance:.2f} km")
        logger.info(f"   • Distancia promedio: {avg_distance:.2f} km")
        logger.info("="*80)

        return Response(
            {
                "detail": f"Se asignaron {len(assigned_orders)} pedidos exitosamente.",
                "assignments": assigned_orders
            },
            status=status.HTTP_200_OK
        )


class OrderProductViewSet(viewsets.ModelViewSet):
    queryset = OrderProduct.objects.select_related("order", "product")
    serializer_class = OrderProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = OrderProduct.objects.select_related(
            "order",
            "product",
            "order__client",
            "order__store",
            "order__rider",
        )
        user = self.request.user
        store = self.request.query_params.get("store")
        order = self.request.query_params.get("order")

        if user.is_staff:
            # Admin puede ver todos, aplicar filtros si se proporcionan
            if store:
                queryset = queryset.filter(order__store_id=store)
            if order:
                queryset = queryset.filter(order_id=order)
            return queryset

        if user.role == UserProfile.Roles.CLIENT:
            queryset = queryset.filter(order__client=user)
        elif user.role == UserProfile.Roles.STORE:
            queryset = queryset.filter(order__store__userprofile=user)
        elif user.role == UserProfile.Roles.RIDER:
            # Los riders pueden ver productos de:
            # 1. Pedidos que ya tienen asignados (order__rider=user)
            # 2. Pedidos disponibles (order__status=3, order__rider=null)
            from django.db.models import Q
            queryset = queryset.filter(
                Q(order__rider=user) | Q(order__status=3, order__rider__isnull=True)
            )
        else:
            return queryset.none()

        # Aplicar filtros adicionales si se proporcionan
        if store:
            queryset = queryset.filter(order__store_id=store)
        if order:
            queryset = queryset.filter(order_id=order)

        return queryset
