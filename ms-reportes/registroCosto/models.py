from django.db import models


class RegistroCosto(models.Model):
    fecha = models.DateField(auto_now_add=True)
    monto = models.DecimalField(max_digits=14, decimal_places=2)
    moneda = models.CharField(max_length=10)
    servicioCloud = models.CharField(max_length=100)
    unidadMedida = models.CharField(max_length=50)
    cantidad = models.DecimalField(max_digits=14, decimal_places=2)
    recursoCloud_id = models.IntegerField(null=True, blank=True)
    proyecto_id = models.IntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.servicioCloud} - {self.monto}{self.moneda} ({self.fecha})"

    class Meta:
        app_label = "registroCosto"


registroCosto = RegistroCosto
