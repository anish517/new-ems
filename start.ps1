# EMS Full Stack Startup Script
# Run from f:\emp\ems-full-stack\

Write-Host "Starting EMS Backend..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd 'f:\emp\ems-full-stack\backend'; .\venv\Scripts\activate; python manage.py runserver 8000"

Start-Sleep -Seconds 3

Write-Host "Backend running at http://127.0.0.1:8000/" -ForegroundColor Green
Write-Host ""
Write-Host "To run Flutter app, open a new terminal and run:" -ForegroundColor Yellow
Write-Host "  cd f:\emp\ems-full-stack\frontend" -ForegroundColor White
Write-Host "  flutter run -d chrome        (Web)" -ForegroundColor White
Write-Host "  flutter run -d android       (Android)" -ForegroundColor White
