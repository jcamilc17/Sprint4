from django.db import models


class Reporte(models.Model):
    titulo = models.CharField(max_length=100)
    tipo = models.CharField(max_length=100)
    fechaGeneracion = models.DateField(auto_now_add=True)
    periodoInicio = models.DateField()
    periodoFin = models.DateField()
    formato = models.CharField(max_length=50)
    usuario_id = models.IntegerField(null=True, blank=True)
    empresa_id = models.IntegerField(null=True, blank=True)
    proyecto_id = models.IntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.titulo} ({self.periodoInicio} -> {self.periodoFin})"

    class Meta:
        app_label = "reporte"


class ConsumoCloud(models.Model):
    empresa_id = models.IntegerField(db_index=True)
    empresa_nombre = models.CharField(max_length=100)
    proveedor = models.CharField(max_length=20)
    servicio = models.CharField(max_length=100)
    costo = models.DecimalField(max_digits=12, decimal_places=4)
    mes = models.IntegerField()
    anio = models.IntegerField()
    region = models.CharField(max_length=50, null=True, blank=True)

    class Meta:
        app_label = "reporte"
        indexes = [
            models.Index(fields=["empresa_id", "anio", "mes"], name="idx_consumo_lookup"),
        ]

    def __str__(self):
        return f"{self.empresa_nombre} {self.proveedor} {self.mes}/{self.anio}: {self.costo}"
