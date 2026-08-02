from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee

class AuthenticationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        # Create a basic user
        self.user = Account.objects.create(email="test@user.com", first_name="Test", last_name="User")
        self.user.set_password("password123")
        self.user.save()
        
        # We need an employee profile to access protected routes correctly in some cases,
        # but for a basic 401 test, just having the route is enough.
        
    def test_login_generates_jwt(self):
        """
        Test that posting valid credentials to the token endpoint returns JWT access and refresh tokens.
        """
        response = self.client.post('/api/auth/token/', {
            'email': 'test@user.com',
            'password': 'password123'
        }, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        
    def test_invalid_login(self):
        """
        Test that invalid credentials get rejected.
        """
        response = self.client.post('/api/auth/token/', {
            'email': 'test@user.com',
            'password': 'wrongpassword'
        }, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        
    def test_protected_route_without_token(self):
        """
        Test that an unauthenticated user receives a 401 Unauthorized
        when attempting to access a protected API route.
        """
        response = self.client.get('/api/organization/employees/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
