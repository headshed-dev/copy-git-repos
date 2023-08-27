#!/usr/bin/env bash

# you can edit these variables to suit your needs
BACKUPS="$HOME/github-backups"
LOGS_DIR="$BACKUPS/logs"
# set max number of iterations - this will equate to 10 pages of 100 repos
# so should be enough for most users, increase if you have more than 1000 repos
MAX=10
DAYS_AGO="-30 days"
###############################################

# DO NOT EDIT BELOW THIS LINE

CURRENT_DATE=$(date +'%Y-%m-%d_%H-%M-%S')

# calculate the current date as an epoch minus 30 days
# this will be used to filter out repos that have not been updated in the last N days
# eg./ 30 days = 2592000 seconds
CURRENT_DATE_MINUS_N_DAYS=$(date -d "$DAYS_AGO" +%s)

usage() {
    echo "Usage: $0 [-e|--envfile] [-p|--prefix <string>] [-h|--help] [--run] [--full]" 1>&2
cat <<EOF

    <env_file> is the name of the file to read environment variables from.

    Example 1: 
    
        $0 -e env/youruser -p youruser --run --full

        backs up all repos it can find up to 10 pages of 100 repos per page

    If the env file is not in the current directory, provide the full path to the file.

    Example 2: 
    
        $0 -e env/youruser -p youruser --run 
    
        backs up repos that have been updated in the last 30 days

    Example env file contentts

    GIT_USERNAME=<your github username>
    GIT_TOKEN=ghp_<your github personal access token>

EOF



    exit 1
}

# Parse options using getopt
TEMP=$(getopt -o e:p:r:h --long envfile:,prefix:,run,help,full -n "$0" -- "$@")
eval set -- "$TEMP"

while true; do
    case "$1" in
    -e | --envfile)
        e=$2
        shift 2
        ;;
    -p | --prefix)
        p=$2
        shift 2
        ;;
    --run)
        r=true
        shift
        ;;
    --full)
        f=true
        shift
        ;;
    -h | --help)
        h=true
        usage
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z "${e}" ] && [ -z "${p}" ]; then
    # Both -e and -p are empty, treat them as optional
    echo "No values provided for environment file -e and prefix -p, using default values or fallback logic"
    e=".env"
    p=""
elif [ -z "${e}" ]; then
    # -e is empty, treat it as optional
    echo "No value provided for environment file -e, using default value or fallback logic"
    e=".env"
elif [ -z "${p}" ]; then
    # -p is empty, treat it as optional
    echo "No value provided for prefix -p, using default value or fallback logic"
    p=""
fi

# function to copy all repos
function clone_repo() {

    echo "Cloning $repo..."
    git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/$repo.git"

    # Change into the cloned repository directory
    repo_name=$(basename "$repo")
    cd "$repo_name"

    # Fetch the latest changes from the remote repository
    git fetch --prune

    # Iterate through remote branches
    remote_branches=$(git branch -r | grep -v HEAD)
    for remote_branch in $remote_branches; do
        branch_name=$(echo "$remote_branch" | sed 's/origin\///')
        # Strip out leading spaces from branch name
        branch_name=$(echo "$branch_name" | sed 's/^ *//g')

        # Checkout the branch
        echo "Checking out [$branch_name]..."
        git checkout "$branch_name"
    done

    # Change back to the previous directory
    cd ..

    echo "Done cloning $repo."
    echo

}

# create a function that will process output of the response
function backup_each_repo_in_page() {
    # use jq to extract full_name from each objecct in the json array
    repo_names=$(echo "$JSON" | jq -r '.[].full_name')
    # updated_at
    updated_at=$(echo "$JSON" | jq -r '.[].updated_at')
    repo_info=$(echo "$JSON" | jq -r '.[] | "\(.full_name)|\(.updated_at)"')

    # Iterate over the repository names
    IFS=$'\n' # Set IFS to newline to properly handle lines
    for info in $repo_info; do

        IFS='|' read -ra repo_info_array <<<"$info"
        repo="${repo_info_array[0]}"
        datetime="${repo_info_array[1]}"
        epoch_timestamp=$(date -d "$datetime" +%s)

        # if $f is 'true' then clone all repos
        if [ -z "${f}" ]; then
            # if the repo has not been updated in the last N days, skip it
            if [ "$epoch_timestamp" -lt "$CURRENT_DATE_MINUS_N_DAYS" ]; then
                continue
            fi

            echo "recently modified repo $repo datetime is $datetime"
            clone_repo
        else
            echo "repo is $repo [full backup in progress]"
            clone_repo
        fi

    done

}

function curl_github_api() {

    # get a full list of all repos taking into account pagination
    # and a limit of 100 repos per page from the GitHub API
    # then call backup_each_repo_in_page to process the response

    # set run variable to true
    r=true

    # set the page count to 1
    count=1
    # untill the run variable is false and MAX is not exceeded run a loop
    until [ "$r" = false ]; do

        MAX=$((MAX - 1))
        if [ "$MAX" -eq 0 ]; then
            r=false
        fi

        echo "Getting page $count of repos..."
        JSON=$(curl -s -L \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GIT_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/user/repos?per_page=100&page=$count")

        # check if response contains the string "Requires authentication" or "Bad credentials"
        if [[ $JSON == *"Requires authentication"* ]] || [[ $JSON == *"Bad credentials"* ]]; then
            echo "Invalid username or token. Please set the correct username and token in the script."
            exit 1
        fi

        count=$((count + 1))
        REPO_COUNT=$(echo "$JSON" | jq length)

        if [ $REPO_COUNT -eq 0 ]; then
            echo "No repositories found."
            exit 1
        fi

        echo "Found $REPO_COUNT objects."

        # if $REPO_COUNT is less than 100 then we have reached the end of the list
        if [ "$REPO_COUNT" -lt 100 ]; then
            r=false
        fi

        cd $BACKUP_DIR

        # process the response
        backup_each_repo_in_page
        echo ""
        echo "... repositories have been cloned to $BACKUP_DIR"

    done

}

function main() {

    echo "starting main with arguments:"
    echo "e = ${e}"
    echo "p = ${p}"
    echo "r = ${r}"
    echo "f = ${f}"

    # if the environment file doesn't exist, print error and exit
    if [ ! -f "$e" ]; then
        echo "environment file $e does not exist"
        exit 1
    fi

    source "$e"

    prefix=""
    if [ -z "${p}" ]; then
        echo "no prefix set"
    else
        prefix="${p}_"
        echo "prefix set to [$prefix]"
    fi

    # if r is 'true'
    if [ -z "${r}" ]; then
        echo "not running anything as --run is not present in the arguments"
    else
        LOG_FILE="$LOGS_DIR/$GIT_USERNAME-$CURRENT_DATE.log"
        # create logs directory if it doesn't exist
        if [ ! -d "$LOGS_DIR" ]; then
            mkdir -p "$LOGS_DIR"
        fi
        exec > >(tee -a $LOG_FILE)
        echo "run is true, runing curl_github_api"

        # create a backupt directory with timestamp in the name and change into it
        BACKUP_DIR="${BACKUPS}/${prefix}${CURRENT_DATE}"

        echo "backups is $BACKUPS"
        echo "prefix is $prefix"
        echo "CURRENT_DATE is $CURRENT_DATE"

        mkdir -p $BACKUP_DIR
        curl_github_api
    fi

    exit 0

}

main
