#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get environment variables
CONFIG_FILE="${CONFIG_FILE:-./projects/all_projects.yaml}" # Updated path
GITHUB_TOKEN="${GITHUB_TOKEN}"

# Ensure yq is available (should be installed by the workflow step)
if ! command -v yq &> /dev/null
then
    echo "Error: yq command not found. Please ensure it's installed."
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

echo "Starting release check using $CONFIG_FILE..."

# Use yq to iterate over each project block
yq -y '.projects[]' "$CONFIG_FILE" | while read -r project_yaml_block; do
    # Use yq to extract project details and Dockerfile info
    name=$(echo "$project_yaml_block" | yq  '.name' -)
    repo_url=$(echo "$project_yaml_block" | yq  '.repo_url' -)
    current_version=$(echo "$project_yaml_block" | yq  '.current_version' -)

    # Extract Dockerfile source and path/name
    dockerfile_source=""
    dockerfile_path=""
    build_repo_dockerfile_name=""

    if echo "$project_yaml_block" | yq  '.dockerfile.in_repo' - &> /dev/null; then
        dockerfile_source="in_repo"
        dockerfile_path=$(echo "$project_yaml_block" | yq  '.dockerfile.in_repo' -)
        if [ "$dockerfile_path" == "null" ]; then dockerfile_path=""; fi # Handle null yq output
    elif echo "$project_yaml_block" | yq  '.dockerfile.from_build_repo' - &> /dev/null; then
        dockerfile_source="from_build_repo"
        build_repo_dockerfile_name=$(echo "$project_yaml_block" | yq  '.dockerfile.from_build_repo' -)
        if [ "$build_repo_dockerfile_name" == "null" ]; then build_repo_dockerfile_name=""; fi # Handle null yq output
    else
        echo "Skipping project '$name': Missing or invalid 'dockerfile' configuration."
        continue # Skip this project if Dockerfile source is not specified correctly
    fi

     if [ -z "$name" ] || [ -z "$repo_url" ] || [ -z "$current_version" ]; then
        echo "Skipping malformed project entry: $project_yaml_block"
        continue
    fi

    # Extract owner and repo name from URL
    echo $repo_url
    if [[ "$repo_url" =~ github.com/([^/]+)/([^/]+) ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        echo "Skipping project with invalid repo_url format: $repo_url"
        continue
    fi

    echo "Checking $name ($owner/$repo)..."

    # Use curl to get the latest release and jq to parse the tag_name
    api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
    latest_release_response=$(curl -s -H "Accept: application/vnd.github.v3+json" -H "Authorization: token $GITHUB_TOKEN" "$api_url")

    # Check for curl errors or non-200 status codes
    if [ $? -ne 0 ]; then
        echo "  Error fetching latest release for $name: curl failed."
        continue
    fi

    latest_version=$(echo "$latest_release_response" | jq -r '.tag_name')

    # Check if jq successfully extracted tag_name
    if [ "$latest_version" == "null" ] || [ -z "$latest_version" ]; then
        # Check if the response indicates a repo not found or error
        error_message=$(echo "$latest_release_response" | jq -r '.message // ""')
        if [ -n "$error_message" ]; then
             echo "  Error fetching latest release for $name: $error_message"
        else
             echo "  Could not find 'tag_name' in latest release data for $name. Skipping."
        fi
        continue
    fi

    echo "  Current version in config: $current_version"
    echo "  Latest release version: $latest_version"

    if [ "$latest_version" != "$current_version" ]; then
        echo "  New release found for $name: $latest_version (was $current_version)"

        # Construct the JSON object for this project, including Dockerfile source info
        project_obj=$(jq -c \
          --arg name "$name" \
          --arg repo_url "$repo_url" \
          --arg latest_version "$latest_version" \
          --arg dockerfile_source "$dockerfile_source" \
          --arg dockerfile_path "$dockerfile_path" \
          --arg build_repo_dockerfile_name "$build_repo_dockerfile_name" \
          '{name: $name, repo_url: $repo_url, latest_version: $latest_version, dockerfile_source: $dockerfile_source, dockerfile_path: $dockerfile_path, build_repo_dockerfile_name: $build_repo_dockerfile_name}')

        # Append the project object to the projects_to_build_json array
        # Read the current JSON array from the environment variable, append, and update the variable
        current_projects_json=$(echo "${!GITHUB_OUTPUT}" | awk '/projects_to_build=/{gsub("projects_to_build=",""); print}')
        if [ -z "$current_projects_json" ]; then
            # If variable is empty (first project), initialize with the first object
            echo "projects_to_build=[$project_obj]" >> "$GITHUB_OUTPUT"
        else
            # Otherwise, append to the existing array (strip trailing ']' and add ', obj]')
            echo "projects_to_build=$(echo "$current_projects_json" | sed 's/]$/,/')$project_obj]" >> "$GITHUB_OUTPUT"
        fi


        # Optional: Update the current_version in the config file directly using yq
        # This requires 'contents: write' permission on the job and a writable checkout
        # echo "Updating config for $name to $latest_version..."
        # yq  "(.projects[] | select(.name == \"$name\").current_version) = \"$latest_version\"" -i "$CONFIG_FILE"


    else
        echo "  No new release for $name."
    fi

done

# Read the final output variable value to report the count
final_projects_json=$(echo "${!GITHUB_OUTPUT}" | awk '/projects_to_build=/{gsub("projects_to_build=",""); print}')
num_projects_to_build=$(echo "$final_projects_json" | jq '. | length')
echo "Finished release check. Projects needing build: $num_projects_to_build"

# If you chose to update the config file within the script, you would then
# add git add, commit, and push steps in the workflow YAML *after* running the script.
# if [ "$num_projects_to_build" -gt 0 ]; then
#    echo "Committing and pushing updated config..."
#    # Add git commands here (requires git user config, add, commit, push)
#    # Ensure the workflow checkout step uses a token with write permission
# fi

