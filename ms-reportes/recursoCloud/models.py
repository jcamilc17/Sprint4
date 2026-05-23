from django.db import models


class RecursoCloud(models.Model):
    nombre = models.CharField(max_length=100)
    tipo = models.CharField(max_length=100)
    region = models.CharField(max_length=100)
    tamano = models.CharField(max_length=100)
    estado = models.CharField(max_length=50)
    fechaCreacion = models.DateField(auto_now_add=True)
    etiquetas = models.CharField(max_length=200, blank=True)
    cuentaCloud_id = models.IntegerField(null=True, blank=True)
    proyecto_id = models.IntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.nombre} creado en {self.fechaCreacion}"

    class Meta:
        app_label = "recursoCloud"
