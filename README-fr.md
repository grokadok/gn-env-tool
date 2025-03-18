# Environnement de Développement GrandNode

## Aperçu

Cet environnement de développement pour GrandNode offre :

-   Automatisation complète du processus d'installation incluant le clonage du dépôt, la compilation et l'installation des dépendances
-   Fonctionnalités de masquage des données MongoDB pour un développement sécurisé avec des données similaires à la production
-   Exécution de MongoDB à partir d'un fichier dump ou d'un dossier fourni
-   Journalisation complète de toutes les requêtes et réponses
-   Support de plusieurs méthodes de connexion : localhost:port, adresse IP:port, ou tout hôte pointant vers le réseau local
-   Création d'un compte administrateur avec les identifiants devadmin:devadmin
-   Envoi des emails vers une instance [maildev](http://localhost:1080) accessible à l'adresse http://localhost:1080

## Prérequis

-   Git
-   Docker et Docker Compose
-   SDK .NET correspondant au projet
-   Node.js et npm
-   Outils MongoDB (MongoDB Shell, MongoDB Command Line Database tools)
-   Un IDE compatible .NET (Visual Studio, Rider)

## Installation

1. Cloner le dépôt :

    ```bash
    git clone https://github.com/grokadok/gn-env-tool.git --config core.autocrlf=false
    ```

    > **Note pour les utilisateurs Windows** : Ajouter `--config core.autocrlf=false` à votre commande git clone évite les problèmes de fin de ligne avec les scripts shell.

2. Copier le fichier d'environnement :

    ```bash
    cp .env.example .env
    ```

3. Configurer votre fichier .env avec :

    - Détails MongoDB
    - Détails du dépôt Git
    - Chemins GrandNode
    - Identifiants souhaités pour l'utilisateur et l'administrateur GrandNode
    - Configuration des boutiques GrandNode (attention au(x) port(s) utilisé(s), définissez celui utilisé par l'IDE, par exemple 5001 pour Rider sur macOS)

    ### Variables d'Environnement

    | Variable                 | Description                          | Exemple                                  |
    | ------------------------ | ------------------------------------ | ---------------------------------------- |
    | `GN_USER_USERNAME`       | Nom utilisateur GrandNode            | user                                     |
    | `GN_USER_EMAIL`          | Email utilisateur GrandNode          | user@example.com                         |
    | `GN_PASSWORD`            | Mot de passe utilisateur GrandNode   | password                                 |
    | `GN_ADMIN_USERNAME`      | Nom d'utilisateur admin GrandNode    | admin                                    |
    | `GN_ADMIN_EMAIL`         | Email admin GrandNode                | admin@example.com                        |
    | `GN_ADMIN_PASSWORD`      | Mot de passe admin GrandNode         | password                                 |
    | `GN_STORES_NAMES`        | Noms des boutiques                   | boutique_1,boutique_2                    |
    | `GN_STORES_HOSTS`        | Domaines des boutiques               | boutique1.com,boutique2.com              |
    | `GN_STORES_PORTS`        | Ports des boutiques (optionnels)     | 5001,5002                                |
    | `MONGO_USER`             | Nom d'utilisateur MongoDB            | user                                     |
    | `MONGO_PASSWORD`         | Mot de passe MongoDB                 | password                                 |
    | `MONGO_HOST`             | Nom d'hôte du serveur MongoDB        | localhost                                |
    | `MONGO_PORT`             | Port du serveur MongoDB              | 27017                                    |
    | `MONGO_DB`               | Nom de la base de données MongoDB    | grandnode                                |
    | `MAILDEV_INCOMING_USER`  | Nom d'utilisateur Maildev            | user                                     |
    | `MAILDEV_INCOMING_PASS`  | Mot de passe Maildev                 | password                                 |
    | `MAILDEV_WEB_HOST`       | Port web Maildev                     | 1080                                     |
    | `MAILDEV_SMTP_HOST`      | Port SMTP Maildev                    | 1025                                     |
    | `GIT_REPO`               | URL du dépôt Git                     | git@ssh.dev.azure.com:v3/org/project     |
    | `GIT_REPO_NAME`          | Nom/dossier du dépôt                 | ProjectName.GrandNode                    |
    | `GIT_WORKING_COMMIT`     | Commit de secours si le clone échoue | 3d65bd034145c1a8cc668deef259c7c08ad89615 |
    | `GRANDNODE_PROJECT_PATH` | Chemin vers le fichier solution      | GrandNode.sln                            |
    | `GRANDNODE_WEB_PATH`     | Chemin vers l'application web        | src/Web/Grand.Web                        |

4. Préparer les ressources nécessaires :

    - Placer le dump MongoDB dans [dumps](http://_vscodecontentref_/1), sous forme de fichier .archive ou d'un dossier nommé d'après la base de données
    - Éditer le fichier de configuration si nécessaire :
        - [InstalledPlugins.cfg](http://_vscodecontentref_/2)
    - (Optionnel) Ajouter des images dans [uploaded](http://_vscodecontentref_/3)

5. Pour le masquage des données :
    ```bash
    cp masking_logic.js.example masking_logic.js
    ```
    Éditer [masking_logic.js](http://_vscodecontentref_/4) avec vos règles de masquage.

## Utilisation

Le script principal offre deux options :

```bash
./script.sh [--clone] [--mask]
```

-   `--clone`: Clone et configure le dépôt GrandNode

    -   Compile la solution
    -   Installe les dépendances
    -   Copie les fichiers de configuration
    -   Copie les ressources d'images (si disponibles)

-   `--mask`: Applique les règles de masquage des données
    -   Crée un dump MongoDB masqué
    -   Utile pour développer avec des données de production anonymisées

## Structure des Répertoires

```
├── assets/
│   ├── data/           # Fichiers de configuration GrandNode
│   └── images/         # Ressources d'images
│       ├── thumbs/     # Images miniatures
│       └── uploaded/   # Images téléchargées
├── mongodb/
│   ├── dumps/          # Dumps de base de données MongoDB
│   └── mask/           # Fichiers de processus de masquage
├── .env                # Configuration d'environnement
├── masking_logic.js    # Règles de masquage des données MongoDB
├── db_setup.js         # Configuration des comptes MongoDB et Maildev
├── script.bat          # Script principal de configuration (batch)
└── script.sh           # Script principal de configuration (shell)
```

## Notes

-   Les données MongoDB sont persistées dans `mongodb/data`
-   Les données masquées sont sauvegardées comme `dumps/masked.archive`
-   Le script vérifie toutes les ressources nécessaires avant l'exécution
-   Les ressources d'images sont optionnelles avec une invite pour continuer sans elles
-   Si le clonage échoue, il essaiera de cloner le dernier commit fonctionnel si fourni

## Problèmes Connus

-   **Fins de ligne Windows**: Les scripts peuvent échouer sur Windows si clonés sans l'option `--config core.autocrlf=false` en raison de problèmes de conversion des fins de ligne.
-   **Compatibilité de version .NET SDK**: Sur Windows, si le projet n'est pas compatible avec .NET SDK 9 et versions ultérieures, Visual Studio peut forcer l'installation de .NET SDK 9, provoquant des échecs de compilation. Une solution pour forcer la compilation à utiliser une version majeure spécifique du SDK est en cours d'étude.
-   **Échecs de connexion MongoDB**: Si MongoDB ne parvient pas à se connecter, vérifiez vos paramètres de pare-feu et assurez-vous que les ports spécifiés dans `.env` sont disponibles.
-   **Permissions des ressources d'images**: Sur Linux/macOS, assurez-vous que les répertoires `assets/images` ont les permissions de lecture/écriture appropriées.
-   **Authentification SSH Git**: Lors de l'utilisation d'URLs SSH pour `GIT_REPO`, assurez-vous que vos clés SSH sont correctement configurées avec le dépôt source.
-   **Performance du masquage des données**: Le masquage de grandes bases de données peut prendre beaucoup de temps et de ressources.
