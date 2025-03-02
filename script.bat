:: GrandNode setup script for Windows environments
@echo off
setlocal enabledelayedexpansion

echo ### Starting the build process

echo ### Checking for required tools
where mongorestore >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ### Missing mongodb tool, please install MongoDB Command Line Database Tools
    exit /b 1
)
where mongosh >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ### Missing mongosh tool, please install MongoDB Shell
    exit /b 1
)
where docker >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ### Missing docker tool, please install Docker
    exit /b 1
)
where npm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ### Missing npm tool, please install Node.js
    exit /b 1
)

echo ### Checking for required assets
if not exist .env (
    echo ### Missing .env file, please create one, see .env.example
    exit /b 1
)

set MASK_FLAG=0
for %%a in (%*) do (
    if "%%a"=="--mask" (
        if not exist .\masking_logic.js (
            echo ### Missing .\masking_logic.js file
            exit /b 1
        )
        set MASK_FLAG=1
    )
)

:: Load env variables
for /f "tokens=*" %%a in (.env) do (
    set line=%%a
    if not "!line:~0,1!"=="#" (
        set %%a
    )
)

if not exist .\mongodb\dumps\%MONGO_DB% if not exist .\mongodb\dumps\%MONGO_DB%.archive (
    echo ### Missing MongoDB dump
    exit /b 1
)
if not exist .\assets\data\InstalledPlugins.cfg (
    echo ### Missing .\assets\data\InstalledPlugins.cfg configuration file
    exit /b 1
)
if not exist .\assets\images\uploaded (
    echo ### Missing image/uploaded assets
    set /p REPLY="### Continue without image assets? (y/n) "
    if /i not "!REPLY!"=="y" (
        exit /b 1
    )
)

echo ### Creating configuration files
(
    echo {
    echo   "ConnectionString": "mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB%",
    echo   "DbProvider": 0
    echo }
) > .\assets\data\Settings.cfg

(
    echo MONGO_INITDB_ROOT_USERNAME: root
    echo MONGO_INITDB_ROOT_PASSWORD: password
    echo MONGO_INITDB_DATABASE: %MONGO_DB%
    echo MONGO_DB: %MONGO_DB%
    echo MONGO_HOST: %MONGO_HOST%
    echo MONGO_PORT: %MONGO_PORT%
    echo MONGO_USER: %MONGO_USER%
    echo MONGO_PASSWORD: %MONGO_PASSWORD%
) > .\mongodb\.env

(
    echo MONGO_DB=%MONGO_DB%
    echo MONGO_USER=%MONGO_USER%
    echo MONGO_PASSWORD=%MONGO_PASSWORD%
) > .\mongodb\mask\.env

echo ### Stopping and cleaning MongoDB
cd .\mongodb
if exist .\dumps\masked.archive del /F .\dumps\masked.archive
docker compose down
cd .\mask
docker compose down
cd ..\..

for /f %%i in ('docker ps -q --filter ancestor^=maildev/maildev') do (
    if not "%%i"=="" (
        echo ### Stopping existing maildev container
        docker stop %%i
    )
)

echo ### Parsing the command line arguments
for %%a in (%*) do (
    if "%%a"=="--clone" (
        echo ### Cleaning up the workspace
        if exist .\%GIT_REPO_NAME% rmdir /S /Q .\%GIT_REPO_NAME%

        echo ### Cloning GrandNode repository

        git clone --recurse-submodules %GIT_REPO%/%GIT_REPO_NAME%
        if %ERRORLEVEL% neq 0 (
            if not defined GIT_WORKING_COMMIT (
                echo ### Clone failed and no working commit provided
                exit /b 1
            )
            echo ### Clone failed, cleaning up the workspace
            rmdir /S /Q .\%GIT_REPO_NAME%
            echo ### Cloning GrandNode repository with the last working commit
            git clone %GIT_REPO%/%GIT_REPO_NAME%
            if %ERRORLEVEL% neq 0 (
                echo ### Clone failed
                exit /b 1
            )
            echo ### Checking out to the target commit
            cd .\%GIT_REPO_NAME%
            git checkout %GIT_WORKING_COMMIT%
            echo ### Initializing and updating submodules
            git submodule init
            git submodule update
            cd ..
        )

        echo ### Building GrandNode
        
        dotnet build .\%GIT_REPO_NAME%\%GRANDNODE_PROJECT_PATH% || (
            if defined GIT_WORKING_COMMIT (
                set /p RETRY_WITH_COMMIT="### Build failed. Do you want to retry with the working commit %GIT_WORKING_COMMIT%? (y/n) "
                if /i "!RETRY_WITH_COMMIT!"=="y" (
                    rmdir /S /Q .\%GIT_REPO_NAME%
                    echo ### Cloning GrandNode repository with the last working commit
                    git clone %GIT_REPO%/%GIT_REPO_NAME%
                    if %ERRORLEVEL% neq 0 (
                        echo ### Clone failed
                        exit /b 1
                    )
                    echo ### Checking out to the working commit
                    cd .\%GIT_REPO_NAME%
                    git checkout %GIT_WORKING_COMMIT%
                    echo ### Initializing and updating submodules
                    git submodule init
                    git submodule update
                    
                    cd ..
                    echo ### Building GrandNode with working commit
                    dotnet build .\%GIT_REPO_NAME%\%GRANDNODE_PROJECT_PATH% || (
                        echo ### Build failed even with working commit
                        exit /b 1
                    )
                ) else (
                    echo ### Build failed
                    exit /b 1
                )
            ) else (
                echo ### Build failed
                exit /b 1
            )
        )

        echo ### Installing GrandNode dependencies
        pushd .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%
        call npm install
        popd

        echo ### Copying configuration files
        move .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\InstalledPlugins.cfg .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\InstalledPlugins.cfg.bak
        move .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\Settings.cfg .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\Settings.cfg.bak
        move .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\appsettings.json .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\appsettings.json.bak
        move .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\Program.cs .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\Program.cs.bak
        copy .\assets\data\InstalledPlugins.cfg .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\InstalledPlugins.cfg
        copy .\assets\data\Settings.cfg .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\Settings.cfg
        copy .\assets\data\appsettings.json .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\App_Data\appsettings.json
        copy .\assets\data\Program.cs .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\Program.cs

        :: Copy image assets if they exist
        if exist .\assets\images\uploaded (
            echo ### Copying image assets
            xcopy /E /Y .\assets\images\uploaded\* .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\wwwroot\assets\images\uploaded\
            xcopy /E /Y .\assets\images\thumbs\* .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%\wwwroot\assets\images\thumbs\
        )
    ) else if "%%a"=="--mask" (
        echo ### Masking MongoDB data
        if exist .\mongodb\data rmdir /S /Q .\mongodb\data
        cd .\mongodb\mask && docker compose up && docker compose down
        cd ..\..
    )
)

echo ### Starting MongoDB
if exist .\mongodb\data rmdir /S /Q .\mongodb\data
cd .\mongodb && docker compose up -d
cd ..

:mongo_wait_loop
echo ### Waiting for mongod to be available...
timeout /t 2 > nul
mongosh --host %MONGO_HOST% --port %MONGO_PORT% --eval "quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)" > nul 2>&1
if %ERRORLEVEL% neq 0 goto mongo_wait_loop

if exist .\mongodb\dumps\masked.archive (
    echo ### Restoring masked MongoDB data
    mongorestore mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB% --archive=.\mongodb\dumps\masked.archive
) else (
    echo ### Restoring MongoDB data
    if exist .\mongodb\dumps\%MONGO_DB%.archive (
        mongorestore mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB% --archive=.\mongodb\dumps\%MONGO_DB%.archive
    ) else (
        mongorestore mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB% .\mongodb\dumps\%MONGO_DB%
    )
)

echo ### Adding dev admin user and configuring email settings
mongosh mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB% --eval "const process = {env: {GN_ADMIN_PASSWORD: '%GN_ADMIN_PASSWORD%', GN_ADMIN_USER: '%GN_ADMIN_USER%', GIT_REPO_NAME: '%GIT_REPO_NAME%', MAILDEV_SMTP_PORT: '%MAILDEV_SMTP_PORT%', MAILDEV_INCOMING_USER: '%MAILDEV_INCOMING_USER%', MAILDEV_INCOMING_PASS: '%MAILDEV_INCOMING_PASS%'}};" --file=db_setup.js


echo ### Starting MailDev
docker run -p %MAILDEV_WEB_PORT%:1080 -p %MAILDEV_SMTP_PORT%:1025 -d -e MAILDEV_INCOMING_USER=%MAILDEV_INCOMING_USER% -e MAILDEV_INCOMING_PASS=%MAILDEV_INCOMING_PASS% maildev/maildev

echo ### All done!
endlocal