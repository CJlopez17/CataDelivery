from rest_framework import permissions, serializers, viewsets

from apps.users.models import UserProfile

from .models import Category, Product, Store
from .serializers import CategorySerializer, ProductSerializer, StoreSerializer


class StoreViewSet(viewsets.ModelViewSet):
    queryset = Store.objects.all().order_by("name")
    serializer_class = StoreSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = Store.objects.select_related("userprofile").order_by("name")
        user = self.request.user
        if user.is_staff:
            return queryset
        if user.role == UserProfile.Roles.STORE:
            return queryset.filter(userprofile=user)
        return queryset.filter(enabled=True)

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == UserProfile.Roles.STORE and not user.is_staff:
            serializer.save(userprofile=user)
        else:
            serializer.save()

    def perform_update(self, serializer):
        store = serializer.instance
        user = self.request.user
        if not user.is_staff and store.userprofile != user:
            raise permissions.PermissionDenied("You can only update your own store.")
        serializer.save()


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all().order_by("name")
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]


class ProductViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.all().order_by("name")
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = Product.objects.select_related("store", "category", "store__userprofile").order_by("name")
        user = self.request.user
        if not user.is_staff and user.role == UserProfile.Roles.STORE:
            queryset = queryset.filter(store__userprofile=user)
        store_param = self.request.query_params.get("store")
        if store_param:
            queryset = queryset.filter(store_id=store_param)
        return queryset

    def perform_create(self, serializer):
        user = self.request.user
        store = serializer.validated_data.get("store")
        if not store:
            raise serializers.ValidationError({"store": "A store is required."})
        if not user.is_staff and store.userprofile != user:
            raise permissions.PermissionDenied("You can only create products for your store.")
        serializer.save()

    def perform_update(self, serializer):
        user = self.request.user
        product = serializer.instance
        store = serializer.validated_data.get("store", product.store)
        if not user.is_staff and store.userprofile != user:
            raise permissions.PermissionDenied("You can only update products for your store.")
        serializer.save()
