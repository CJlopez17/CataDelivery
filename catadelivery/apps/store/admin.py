from django.contrib import admin
from import_export.admin import ImportExportModelAdmin
from unfold.admin import ModelAdmin

from .models import Category, Product, Store


class BaseImportExportAdmin(ImportExportModelAdmin, ModelAdmin):
    pass


@admin.register(Store)
class StoreAdmin(BaseImportExportAdmin):
    list_display = ("name", "enabled", "userprofile")
    list_filter = ("enabled",)
    search_fields = ("name", "userprofile__username")
    autocomplete_fields = ("userprofile",)


@admin.register(Category)
class CategoryAdmin(BaseImportExportAdmin):
    list_display = ("name",)
    search_fields = ("name",)


@admin.register(Product)
class ProductAdmin(BaseImportExportAdmin):
    list_display = ("name", "price", "category", "store")
    list_filter = ("category", "store")
    search_fields = ("name", "store__name")
    autocomplete_fields = ("category", "store")
