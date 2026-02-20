from django.contrib import admin
from import_export.admin import ImportExportModelAdmin
from unfold.admin import ModelAdmin, TabularInline

from .models import Order, OrderProduct


class BaseImportExportAdmin(ImportExportModelAdmin, ModelAdmin):
    pass


class OrderProductInline(TabularInline):
    model = OrderProduct
    extra = 0
    readonly_fields = ("name", "total")


@admin.register(Order)
class OrderAdmin(BaseImportExportAdmin):
    list_display = ("id", "store", "client", "rider", "status", "dt", "total")
    list_filter = ("status", "store")
    search_fields = ("store__name", "client__username", "rider__username")
    autocomplete_fields = ("store", "client", "rider", "delivery_address")
    inlines = [OrderProductInline]


@admin.register(OrderProduct)
class OrderProductAdmin(BaseImportExportAdmin):
    list_display = ("order", "product", "price", "quantity", "total")
    autocomplete_fields = ("order", "product")
    search_fields = ("order__id", "product__name")

