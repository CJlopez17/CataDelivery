from django.contrib import admin

from .models import Conversation


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ("id", "order", "participant_1", "participant_2", "created_at")
    list_filter = ("created_at",)
    search_fields = (
        "participant_1__username",
        "participant_2__username",
        "order__id",
    )
    readonly_fields = ("id", "created_at")
