# Use an official base image with a Linux distribution
FROM ubuntu:latest

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y jq curl git && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy the script and env file into the container
COPY copy_github_repos.sh .

# Make the script executable
RUN chmod +x copy_github_repos.sh

# Default command to run the script
CMD ["./copy_github_repos.sh"]

# docker build -t copy-git-repos:initial .
# docker run  --rm -v $(pwd)/data:/app/data  -v ./env/user:/app/.env copy-git-repos:initial ./copy_github_repos.sh -p user -w /app/data -r