from django.contrib.auth import get_user_model
User = get_user_model()
from organization.models import Employee

# clean up
User.objects.filter(username='testx').delete()

user=User.objects.create(username='testx', email='testx@test.com')
emp=Employee.objects.create(user=user, gender='male', father_name='X', phone_no='1', official_email='x', personal_email='x')

print('Before delete:', User.objects.filter(id=user.id).exists())
emp.delete()
print('After emp.delete(): user exists?', User.objects.filter(id=user.id).exists())

user.delete()
print('After user.delete(): user exists?', User.objects.filter(id=user.id).exists())
