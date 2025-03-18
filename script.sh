#!/bin/sh
echo "### Starting the build process"

echo "### Checking for required tools"
if ! command -v git &> /dev/null; then
    echo "### Missing git tool, please install Git"
    exit 1
fi
if ! command -v mongorestore &> /dev/null; then
    echo "### Missing mongorestore tool, please install MongoDB Command Line Database Tools"
    exit 1
fi
if ! command -v mongosh &> /dev/null; then
    echo "### Missing mongosh tool, please install MongoDB Shell"
    exit 1
fi
if ! command -v docker &> /dev/null; then
    echo "### Missing docker tool, please install Docker"
    exit 1
fi
if ! command -v npm &> /dev/null; then
    echo "### Missing npm tool, please install Node.js"
    exit 1
fi
if ! command -v dotnet &> /dev/null; then
    echo "### Missing dotnet tool, please install .NET SDK"
    exit 1
fi
if ! dotnet dev-certs https --check; then
    echo "### Installing the HTTPS development certificate"
    dotnet dev-certs https --trust
    if [ $? -ne 0 ]; then
        echo "### Certificate installation failed, please install and trust the certificate manually"
    fi
fi

echo "### Checking for required assets"
if [ ! -d ./solution ]; then
    mkdir ./solution
fi
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
        rm -rf ./solution/${GIT_REPO_NAME}

        echo "### Cloning GrandNode repository"

        git clone --recurse-submodules ${GIT_REPO}/${GIT_REPO_NAME} ./solution/${GIT_REPO_NAME}
        if [ $? -ne 0 ]; then
            if [ -z ${GIT_WORKING_COMMIT+x} ]; then
                echo "### Clone failed and no working commit provided"
                exit 1
            fi
            echo "### Clone failed, cleaning up the workspace"
            rm -rf ./solution/${GIT_REPO_NAME}
            echo "### Cloning GrandNode repository with the last working commit"
            git clone ${GIT_REPO}/${GIT_REPO_NAME} ./solution/${GIT_REPO_NAME}
            echo "### Checking out to the target commit"
            cd ./solution/${GIT_REPO_NAME}
            git checkout ${GIT_WORKING_COMMIT}
            echo "### Initializing and updating submodules"
            git submodule init
            git submodule update
            cd ../..
        fi
        # if clone fails, exit
        if [ $? -ne 0 ]; then
            echo "### Clone failed"
            exit 1
        fi

        echo "### Building GrandNode"
        dotnet build ./solution/${GIT_REPO_NAME}/${GRANDNODE_PROJECT_PATH}

        # if build fails, handle the error
        if [ $? -ne 0 ]; then
            echo "### Build failed"
            if [ -n "${GIT_WORKING_COMMIT+x}" ]; then
            # Check if already on the working commit
            CURRENT_COMMIT=$(cd ./solution/${GIT_REPO_NAME} && git rev-parse HEAD)
            if [ "$CURRENT_COMMIT" = "${GIT_WORKING_COMMIT}" ]; then
                echo "### Already on the working commit (${GIT_WORKING_COMMIT}) and build still failed"
                exit 1
            else
                read -p "### Do you want to try with the last working commit (${GIT_WORKING_COMMIT})? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "### Checking out to the last working commit (${GIT_WORKING_COMMIT})"
                cd ./solution/${GIT_REPO_NAME}
                git checkout ${GIT_WORKING_COMMIT}
                cd ../..
                echo "### Rebuilding GrandNode with the last working commit"
                dotnet build ./solution/${GIT_REPO_NAME}/${GRANDNODE_PROJECT_PATH}
                if [ $? -ne 0 ]; then
                    echo "### Build failed again with the last working commit"
                    exit 1
                fi
                else
                exit 1
                fi
            fi
            else
            echo "### No working commit provided (GIT_WORKING_COMMIT not set)"
            exit 1
            fi
        fi

        echo "### Installing GrandNode dependencies"
        npm install --prefix ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}

        echo "### Copying configuration files"
        mv ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg.bak
        mv ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg.bak
        mv ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json.bak
        mv ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs.bak
        cp ./assets/data/InstalledPlugins.cfg ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/InstalledPlugins.cfg
        cp ./assets/data/Settings.cfg ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/Settings.cfg
        cp ./assets/data/appsettings.json ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/App_Data/appsettings.json
        cp ./assets/data/Program.cs ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/Program.cs

        # if images assets, copy them
        if [ -d ./assets/images/uploaded ]; then
            echo "### Copying image assets"
            cp -r ./assets/images/uploaded/* ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/wwwroot/assets/images/uploaded
            cp -r ./assets/images/thumbs/* ./solution/${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}/wwwroot/assets/images/thumbs
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

cd ..

echo "### Adding dev admin user and configuring email settings"
# Running the MongoDB operations using an external JS file
mongosh mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB} \
  --eval "const process = {env: {GN_USER_PASSWORD: '${GN_USER_PASSWORD}', GN_USER_USERNAME: '${GN_USER_USERNAME}', GN_USER_EMAIL: '${GN_USER_EMAIL}', GN_ADMIN_EMAIL: '${GN_ADMIN_EMAIL}', GN_ADMIN_PASSWORD: '${GN_ADMIN_PASSWORD}', GN_ADMIN_USERNAME: '${GN_ADMIN_USERNAME}',GN_STORES_NAMES: '${GN_STORES_NAMES}', GN_STORES_HOSTS: '${GN_STORES_HOSTS}', GN_STORES_PORTS: '${GN_STORES_PORTS}', GIT_REPO_NAME: '${GIT_REPO_NAME}', MAILDEV_SMTP_PORT: ${MAILDEV_SMTP_PORT}, MAILDEV_INCOMING_USER: '${MAILDEV_INCOMING_USER}', MAILDEV_INCOMING_PASS: '${MAILDEV_INCOMING_PASS}'}};" \
  --file=db_setup.js

echo "### Starting MailDev"
docker run -p ${MAILDEV_WEB_PORT}:1080 -p ${MAILDEV_SMTP_PORT}:1025 -d -e MAILDEV_INCOMING_USER=${MAILDEV_INCOMING_USER} -e MAILDEV_INCOMING_PASS=${MAILDEV_INCOMING_PASS} maildev/maildev


# echo "### Opening GrandNode solution"
# cd ./solution/${GIT_REPO_NAME} && open ${GRANDNODE_SOLUTION_PATH}

echo "### All done!"