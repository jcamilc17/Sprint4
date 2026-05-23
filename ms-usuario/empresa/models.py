import datetime
from django.db import models


class Empresa(models.Model):
    nombre = models.CharField(max_length=100)
    razonSocial = models.CharField(max_length=100)
    nit = models.CharField(max_length=100)
    sector = models.CharField(max_length=100)
    fechaRegistro = models.DateField(default=datetime.date.today)
    estado = models.CharField(max_length=100)
    plan_suscripcion_id = models.IntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.nombre}, {self.nit}"

    class Meta:
        app_label = "empresa"
