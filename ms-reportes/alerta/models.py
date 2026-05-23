from django.db import models


class Alerta(models.Model):
    tipo = models.CharField(max_length=100)
    severidad = models.CharField(max_length=100)
    mensaje = models.CharField(max_length=500)
    fechaCreacion = models.DateField(auto_now_add=True)
    fechaLectura = models.DateField(auto_now=True)
    estado = models.CharField(max_length=100)
    usuario_id = models.IntegerField(null=True, blank=True)
    empresa_id = models.IntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.tipo}-{self.severidad}: {self.mensaje}"

    class Meta:
        app_label = "alerta"
