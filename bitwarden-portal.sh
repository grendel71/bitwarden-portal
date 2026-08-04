#!/bin/bash

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")

#-------------------#
# Helper Functions  #
#-------------------#

fix_permissions() {
    local puid="$1"
    local pgid="$2"
    local folder="$3"

    chown -R "$puid:$pgid" "$folder"
}


purge_folder() {
    local folder_path="$1"
    local max_files="$2"
    local retention_days="$3"

    local folder_name=$(echo "$folder_path" | sed 's/\/app\///g')

    if [ "$ENABLE_PRUNING" == "false" ]; then
        echo "# Pruning disabled, skipping..."
        return
    elif [ "$ENABLE_PRUNING" != "true" ]; then
        echo "The var ENABLE_PRUNING is invalid (only 'true' or 'false' is accepted): $ENABLE_PRUNING"
        exit 1
    fi

    echo "# Purging files in folder: $folder_name."

    # Find all files in the folder sorted by modification time (oldest first)
    all_files=$(find "$folder_path" -type f -printf "%T@ %p\n" | sort -n)

    # Find files older than the retention period
    old_files=$(find "$folder_path" -type f -mtime +"$retention_days")

    # Find files newer than the retention period
    recent_files=$(find "$folder_path" -type f -mtime -"$retention_days")

    # Check if there are no files in the folder
    if [ -z "$all_files" ]; then
        echo "# No files found in the folder: $folder_path. Nothing to purge."
        return
    fi

    # Case 1: If there are recent files, delete only the files older than retention_days
    if [ -n "$recent_files" ]; then
        if [ -n "$old_files" ]; then
            echo "# Found files modified within the last $retention_days days. Deleting only older files..."
            find "$folder_path" -type f -mtime +"$retention_days" -exec rm -f {} +
        else
            echo "# No files older than $retention_days days to delete. Nothing to purge."
        fi
    else
        # Case 2: If all files are older than retention_days, keep only the most recent max_files files
        echo "# All files are older than $retention_days days. Keeping the most recent $max_files files..."
        echo "$all_files" | head -n -"$max_files" | awk '{print $2}' | xargs -I{} rm -f "{}"
    fi

    echo "# Purge completed for $folder_name."
}


#------#
# INIT #
#------#

# Create folder if not exists 
SOURCE_FOLDER="/app/backups/source"

mkdir -p "$SOURCE_FOLDER"

if [ $? -ne 0 ]; then
    echo "✕ Error: Failed to create folder /backups/source."
    exit 1
fi

echo "########## Start of Backup process ##########"

echo "# Fixing permissions on backups folder..."
fix_permissions "$PUID" "$PGID" "/app/backups"

sleep 1


#--------#
# BACKUP #
#--------#

echo "# Start Time: $(date)"

# Set the filename for our json export as variable
SOURCE_EXPORT_OUTPUT_BASE="bw_export_source_"
SOURCE_NEW_FILENAME="$SOURCE_EXPORT_OUTPUT_BASE$TIMESTAMP.json"
# Encrypted export written directly to backup folder (no plaintext on disk)
ENCRYPTED_SOURCE_OUTPUT_FILE_PATH="$SOURCE_FOLDER/$SOURCE_NEW_FILENAME"


#--------------#
# SOURCE PURGE #
#--------------#

purge_folder "$SOURCE_FOLDER" "$MIN_FILES" "$RETENTION_DAYS"
sleep 1


#--------------#
# SOURCE LOGIN #
#--------------#

# Lets make sure we're logged out before we start
echo "# Logging out from Bitwarden..."
bw logout >/dev/null

export BW_CLIENTID=${SOURCE_CLIENT_ID}
export BW_CLIENTSECRET=${SOURCE_CLIENT_SECRET}

# Login to our Server
echo "# Logging into Source server..."
bw config server "$SOURCE_SERVER"

bw login "$SOURCE_ACCOUNT" --apikey --raw

if [ $? -ne 0 ]; then
    printf "\n"
    echo "✕ Error: Failed to log in to source server with account ${SOURCE_ACCOUNT} at ${SOURCE_SERVER}."
    exit 1
fi

printf '\n'

# By using an API Key, we need to unlock the vault to get a sessionID
echo "# Unlocking the vault..."
SOURCE_SESSION=$(bw unlock "$SOURCE_PASSWORD" --raw)

if [ -z "$SOURCE_SESSION" ]; then
    echo "✕ Error: No source session retrieved. Check your source credentials and try again."
    exit 1
fi

# Synchronizing the vault
echo "# Synchronizing the vault..."
bw sync --session "$SOURCE_SESSION"
printf '\n'


#---------------#
# SOURCE EXPORT #
#---------------#

echo "# Exporting all items..."
bw --session "$SOURCE_SESSION" export --format encrypted_json --password "$ENCRYPTION_PASSWORD" --output "$ENCRYPTED_SOURCE_OUTPUT_FILE_PATH"

if [ $? -ne 0 ]; then
    echo "✕ Error: Failed to export data."
    exit 1
fi

fix_permissions "$PUID" "$PGID" "$ENCRYPTED_SOURCE_OUTPUT_FILE_PATH"


#---------------#
# SOURCE LOGOUT #
#---------------#
echo "# Locking the vault..."
bw lock
echo ""

# Logout
echo "# Logging out from Bitwarden..."
bw logout >/dev/null

unset BW_CLIENTID
unset BW_CLIENTSECRET

echo "########## End of Backup process ##########"
