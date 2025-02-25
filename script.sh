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


for arg in "$@"; do
    if [ "$arg" = "--clone" ]; then
        echo "### Cleaning up the workspace"
        rm -rf ./${GIT_REPO_NAME}

        echo "### Cloning GrandNode repository"
        git clone --recurse-submodules ${GIT_REPO}/${GIT_REPO_NAME}

        echo "### Building GrandNode"
        dotnet build ./${GIT_REPO_NAME}/${GRANDNODE_PROJECT_PATH}

        echo "### Installing GrandNode dependencies"
        npm install --prefix ./${GIT_REPO_NAME}/${GRANDNODE_WEB_PATH}

        echo "### Copying configuration files"
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

# echo "### Opening GrandNode solution"
# cd ../${GIT_REPO_NAME} && open ${GRANDNODE_SOLUTION_PATH}

echo "### All done!"