@echo off
setlocal
cd /d "%~dp0"

echo [1/5] Preparando ambiente virtual...
if not exist ".venv\Scripts\python.exe" py -3 -m venv .venv

echo [2/5] Instalando dependencias...
call .venv\Scripts\python.exe -m pip install --upgrade pip
if errorlevel 1 goto :error
call .venv\Scripts\python.exe -m pip install -r requirements-dev.txt
if errorlevel 1 goto :error

echo [3/5] Executando testes...
call .venv\Scripts\python.exe -m pytest -q
if errorlevel 1 goto :error

echo [4/5] Gerando executavel Windows...
call .venv\Scripts\python.exe -m PyInstaller --noconfirm --clean EcosDaMata.spec
if errorlevel 1 goto :error
copy /Y IDENTIFICACAO.txt dist\EcosDaMata\IDENTIFICACAO.txt >nul
copy /Y README.md dist\EcosDaMata\LEIA-ME.txt >nul

echo [5/5] Criando ZIP de entrega...
powershell -NoProfile -Command "if (Test-Path 'dist\EcosDaMata_Entrega_Windows.zip') { Remove-Item 'dist\EcosDaMata_Entrega_Windows.zip' }; Compress-Archive -Path 'dist\EcosDaMata\*' -DestinationPath 'dist\EcosDaMata_Entrega_Windows.zip'"
if errorlevel 1 goto :error

echo.
echo Build concluida: dist\EcosDaMata_Entrega_Windows.zip
exit /b 0

:error
echo.
echo A compilacao falhou. Revise a mensagem acima.
exit /b 1
