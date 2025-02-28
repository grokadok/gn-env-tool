:: GrandNode setup script for Windows environments
@echo off
setlocal enabledelayedexpansion

echo ### Starting the build process

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
cd .\mongodb && if exist .\dumps\masked.archive del /F .\dumps\masked.archive
docker compose down
cd .\mask && docker compose down && cd ..\..

:: Check if maildev container is running and stop it
for /f %%i in ('docker ps -q --filter ancestor^=maildev/maildev') do (
    if not "%%i"=="" (
        echo ### Stopping existing maildev container
        docker stop %%i
    )
)

for %%a in (%*) do (
    if "%%a"=="--clone" (
        echo ### Cleaning up the workspace
        if exist .\%GIT_REPO_NAME% rmdir /S /Q .\%GIT_REPO_NAME%

        echo ### Cloning GrandNode repository

        if not defined GIT_WORKING_COMMIT (
            echo ### Clone failed and no working commit provided
            exit /b 1
        )
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

        echo ### Building GrandNode
        dotnet build .\%GIT_REPO_NAME%\%GRANDNODE_PROJECT_PATH%
        if %ERRORLEVEL% neq 0 (
            echo ### Build failed
            exit /b 1
        )

        echo ### Installing GrandNode dependencies
        call npm install --prefix .\%GIT_REPO_NAME%\%GRANDNODE_WEB_PATH%

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
        cd .\mongodb\mask && docker compose up && docker compose down && cd ..\..
    )
)

echo ### Starting MongoDB
if exist .\mongodb\data rmdir /S /Q .\mongodb\data
cd .\mongodb && docker compose up -d
cd ..

:: Wait for MongoDB to be available
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
:: Create a temporary JavaScript file for MongoDB operations
(
    echo function hashPassword(password, salt) {
    echo     const crypto = require('crypto'^);
    echo     const hash = crypto.createHash('sha256'^);
    echo     hash.update(password + salt^);
    echo     return hash.digest('hex'^).toUpperCase(^);
    echo }
    echo.
    echo const salt = 'salty123';
    echo const password = '%GN_ADMIN_PASSWORD%';
    echo const hashedPassword = hashPassword(password, salt^);
    echo.
    echo db.Customer.insertOne({
    echo     _id: ObjectId(^).toString(^),
    echo     Active: true,
    echo     Addresses: [],
    echo     AdminComment: null,
    echo     AffiliateId: null,
    echo     Attributes: [],
    echo     BillingAddress: null,
    echo     CannotLoginUntilDateUtc: null,
    echo     Coordinates: null,
    echo     CreatedOnUtc: new Date(^),
    echo     CustomerGuid: UUID(^),
    echo     CustomerTags: [],
    echo     Deleted: false,
    echo     Email: 'devadmin@example.com',
    echo     FailedLoginAttempts: 0,
    echo     FreeShipping: false,
    echo     Groups: [
    echo         '63ebc5f02e4bfb93ca449822',
    echo         '63ebc5f02e4bfb93ca449823',
    echo         '64c8b2dea8021148097c9de8',
    echo     ],
    echo     HasContributions: false,
    echo     IsSystemAccount: false,
    echo     IsTaxExempt: false,
    echo     LastActivityDateUtc: new Date(^),
    echo     LastIpAddress: null,
    echo     LastLoginDateUtc: new Date(^),
    echo     LastPurchaseDateUtc: null,
    echo     LastUpdateCartDateUtc: null,
    echo     LastUpdateWishListDateUtc: null,
    echo     OwnerId: '',
    echo     Password: hashedPassword,
    echo     PasswordChangeDateUtc: new Date(^),
    echo     PasswordFormatId: 1,
    echo     PasswordSalt: salt,
    echo     SeId: '6527b31be262fc12f168af58',
    echo     ShippingAddress: null,
    echo     ShoppingCartItems: [],
    echo     StaffStoreId: null,
    echo     StoreId: null,
    echo     SystemName: null,
    echo     UserFields: [
    echo         { Key: 'FirstName', Value: 'devadmin', StoreId: '' },
    echo         { Key: 'LastName', Value: 'devadmin', StoreId: '' },
    echo         { Key: 'Gender', Value: null, StoreId: '' },
    echo         { Key: 'Phone', Value: null, StoreId: '' },
    echo         { Key: 'Fax', Value: null, StoreId: '' },
    echo         { Key: 'PasswordToken', Value: null, StoreId: '' },
    echo     ],
    echo     Username: '%GN_ADMIN_USER%',
    echo     VendorId: null,
    echo }^);
    echo.
    echo const emailAccountId = ObjectId(^).toString(^);
    echo db.EmailAccount.insertOne({
    echo     '_id': emailAccountId,
    echo     'DisplayName': '%GIT_REPO_NAME% mailer',
    echo     'Email': 'noreply@test.dev',
    echo     'Host': 'localhost',
    echo     'Port': %MAILDEV_SMTP_PORT%,
    echo     'Username': '%MAILDEV_INCOMING_USER%',
    echo     'Password': '%MAILDEV_INCOMING_PASS%',
    echo     'UseServerCertificateValidation': false,
    echo     'SecureSocketOptionsId': 0,
    echo     'UserFields': []
    echo }^);
    echo.
    echo db.Setting.updateOne(
    echo     { 'Name': 'emailaccountsettings' },
    echo     { $set: { 'Metadata': '{\"DefaultEmailAccountId\":\"' + emailAccountId + '\"}' } }
    echo ^);
) > temp_mongo_script.js

mongosh mongodb://%MONGO_USER%:%MONGO_PASSWORD%@%MONGO_HOST%:%MONGO_PORT%/%MONGO_DB% --file=temp_mongo_script.js
del temp_mongo_script.js

echo ### Starting MailDev
docker run -p %MAILDEV_WEB_PORT%:1080 -p %MAILDEV_SMTP_PORT%:1025 -d -e MAILDEV_INCOMING_USER=%MAILDEV_INCOMING_USER% -e MAILDEV_INCOMING_PASS=%MAILDEV_INCOMING_PASS% maildev/maildev

echo ### All done!
endlocal