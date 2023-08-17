:: Copyright 2022 Google LLC
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.

:: Update all WebDrivers.  Runs after package installation, on service startup,
:: and again nightly.

:: Dont print every command.
@echo off

:: Change to the script folder.
cd /D "%~dp0"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Copy package.json to the working directory in ProgramData.
copy package.json "C:\ProgramData\shaka-lab-node\"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Go to the working directory.
cd /D "C:\ProgramData\shaka-lab-node"
if %errorlevel% neq 0 exit /b %errorlevel%

:: Update all modules to the latest version allowed by package.json.
call npm update
if %errorlevel% neq 0 exit /b %errorlevel%

:: Update all drivers.
call node_modules/.bin/webdriver-installer.cmd .
if %errorlevel% neq 0 exit /b %errorlevel%
