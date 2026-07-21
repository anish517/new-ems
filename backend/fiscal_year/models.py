from django.db import models

from organization.models import Organization

# Create your models here.
class FiscalYear(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, null=True, blank=True)
    title = models.CharField(default='', verbose_name='Fiscal year', max_length=255)

    def __str__(self) -> str:
        return f'{self.title}'
    
    class Meta:
        verbose_name = 'Fiscal year'
        ordering = ['-id']
    