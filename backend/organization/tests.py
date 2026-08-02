from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee

class OrganizationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        
        # Admin user to get token
        self.admin_user = Account.objects.create(email="admin@user.com", first_name="Admin", last_name="User")
        self.admin_user.set_password("password123")
        self.admin_user.save()
        
        # Hierarchy
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")
        
        # Get JWT Token
        response = self.client.post('/api/auth/token/', {
            'email': 'admin@user.com',
            'password': 'password123'
        }, format='json')
        self.token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token)

    def test_employee_creation_and_marital_status(self):
        """
        Test that creating an employee via the API correctly saves 
        all fields including marital_status and employee_type.
        """
        payload = {
            "user": {
                "first_name": "API",
                "last_name": "User",
                "email": "api.user@test.com",
                "password": "Password123!"
            },
            "post": self.post.id,
            "gender": "male",
            "marital_status": "single",
            "date_of_birth": "2050-01-01",
            "phone_no": "9800000000",
            "employee_type": "full_time",
            "official_email": "official@test.com",
            "personal_email": "personal@test.com",
            "father_name": "Father API"
        }
        
        response = self.client.post('/api/organization/employees/', payload, format='json')
        if response.status_code != status.HTTP_201_CREATED:
            print(f"CREATE ERROR: {response.data}")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # Verify in DB
        emp = Employee.objects.get(user__email="api.user@test.com")
        self.assertEqual(emp.marital_status, "single")
        self.assertEqual(emp.employee_type, "full_time")
        self.assertEqual(emp.user.first_name, "API")

    def test_employee_edit_marital_status_and_type(self):
        """
        Test that editing an employee correctly updates marital_status and employee_type.
        (This ensures the frontend bug we fixed is also sound on the backend).
        """
        # First create
        user = Account.objects.create(email="edit.user@test.com", first_name="Edit", last_name="User")
        emp = Employee.objects.create(
            user=user, post=self.post, marital_status="single", employee_type="part_time", date_of_birth="2050-01-01",
            phone_no="123", official_email="o@o.com", personal_email="p@p.com", father_name="father"
        )
        
        payload = {
            "user": {
                "first_name": "Edit",
                "last_name": "User",
                "email": "edit.user@test.com",
            },
            "post": self.post.id,
            "marital_status": "married",
            "employee_type": "full_time",
            "date_of_birth": "2050-01-01",
        }
        
        response = self.client.patch(f'/api/organization/employees/{emp.id}/', payload, format='json')
        if response.status_code != status.HTTP_200_OK:
            print(f"PATCH ERROR: {response.data}")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify changes in DB
        emp.refresh_from_db()
        self.assertEqual(emp.marital_status, "married")
        self.assertEqual(emp.employee_type, "full_time")
