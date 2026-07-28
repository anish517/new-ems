import re

path = r"f:\emp\ems-full-stack\backend\organization\api\views.py"

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

classes_to_update = [
    "DepartmentRetrieveUpdateDeleteAPIView",
    "EmployeeViewSet",
    "EmployeeAddressCreateView",
    "EmployeeAddressDetailView",
    "NationalIdViewSet",
    "QualificationViewSet",
    "BankDetailViewSet",
    "DocumentViewSet",
    "EmployeeAnalysisReportListAPIView",
    "OrganizationFileRetrieveAPIView"
]

for cls in classes_to_update:
    # Find the class definition and the next line
    pattern = r"(class " + cls + r"\(.*?\):\n(\s+))(.*?)\n"
    # We want to insert nepali_date_filter_field = False
    replacement = r"\1nepali_date_filter_field = False\n\2\3\n"
    content = re.sub(pattern, replacement, content, count=1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated views.py")
