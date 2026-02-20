"""
URL configuration for catadelivery project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from apps.chat.api_views import ConversationViewSet
from apps.order.api_views import OrderProductViewSet, OrderViewSet
from apps.store.api_views import CategoryViewSet, ProductViewSet, StoreViewSet
from apps.users.api_views import (
    CatadeliveryTokenObtainPairView,
    ChangePasswordView,
    ClientAddressViewSet,
    ForgotPasswordView,
    LogoutView,
    MonthSubscriptionViewSet,
    RegistrationView,
    ResetPasswordView,
    RoleChangeRequestViewSet,
    ToggleActiveStatusView,
    UserProfileViewSet,
)

router = DefaultRouter()
router.register(r"users", UserProfileViewSet)
router.register(r"subscriptions", MonthSubscriptionViewSet)
router.register(r"addresses", ClientAddressViewSet)
router.register(r"stores", StoreViewSet)
router.register(r"categories", CategoryViewSet)
router.register(r"products", ProductViewSet)
router.register(r"orders", OrderViewSet)
router.register(r"order-products", OrderProductViewSet)
router.register(r'role-change-requests', RoleChangeRequestViewSet, basename='role-change-requests')
router.register(r"chat/conversations", ConversationViewSet, basename="conversations")


urlpatterns = [
    path('admin/', admin.site.urls),
    path("api/", include(router.urls)),
    path("api/auth/login/", CatadeliveryTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/auth/logout/", LogoutView.as_view(), name="logout"),
    path("api/auth/register/", RegistrationView.as_view(), name="register"),
    path("api/auth/change-password/", ChangePasswordView.as_view(), name="change_password"),
    path("api/auth/forgot-password/", ForgotPasswordView.as_view(), name="forgot_password"),
    path("api/auth/reset-password/", ResetPasswordView.as_view(), name="reset_password"),
    path("api/auth/toggle-active/", ToggleActiveStatusView.as_view(), name="toggle_active"),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]+ static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
