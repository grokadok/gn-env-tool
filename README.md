# GrandNode Development Environment

A development environment setup for GrandNode with MongoDB data masking capabilities.

## Prerequisites

-   Git
-   Docker and Docker Compose
-   .NET SDK according to project
-   Node.js and npm
-   MongoDB Tools (mongosh, mongorestore)
-   A .Net capable IDE (Visual Studio, Rider)

## Setup

1. Copy the environment file:

    ```bash
    cp .env.example .env
    ```

2. Configure your [.env](http://_vscodecontentref_/1) file with:

    - MongoDB details
    - Git repository details
    - GrandNode paths

    ### Environment Variables

    | Variable                 | Description                              | Example                                  |
    | ------------------------ | ---------------------------------------- | ---------------------------------------- |
    | `MONGO_USER`             | MongoDB username                         | user                                     |
    | `MONGO_PASSWORD`         | MongoDB password                         | password                                 |
    | `MONGO_HOST`             | MongoDB server hostname                  | localhost                                |
    | `MONGO_PORT`             | MongoDB server port                      | 27017                                    |
    | `MONGO_DB`               | MongoDB database name                    | grandnode                                |
    | `GIT_REPO`               | Git repository URL                       | git@ssh.dev.azure.com:v3/org/project     |
    | `GIT_REPO_NAME`          | Repository name/folder                   | ProjectName.GrandNode                    |
    | `GIT_WORKING_COMMIT`     | Fallback commit hash if main clone fails | 3d65bd034145c1a8cc668deef259c7c08ad89615 |
    | `GRANDNODE_PROJECT_PATH` | Path to solution file                    | GrandNode.sln                            |
    | `GRANDNODE_WEB_PATH`     | Path to web application                  | src/Web/Grand.Web                        |

3. Prepare required assets:

    - Place MongoDB dump in `mongodb/dumps`, as an .archive file or a folder named after the database
    - Edit configuration file if needed:
        - `assets/data/InstalledPlugins.cfg`
    - (Optional) Add images in `assets/images/uploaded`

4. For data masking:
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
└── script.sh           # Main setup script
```

## Notes

-   MongoDB data is persisted in `mongodb/data`
-   Masked data is saved as `dumps/masked.archive`
-   The script checks for all required assets before running
-   Image assets are optional with prompt to continue without them
