# GrandNode Development Environment

## Overview

This is a development environment for GrandNode that:

-   Automates the entire setup process including repository cloning, building, and dependency installation
-   Features MongoDB data masking capabilities for secure development with production-like data
-   Runs MongoDB from a provided dump file or folder
-   Provides comprehensive logging of all requests and responses
-   Supports multiple connection methods: localhost:port, IP address:port, or any host pointing to the local network
-   Creates an admin account with credentials devadmin:devadmin
-   Sends emails to a [maildev](http://localhost:1080) instance accessible at http://localhost:1080

## Prerequisites

-   Git
-   Docker and Docker Compose
-   .NET SDK according to project
-   Node.js and npm
-   MongoDB Tools (MongoDB Shell, MongoDB Command Line Database tools)
-   A .Net capable IDE (Visual Studio, Rider)

## Setup

1. Clone the repository:

    ```bash
    git clone https://github.com/grokadok/gn-env-tool.git --config core.autocrlf=false
    ```

    > **Note for Windows users**: Adding `--config core.autocrlf=false` to your git clone command prevents line ending issues with shell scripts.

2. Copy the environment file:

    ```bash
    cp .env.example .env
    ```

3. Configure your .env file with:

    - MongoDB details
    - Git repository details
    - GrandNode paths

    ### Environment Variables

    | Variable                 | Description                              | Example                                  |
    | ------------------------ | ---------------------------------------- | ---------------------------------------- |
    | `GN_ADMIN_USER`          | GrandNode admin username                 | admin                                    |
    | `GN_ADMIN_PASSWORD`      | GrandNode admin password                 | password                                 |
    | `MONGO_USER`             | MongoDB username                         | user                                     |
    | `MONGO_PASSWORD`         | MongoDB password                         | password                                 |
    | `MONGO_HOST`             | MongoDB server hostname                  | localhost                                |
    | `MONGO_PORT`             | MongoDB server port                      | 27017                                    |
    | `MONGO_DB`               | MongoDB database name                    | grandnode                                |
    | `MAILDEV_INCOMING_USER`  | Maildev username                         | user                                     |
    | `MAILDEV_INCOMING_PASS`  | Maildev password                         | password                                 |
    | `MAILDEV_WEB_HOST`       | Maildev web port                         | 1080                                     |
    | `MAILDEV_SMTP_HOST`      | Maildev smtp port                        | 1025                                     |
    | `GIT_REPO`               | Git repository URL                       | git@ssh.dev.azure.com:v3/org/project     |
    | `GIT_REPO_NAME`          | Repository name/folder                   | ProjectName.GrandNode                    |
    | `GIT_WORKING_COMMIT`     | Fallback commit hash if main clone fails | 3d65bd034145c1a8cc668deef259c7c08ad89615 |
    | `GRANDNODE_PROJECT_PATH` | Path to solution file                    | GrandNode.sln                            |
    | `GRANDNODE_WEB_PATH`     | Path to web application                  | src/Web/Grand.Web                        |

4. Prepare required assets:

    - Place MongoDB dump in `mongodb/dumps`, as an .archive file or a folder named after the database
    - Edit configuration file if needed:
        - `assets/data/InstalledPlugins.cfg`
    - (Optional) Add images in `assets/images/uploaded`

5. For data masking:
    ```bash
    cp masking_logic.js.example masking_logic.js
    ```
    Edit `masking_logic.js` with your masking rules.

## Usage

The main script provides two options:

```bash
./script.sh [--clone] [--mask]
```

-   `--clone`: Clones and sets up GrandNode repository

    -   Builds the solution
    -   Installs dependencies
    -   Copies configuration files
    -   Copies image assets (if available)

-   `--mask`: Applies data masking rules
    -   Creates a masked MongoDB dump
    -   Useful for developing with sanitized production data

## Directory Structure

```
├── assets/
│   ├── data/           # GrandNode configuration files
│   └── images/         # Image assets
│       ├── thumbs/     # Thumbnail images
│       └── uploaded/   # Uploaded images
├── mongodb/
│   ├── dumps/          # MongoDB database dumps
│   └── mask/           # Masking process files
├── .env                # Environment configuration
├── masking_logic.js    # MongoDB data masking rules
├── db_setup.js         # MongoDB accounts and Maildev setup
├── script.bat          # Main setup script (batch)
└── script.sh           # Main setup script (shell)
```

## Notes

-   MongoDB data is persisted in `mongodb/data`
-   Masked data is saved as `dumps/masked.archive`
-   The script checks for all required assets before running
-   Image assets are optional with prompt to continue without them
-   If clone fails, it will try to clone the last working commit if provided
