from django.db import models
from django.contrib.auth import get_user_model
from django.utils.text import slugify
from nepali_datetime_field.models import NepaliDateField
from utils.models import SoftDeleteModel

User = get_user_model()

# Create your models here.


class OrganizationType(models.Model):
    name = models.CharField(max_length=255)
    slug = models.SlugField(null=True, blank=True)

    def __str__(self) -> str:
        return f"{self.name}"

    def save(self, *args, **kwargs):
        if not self.id:
            super(OrganizationType, self).save(*args, **kwargs)
            self.slug = slugify(f"{self.name}-{self.id}")
            kwargs["force_insert"] = False
            super(OrganizationType, self).save(*args, **kwargs)
        else:
            if not self.slug:
                self.slug = slugify(f"{self.name}-{self.id}")
            super(OrganizationType, self).save(*args, **kwargs)


class Organization(models.Model):
    name = models.CharField(max_length=255, verbose_name="Organization name")
    website = models.URLField(
        max_length=255, verbose_name="Organization website", null=True, blank=True
    )
    type_of_organization = models.ForeignKey(
        OrganizationType, on_delete=models.SET_NULL, null=True, blank=True
    )
    contact_person = models.CharField(max_length=255, null=True, blank=True)
    contact_number = models.CharField(max_length=255, null=True, blank=True)
    admin_users = models.ManyToManyField(User, related_name="organization")
    opening_time = models.TimeField(null=True, blank=True)
    closing_time = models.TimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True)

    def __str__(self):
        return f"{self.name}"

    @property
    def primary_address(self):
        return self.address.filter(primary=True)[0]

    @property
    def addresses(self):
        return self.address.all()

    @property
    def departments(self):
        return self.department.all()

    @property
    def employees(self):
        return Employee.objects.filter(post__department__organization=self).distinct()

    @property
    def posts(self):
        return Post.objects.filter(department__organization=self).distinct()


class OrganizationAddress(models.Model):
    STATE_CHOICES = [
        ("province_1", "Province No. 1"),
        ("province_2", "Province No. 2 (Madhesh Province)"),
        ("bagmati", "Bagmati Province"),
        ("gandaki", "Gandaki Province"),
        ("lumbini", "Lumbini Province"),
        ("karnali", "Karnali Province"),
        ("sudurpaschim", "Sudurpashchim Province"),
    ]
    address_line_1 = models.CharField(max_length=255)
    address_line_2 = models.CharField(max_length=255)
    city = models.CharField(max_length=255, null=True, blank=True)
    state = models.CharField(max_length=255, choices=STATE_CHOICES)
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="address"
    )
    primary = models.BooleanField(default=False)
    latitude = models.FloatField(default=0)
    longitude = models.FloatField(default=0)

    def __str__(self) -> str:
        return f"{self.organization.name}, {self.city}, {self.state}"


class Department(models.Model):
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="department",
        null=True,
        blank=True,
    )
    department_name = models.CharField(max_length=255)
    department_slug = models.SlugField(unique=True, null=True, blank=True)
    parent_department = models.ForeignKey(
        "self", on_delete=models.SET_NULL, null=True, blank=True
    )

    def __str__(self):
        return self.department_name

    class Meta:
        unique_together = ("department_name", "organization")

    def save(self, *args, **kwargs):
        if not self.id:
            super(Department, self).save(*args, **kwargs)
            self.department_slug = slugify(f"{self.department_name}-{self.id}")
            kwargs["force_insert"] = False
            super(Department, self).save(*args, **kwargs)
        else:
            if not self.department_slug:
                self.department_slug = slugify(
                    f"{self.department_name}-{self.id}")
            super(Department, self).save(*args, **kwargs)

    @property
    def employees(self):
        return Employee.objects.filter(post__in=self.posts.all())

    @property
    def posts(self):
        return self.posts.all()


class Post(models.Model):
    department = models.ForeignKey(
        Department, on_delete=models.CASCADE, related_name="posts"
    )
    title = models.CharField(max_length=100)

    def __str__(self) -> str:
        return f"{self.title}"

    @property
    def employees(self):
        return Employee.objects.filter(post=self)

    @property
    def organization(self) -> Organization:
        return self.department.organization


class Employee(SoftDeleteModel):
    GENDER_CHOICES = (
        ("male", "Male"),
        ("female", "Female"),
        ("others", "Others"),
    )

    EMPLOYEE_TYPES = (
        ("full_time", "Full time"),
        ("part_time", "Part time"),
        ("intern", "Intern"),
    )

    id_prefix = models.CharField(
        default="EMP", max_length=255, null=True, blank=True)
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    post = models.ForeignKey(
        "Post",
        on_delete=models.SET_NULL,
        related_name="employees",
        verbose_name="Designation",
        null=True,
        blank=False,
    )

    gender = models.CharField(
        max_length=10, choices=GENDER_CHOICES, blank=False, null=False
    )

    date_of_birth = NepaliDateField(null=True, blank=False)

    father_name = models.CharField(
        max_length=255, null=False, blank=False, verbose_name="Father's name"
    )
    blood_group = models.CharField(max_length=5, null=True, blank=True)
    alternative_contact_number = models.CharField(max_length=255, null=True, blank=True)
    phone_no = models.CharField(max_length=255, null=False, blank=False)
    official_email = models.EmailField(max_length=255, null=False, blank=False)
    personal_email = models.EmailField(max_length=255, null=False, blank=False)
    is_active = models.BooleanField(default=True, blank=False)
    employee_type = models.CharField(
        max_length=255, null=True, choices=EMPLOYEE_TYPES, default="full_time"
    )

    class Meta:
        ordering = ["user__first_name", "user__last_name"]
        verbose_name = "Employee"
        verbose_name_plural = "Employees"

    def __str__(self):
        return f"{self.user.full_name}"

    def delete(self, *args, **kwargs):
        super().delete(*args, **kwargs)
        if self.user:
            self.user.is_active = False
            self.user.save()

    @property
    def get_id(self):
        return f'{self.id_prefix or "EMP"}_{self.id}'

    @property
    def organization(self):
        return (
            self.post.department.organization
            if self.post and self.post.department
            else None
        )

    @property
    def department(self):
        return self.post.department if self.post else None

    def is_company_admin(self):
        return (
            self.user in self.organization.admin_users.all()
            if self.organization
            else False
        )


class Address(models.Model):
    ADDRESS_TYPE = (
        ("permanent", "Permanent"),
        ("temporary", "Temporary"),
    )
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, related_name="address"
    )
    state = models.CharField(max_length=255, null=True)
    district = models.CharField(max_length=255, null=True)
    street = models.CharField(max_length=255, null=True)
    type = models.CharField(max_length=255, null=True)

    def __str__(self):
        return self.employee.user.full_name


class NationalIdDetail(models.Model):
    employee = models.OneToOneField(
        Employee, on_delete=models.CASCADE, null=True, related_name='national_id')
    national_id_no = models.CharField(max_length=255, null=True, blank=True)
    citizenship_no = models.CharField(max_length=255, null=True, blank=True)
    martial_status = models.CharField(max_length=255, null=True)

    def __str__(self):
        return self.employee.user.full_name


class Qualification(models.Model):
    employee = models.ForeignKey(
        Employee,
        on_delete=models.CASCADE,
        related_name="qualification",
        null=True,
        blank=False,
    )
    college = models.CharField(max_length=255, null=True, blank=False)
    degree = models.CharField(max_length=255, null=True, blank=False)
    field_of_study = models.CharField(max_length=255, null=True, blank=False)
    start_date = models.DateField(null=True, blank=False)
    end_date = models.DateField(null=True, blank=False)

    def __str__(self):
        return self.employee.user.full_name


class BankDetail(models.Model):
    employee = models.ForeignKey(Employee, on_delete=models.CASCADE, null=True)
    bank_name = models.CharField(max_length=255, null=True, blank=True)
    account_number = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return self.employee.user.full_name


class Document(models.Model):
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, related_name="documents"
    )
    name = models.CharField(max_length=255, null=True, blank=True)
    file = models.FileField(upload_to="employee/", null=True, blank=True)

    def __str__(self):
        return self.employee.user.full_name


class EmployeeDocument(models.Model):
    employee = models.OneToOneField(
        Employee,
        on_delete=models.CASCADE,
        related_name="employee_document",
        null=True,
        blank=True,
    )
    citizenship = models.FileField(
        upload_to="employee/", blank=True, null=True)
    pan_card = models.FileField(upload_to="employee/", blank=True, null=True)
    cv = models.FileField(upload_to="employee/", blank=True, null=True)
    cover_letter = models.FileField(
        upload_to="employee/", blank=True, null=True)
    contract = models.FileField(upload_to="employee/", blank=True, null=True)

    def __str__(self):
        return f"{self.employee}"

    @property
    def academic_documents(self):
        return self.academic_documents.all()

    def delete(self, *args, **kwargs):
        self.citizenship.delete(save=False)
        self.pan_card.delete(save=False)
        self.cv.delete(save=False)
        self.cover_letter.delete(save=False)
        self.contract.delete(save=False)
        super().delete(*args, **kwargs)

    def save(self, *args, **kwargs):
        if self.pk:
            old_instance = EmployeeDocument.objects.get(pk=self.pk)
            if self.citizenship and old_instance.citizenship != self.citizenship:
                old_instance.citizenship.delete(save=False)
            if self.pan_card and old_instance.pan_card != self.pan_card:
                old_instance.pan_card.delete(save=False)
            if self.cv and old_instance.cv != self.cv:
                old_instance.cv.delete(save=False)
            if self.cover_letter and old_instance.cover_letter != self.cover_letter:
                old_instance.cover_letter.delete(save=False)
            if self.contract and old_instance.contract != self.contract:
                old_instance.contract.delete(save=False)
        super().save(*args, **kwargs)


class OtherDocument(models.Model):
    employee_document = models.ForeignKey(
        EmployeeDocument, on_delete=models.CASCADE, related_name="other_files"
    )
    name = models.CharField(max_length=255, null=True, blank=True)
    file = models.FileField(upload_to="employee/", blank=True, null=True)

    def __str__(self):
        return f"{self.name}"

    def delete(self, *args, **kwargs):
        self.file.delete(save=False)
        super().delete(*args, **kwargs)

    def save(self, *args, **kwargs):
        if self.pk:
            old_instance = OtherDocument.objects.get(pk=self.pk)
            old_instance.file.delete()
        super().save(*args, **kwargs)


class EmployeeAnalysisReport(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE)
    employee = models.ForeignKey(Employee, on_delete=models.CASCADE)
    date = NepaliDateField(null=True, blank=True)
    task_score = models.FloatField(default=0)
    attendance_score = models.FloatField(default=0)

    def __str__(self):
        return f"{self.employee.user.full_name}"

    @property
    def analysis_score(self):
        total_score = (self.task_score + self.attendance_score) / 2
        return round(total_score, 2)

    @property
    def feedbacks(self):
        return EmployeeAnalysisReportFeedback.objects.filter(report=self)


class EmployeeAnalysisReportFeedback(models.Model):
    report = models.ForeignKey(
        EmployeeAnalysisReport, on_delete=models.CASCADE, null=True, blank=True
    )
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, blank=True
    )
    content = models.CharField(max_length=500)


class OrganizationFolder(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="folders", null=True
    )
    title = models.CharField(max_length=255)
    parent = models.ForeignKey("self", on_delete=models.CASCADE, null=True)

    def __str__(self) -> str:
        return self.title


def file_upload_path(instance, filename):
    """
    Custom upload path function based on the organization and folder.
    """
    if instance.folder:
        return f"files/{instance.organization.name}/{instance.folder.title}/{filename}"
    else:
        return f"files/{instance.organization.name}/{filename}"


class OrganizationFile(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, related_name="files"
    )
    folder = models.ForeignKey(
        OrganizationFolder, on_delete=models.CASCADE, null=True, related_name="files"
    )
    title = models.CharField(max_length=255)
    description = models.TextField(max_length=500, null=True, blank=True)
    file = models.FileField(upload_to=file_upload_path)

    def __str__(self):
        return self.title
