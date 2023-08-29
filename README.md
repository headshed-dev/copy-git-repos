# Copy Git Repos

Copy Git Repos is a Bash script for copying all Git repositories or those updated in the last 30 days owned by a given account from Github to your local system.

It can be run as a script or a docker container and is developed on an Ubuntu Linux system.



## Installation

clone this repo and cd into it

```
git clone https://github.com/headshed-dev/copy-git-repos
cd copy-git-repos
```
### Docker Install

build using docker with 

```bash
docker build -t copy-git-repos:initial .
```

### Bash Script Setup

install for using the script with its prerequisites `jq`, `cur`, `git` in Ubuntu or Debian

```bash
apt-get update 
apt-get install -y jq curl git
```

## Usage

create an env file ```env/user``` containing

```
GIT_USERNAME=user
GIT_TOKEN=ghp_<users personal git token>
```

### Running with Docker

In your current directory, create a ```data``` directory into which the git repositories will be copied to.

Run the previously built container with:

```bash
docker run  --rm -v $(pwd)/data:/app/data  -v ./env/user:/app/.env copy-git-repos:initial ./copy_github_repos.sh -p user -w /app/data -r
```

where ```user``` is the username in the env file that owns the github repositories.

### Running as a Bash Script

```bash
./copy_github_repos.sh

Usage: ./copy_github_repos.sh [-e|--envfile <string>] [-p|--prefix <string>] [-w | --workdir <string>] [-h|--help] [-r | --run] [-f | --full]

    <env_file> is the name of the file to read environment variables from.

    Example 1:

        ./copy_github_repos.sh -e env/youruser -p youruser --run --full

        backs up all repos it can find up to 10 pages of 100 repos per page

    If the env file is not in the current directory, provide the full path to the file.

    Example 2:

        ./copy_github_repos.sh -e env/youruser -p youruser --run

        backs up repos that have been updated in the last 30 days

    Example env file contentts

    GIT_USERNAME=<your github username>
    GIT_TOKEN=ghp_<your github personal access token>

```

Default behaviour is for repositories to be copied to a directory under the current users home ```BACKUPS="$HOME/github-backups"``` or this may be specified with the ```-w | --workdir``` flag.

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.


## License

[MIT](https://choosealicense.com/licenses/mit/)