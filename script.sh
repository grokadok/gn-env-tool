#!/bin/sh
echo "### Starting the build process"

echo "### Checking for required assets"
if [ ! -f .env ]; then
    echo "### Missing .env file, please create one, see .env.example"
    exit 1
fi
for arg in "$@"; do
    if [ "$arg" = "--mask" ]; then
        if [ ! -f ./masking_logic.js ]; then
            echo "### Missing ./masking_logic.js file"
            exit 1
        fi
    fi
done
if [ ! -d ./mongodb/dumps/${MONGO_DB} ] && [ ! -f ./mongodb/dumps/${MONGO_DB}.archive ]; then
    echo "### Missing MongoDB dump"
    exit 1
fi
if [ ! -f ./assets/data/InstalledPlugins.cfg ]; then
    echo "### Missing ./assets/data/InstalledPlugins.cfg configuration file"
    exit 1
fi
if [ ! -d ./assets/images/uploaded ]; then
    echo "### Missing image/uploaded assets"
    read -p "### Continue without image assets? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "### Loading environment variables"
export $(cat .env | sed 's/#.*//g' | xargs)

echo "### Creating configuration files"
cat > ./assets/data/Settings.cfg << EOF
{
  "ConnectionString": "mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}",
  "DbProvider": 0
}
EOF
cat > ./mongodb/.env << EOF
MONGO_INITDB_ROOT_USERNAME: root
MONGO_INITDB_ROOT_PASSWORD: password
MONGO_INITDB_DATABASE: ${MONGO_DB}
MONGO_DB: ${MONGO_DB}
MONGO_HOST: ${MONGO_HOST}
MONGO_PORT: ${MONGO_PORT}
MONGO_USER: ${MONGO_USER}
MONGO_PASSWORD: ${MONGO_PASSWORD}
EOF
cat > ./mongodb/mask/.env << EOF
MONGO_DB=${MONGO_DB}
MONGO_USER=${MONGO_USER}
MONGO_PASSWORD=${MONGO_PASSWORD}
EOF

echo "### Stoping and cleaning MongoDB"
cd ./mongodb && rm -f ./dumps/masked.archive && docker compose down && cd ./mask && docker compose down && cd ../..
# if maildev container is running, stop it
if [ $(docker ps -q --filter ancestor=maildev/maildev | wc -l) -gt 0 ]; then
    echo "### Stopping existing maildev container"
    docker stop $(docker ps -q --filter ancestor=maildev/maildev)
fi


for arg in "$@"; do
    if [ "$arg" = "--clone" ]; then
        echo "### Cleaning up the workspace"
        rm -rf ./${GIT_REPO_NAME}

        echo "### Cloning GrandNode repository"

        git clone --recurse-submodules ${GIT_REPO}/${GIT_REPO_NAME}
        if [ $? -ne 0 ]; then
            if [ -z ${GIT_WORKING_COMMIT+x} ]; then
                echo "### Clone failed and no working commit provided"
                exit 1
            fi
            echo "### Clone failed, cleaning up the workspace"
            rm -rf ./${GIT_REPO_NAME}
            echo "### Cloning GrandNode repository with the last working commit"
            git clone ${GIT_REPO}/${GIT_REPO_NAME}
            echo "### Checking out to the target commit"
            cd ./${GIT_REPO_NAME}
            git checkout ${GIT_WORKING_COMMIT}
            echo "### Initializing and updating submodules"
            git submodule init
            git submodule update
            cd ..
        fi
        # if clone fails, exit
        if [ $? -ne 0 ]; then
            echo "### Clone failed"
            exit 1
        fi

        echo "### Building GrandNode"
        dotnet build ./${GIT_REPO_NAME}/${GRANDNODE_PROJECT_PATH}

        # if build fails, exit
        if [ $? -ne 0 ]; then
            echo "### Build failed"
            exit 1
        fi

        echo "### Installing GrandNode dependencies"
        npm install --prefix ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}

        echo "### Copying configuration files"
        mv ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg.bak
        mv ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg.bak
        mv ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json.bak
        mv ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs.bak
        cp ./assets/data/InstalledPlugins.cfg ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg
        cp ./assets/data/Settings.cfg ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg
        cp ./assets/data/appsettings.json ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json
        cp ./assets/data/Program.cs ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs

        # if images assets, copy them
        if [ -d ./assets/images/uploaded ]; then
            echo "### Copying image assets"
            cp -r ./assets/images/uploaded/* ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/wwwroot/assets/images/uploaded
            cp -r ./assets/images/thumbs/* ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/wwwroot/assets/images/thumbs
        fi
    elif [ "$arg" = "--mask" ]; then
        echo "### Masking MongoDB data"
        rm -rf ./mongodb/data/*
        cd ./mongodb/mask && docker compose up && docker compose down && cd ../..
    fi
done

echo "### Starting MongoDB"
rm -rf ./mongodb/data/*
cd ./mongodb && docker compose up -d
until mongosh --host ${MONGO_HOST} --port ${MONGO_PORT} --eval 'quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)' > /dev/null 2>&1
do
  echo "### Waiting for mongod to be available..."
  sleep 2
done

if [ -f ./dumps/masked.archive ]; then
  echo "### Restoring masked MongoDB data"
  mongorestore mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB} --archive=./dumps/masked.archive
else
  echo "### Restoring MongoDB data"
  if [ -f ./dumps/${MONGO_DB}.archive ]; then
    mongorestore mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB} --archive=./dumps/${MONGO_DB}.archive
  else
    mongorestore mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB} ./dumps/${MONGO_DB}
  fi
fi

echo "### Adding dev admin user and configuring email settings"
mongosh mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}\
    --eval "
        function hashPassword(password, salt) {
            const crypto = require('crypto');
            const hash = crypto.createHash('sha256');
            hash.update(password + salt);
            return hash.digest('hex').toUpperCase();
        }

        const salt = 'salty123'; // You can use any string as salt
        const password = 'devadmin';
        const hashedPassword = hashPassword(password, salt);
        /********** Insert dev admin user **********/
        db.Customer.insertOne({
            _id: ObjectId().toString(),
            Active: true,
            Addresses: [],
            AdminComment: null,
            AffiliateId: null,
            Attributes: [],
            BillingAddress: null,
            CannotLoginUntilDateUtc: null,
            Coordinates: null,
            CreatedOnUtc: new Date(),
            CustomerGuid: UUID(),
            CustomerTags: [],
            Deleted: false,
            Email: 'devadmin@example.com',
            FailedLoginAttempts: 0,
            FreeShipping: false,
            Groups: [
                '63ebc5f02e4bfb93ca449822',
                '63ebc5f02e4bfb93ca449823',
                '64c8b2dea8021148097c9de8',
            ],
            HasContributions: false,
            IsSystemAccount: false,
            IsTaxExempt: false,
            LastActivityDateUtc: new Date(),
            LastIpAddress: null,
            LastLoginDateUtc: new Date(),
            LastPurchaseDateUtc: null,
            LastUpdateCartDateUtc: null,
            LastUpdateWishListDateUtc: null,
            OwnerId: '',
            Password: hashedPassword,
            PasswordChangeDateUtc: new Date(),
            PasswordFormatId: 1,
            PasswordSalt: salt,
            SeId: '6527b31be262fc12f168af58',
            ShippingAddress: null,
            ShoppingCartItems: [],
            StaffStoreId: null,
            StoreId: null,
            SystemName: null,
            UserFields: [
                {
                    Key: 'FirstName',
                    Value: 'devadmin',
                    StoreId: '',
                },
                {
                    Key: 'LastName',
                    Value: 'devadmin',
                    StoreId: '',
                },
                {
                    Key: 'Gender',
                    Value: null,
                    StoreId: '',
                },
                {
                    Key: 'Phone',
                    Value: null,
                    StoreId: '',
                },
                {
                    Key: 'Fax',
                    Value: null,
                    StoreId: '',
                },
                {
                    Key: 'PasswordToken',
                    Value: null,
                    StoreId: '',
                },
            ],
            Username: 'devadmin',
            VendorId: null,
        });
        /********** Insert dev email account and set it as default **********/
        const emailAccountId = ObjectId().toString();
        db.EmailAccount.insertOne({
            '_id': emailAccountId,
            'DisplayName': 'Email test account', 
            'Email': 'noreply@test.dev', 
            'Host': 'localhost', 
            'Port': 1025, 
            'Username': 'dev', 
            'Password': 'dev', 
            'UseServerCertificateValidation': false, 
            'SecureSocketOptionsId': 0, 
            'UserFields': []
        });
        db.Setting.updateOne(
            { 'Name': 'emailaccountsettings' }, 
            { \$set: { 'Metadata': '{\"DefaultEmailAccountId\":\"' + emailAccountId + '\"}' } }
        );
    "

echo "### Starting MailDev"
docker run -p 1080:1080 -p 1025:1025 -d -e MAILDEV_INCOMING_USER=dev -e MAILDEV_INCOMING_PASS=dev maildev/maildev


# echo "### Opening GrandNode solution"
# cd ../${GIT_REPO_NAME} && open ${GRANDNODE_SOLUTION_PATH}

echo "### All done!"