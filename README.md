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

2. Configure your `.env` file with:

    - MongoDB credentials
    - Git repository details
    - GrandNode paths

3. Prepare required assets:

    - Place MongoDB dump in `mongodb/dumps`, as an .archive file or a folder named after the database
    - Add configuration file:
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
├── mongodb/
│   ├── dumps/          # MongoDB database dumps
│   └── mask/           # Masking configuration
├── .env                # Environment configuration
├── masking_logic.js    # MongoDB data masking rules
└── script.sh           # Main setup script
```

## Notes

-   MongoDB data is persisted in `mongodb/data`
-   Masked data is saved as `dumps/masked.archive`
-   The script checks for all required assets before running
-   Image assets are optional with prompt to continue without them
