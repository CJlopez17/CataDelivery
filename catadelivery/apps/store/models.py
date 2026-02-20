from django.db import models

from apps.users.models import UserProfile
from django.core.exceptions import ValidationError
from django.core.validators import FileExtensionValidator

def validate_file_size(value):
    max_size_mb = 10
    if value.size > max_size_mb * 1024 * 1024:
        raise ValidationError(f"El archivo no puede superar los {max_size_mb}MB.")


# Create your models here.
class Store(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    address = models.TextField()
    latitude = models.FloatField()
    longitude = models.FloatField()
    enabled = models.BooleanField()
    logo = models.ImageField(
        upload_to="store_logos/",
        validators=[
            FileExtensionValidator(["jpg", "jpeg", "png"]),
            validate_file_size
        ],
        null=True,
        blank=True
    )
    
    userprofile = models.ForeignKey(
        UserProfile, 
        on_delete=models.CASCADE, 
        related_name="stores", 
        limit_choices_to={"role": UserProfile.Roles.STORE},)

    class Meta:
        verbose_name = "Store"
        verbose_name_plural = "Stores"

    def __str__(self):
        return self.name

class Category(models.Model):
    name = models.CharField(max_length=100)
    
    class Meta:
        verbose_name = "Category"
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name

class Product(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    price = models.FloatField(null=True, blank=True)
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    store = models.ForeignKey(Store, on_delete=models.CASCADE)
    photoProduct = models.ImageField(
        upload_to="product_logos/",
        validators=[
            FileExtensionValidator(["jpg", "jpeg", "png"]),
            validate_file_size
        ],
        null=True,
        blank=True
    )

    class Meta:
        verbose_name = "Product"
        verbose_name_plural = "Products"

    def __str__(self):
        return self.name