from django.apps import AppConfig


class OrderConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.order'

    def ready(self):
        """Importa los signals cuando la app está lista."""
        import apps.order.signals  # noqa
