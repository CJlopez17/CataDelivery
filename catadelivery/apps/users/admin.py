from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from import_export.admin import ImportExportModelAdmin
from unfold.admin import ModelAdmin

from .models import ClientAddress, MonthSubscription, RoleChangeRequest, UserProfile
from django.utils.translation import gettext_lazy as _


class BaseImportExportAdmin(ImportExportModelAdmin, ModelAdmin):
    pass


@admin.register(UserProfile)
class UserProfileAdmin(BaseImportExportAdmin, UserAdmin):
    list_display = (
        "username",
        "email",
        "first_name",
        "last_name",
        "role",
        "is_active",
        "is_available",
    )
    list_filter = ("role", "is_active", "is_available")
    search_fields = ("username", "email", "first_name", "last_name")
    ordering = ("username",)
    fieldsets = UserAdmin.fieldsets + (
        (_("Catadelivery"), {"fields": ("role", "is_available")}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + ((_("Catadelivery"), {"fields": ("role",)}),)


@admin.register(MonthSubscription)
class MonthSuscriptionAdmin(BaseImportExportAdmin):
    list_display = ("id", "user", "user_role", "status", "starts_at", "expires_at", "has_document", "view_document_link")
    list_filter = ("status", "user__role")
    search_fields = ("user__username", "user__email")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "status", "starts_at", "expires_at", "view_document_preview")
    actions = ["approve_subscriptions", "reject_subscriptions"]
    fieldsets = (
        ("Información del Usuario", {
            "fields": ("user",)
        }),
        ("Estado y Periodo", {
            "fields": ("status", "starts_at", "expires_at")
        }),
        ("Comprobante de Pago", {
            "fields": ("document", "view_document_preview")
        }),
        ("Información del Sistema", {
            "fields": ("created_at",),
            "classes": ("collapse",)
        }),
    )

    def user_role(self, obj):
        """Muestra el rol del usuario"""
        return obj.user.get_role_display()
    user_role.short_description = "Rol"

    def has_document(self, obj):
        """Indica si tiene documento subido"""
        return bool(obj.document)
    has_document.boolean = True
    has_document.short_description = "Tiene Comprobante"

    def view_document_link(self, obj):
        """Link para ver el documento en la lista"""
        if obj.document:
            return f'<a href="{obj.document.url}" target="_blank">Ver Documento</a>'
        return "-"
    view_document_link.allow_tags = True
    view_document_link.short_description = "Comprobante"

    def view_document_preview(self, obj):
        """Preview del documento en el formulario de edición"""
        if obj.document:
            file_extension = obj.document.name.split('.')[-1].lower()
            if file_extension in ['jpg', 'jpeg', 'png']:
                return f'<img src="{obj.document.url}" style="max-width: 500px; max-height: 500px;" /><br><a href="{obj.document.url}" target="_blank">Ver en tamaño completo</a>'
            elif file_extension == 'pdf':
                return f'<a href="{obj.document.url}" target="_blank">Ver PDF</a><br><embed src="{obj.document.url}" type="application/pdf" width="100%" height="600px" />'
        return "No hay documento subido"
    view_document_preview.allow_tags = True
    view_document_preview.short_description = "Vista Previa del Comprobante"

    @admin.action(description="Aprobar suscripciones seleccionadas")
    def approve_subscriptions(self, request, queryset):
        count = 0
        for sub in queryset.filter(status=MonthSubscription.Status.PENDING):
            sub.approve()
            count += 1
        self.message_user(request, f"{count} suscripción(es) aprobada(s).")

    @admin.action(description="Rechazar suscripciones seleccionadas")
    def reject_subscriptions(self, request, queryset):
        count = 0
        for sub in queryset.filter(status=MonthSubscription.Status.PENDING):
            sub.reject()
            count += 1
        self.message_user(request, f"{count} suscripción(es) rechazada(s).")


@admin.register(ClientAddress)
class ClientAdressAdmin(BaseImportExportAdmin):
    list_display = ("name", "latitude", "longitude")
    search_fields = ("name",)
    
@admin.register(RoleChangeRequest)
class RoleChangeRequestAdmin(BaseImportExportAdmin):
    list_display = ("id", "user", "requested_role", "status", "created_at", "resolved_at")
    list_filter = ("status", "requested_role")
    search_fields = ("user__username", "user__email")
    autocomplete_fields = ("user", "resolved_by")


admin.site.site_header = "Catadelivery"
admin.site.site_title = "Catadelivery"
admin.site.index_title = "Catadelivery administration"