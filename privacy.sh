#!/bin/bash

# Standalone script to check, backup, and optionally disable macOS privacy-related settings (with automatic updates enabled)
# Run with: sudo bash this_script.sh

LOGFILE="/tmp/macos_privacy_disable.log"
BACKUPFILE="/tmp/macos_privacy_backup_$(date +%Y%m%d_%H%M%S).txt"
echo "=== macOS Privacy Settings Report - $(date) ===" | tee "$LOGFILE"

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)." | tee -a "$LOGFILE"
    exit 1
fi

# Detect original user
ORIG_USER="${SUDO_USER:-$(whoami)}"
if [ "$ORIG_USER" = "root" ]; then
    echo "Error: Cannot determine original user. Run with sudo as a non-root user." | tee -a "$LOGFILE"
    exit 1
fi
ORIG_HOME=$(eval echo "~$ORIG_USER")

# Function to log and print to console
log_and_print() {
    echo "$1" | tee -a "$LOGFILE"
}

# Function to backup system-level default
backup_system() {
    local domain="$1"
    local key="$2"
    local current=$(defaults read "$domain" "$key" 2>/dev/null || echo "not set")
    echo "System • $domain $key = $current" >> "$BACKUPFILE"
}

# Function to backup user-level default
backup_user() {
    local domain="$1"
    local key="$2"
    local current=$(su - "$ORIG_USER" -c "defaults read '$domain' '$key' 2>/dev/null || echo 'not set'" 2>/dev/null || echo "error reading")
    echo "User ($ORIG_USER) • $domain $key = $current" >> "$BACKUPFILE"
}

# Function to check system-level default
check_system() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local current=$(defaults read "$domain" "$key" 2>/dev/null || echo "not set")
    log_and_print "System • $domain $key = $current (desired: $expected)"
}

# Function to check user-level default
check_user() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local current=$(su - "$ORIG_USER" -c "defaults read '$domain' '$key' 2>/dev/null || echo 'not set'" 2>/dev/null || echo "error reading")
    log_and_print "User ($ORIG_USER) • $domain $key = $current (desired: $expected)"
}

log_and_print ""
log_and_print "=== CURRENT SETTINGS REPORT ==="

# 1.1 Disable Diagnostic & Usage Data auto-submission
check_system "/Library/Preferences/com.apple.SubmitDiagInfo" "AutoSubmit" "false (0)"

# 1.2 Disable Crash Reporter dialogs (user-level)
check_user "com.apple.CrashReporter" "DialogType" "none"

# 1.3 Enable Automatic macOS update checks and downloads (for security)
check_system "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticCheckEnabled" "true (1)"
check_system "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticDownload" "true (1)"

# 1.4 Disable Siri (user-level)
check_user "com.apple.assistant.support" "Assistant Enabled" "false (0)"
check_user "com.apple.Siri" "StatusMenuVisible" "false (0)"

# 1.5 Disable Spotlight Suggestions & Privacy Hints (user-level)
check_user "com.apple.lookup.shared" "LookupSuggestionsDisabled" "true (1)"

# 1.6 Disable iCloud Analytics & Usage Tracking (user-level)
check_user "com.apple.UsageTracking" "CoreDonationsEnabled" "false (0)"
check_user "com.apple.UsageTracking" "UDCAutomationEnabled" "false (0)"

log_and_print ""
log_and_print "=== END REPORT ==="
log_and_print "Log saved to: $LOGFILE"

# Prompt for confirmation
read -p "Do you want to backup settings and set telemetry to off (with automatic updates enabled)? (y/n): " choice
case "$choice" in
    y|Y )
        log_and_print ""
        log_and_print "Backing up current settings to: $BACKUPFILE"
        touch "$BACKUPFILE"
        echo "=== macOS Privacy Settings Backup - $(date) ===" >> "$BACKUPFILE"
        echo "Original User: $ORIG_USER" >> "$BACKUPFILE"
        echo "" >> "$BACKUPFILE"
        
        # Backup all settings
        # 1.1
        backup_system "/Library/Preferences/com.apple.SubmitDiagInfo" "AutoSubmit"
        
        # 1.2
        backup_user "com.apple.CrashReporter" "DialogType"
        
        # 1.3
        backup_system "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticCheckEnabled"
        backup_system "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticDownload"
        
        # 1.4
        backup_user "com.apple.assistant.support" "Assistant Enabled"
        backup_user "com.apple.Siri" "StatusMenuVisible"
        
        # 1.5
        backup_user "com.apple.lookup.shared" "LookupSuggestionsDisabled"
        
        # 1.6
        backup_user "com.apple.UsageTracking" "CoreDonationsEnabled"
        backup_user "com.apple.UsageTracking" "UDCAutomationEnabled"
        
        log_and_print "Backup complete."
        log_and_print ""
        log_and_print "Applying changes..."
        
        # 1.1
        defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false
        log_and_print " • /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit = false"
        
        # 1.2
        su - "$ORIG_USER" -c "defaults write com.apple.CrashReporter DialogType none"
        log_and_print " • com.apple.CrashReporter DialogType = none (for $ORIG_USER)"
        
        # 1.3 (set to enabled)
        defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
        defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
        log_and_print " • /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled = true"
        log_and_print " • /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload = true"
        
        # 1.4
        su - "$ORIG_USER" -c "defaults write com.apple.assistant.support 'Assistant Enabled' -bool false"
        su - "$ORIG_USER" -c "defaults write com.apple.Siri StatusMenuVisible -bool false"
        log_and_print " • com.apple.assistant.support 'Assistant Enabled' = false (for $ORIG_USER)"
        log_and_print " • com.apple.Siri StatusMenuVisible = false (for $ORIG_USER)"
        
        # 1.5
        su - "$ORIG_USER" -c "defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true"
        log_and_print " • com.apple.lookup.shared LookupSuggestionsDisabled = true (for $ORIG_USER)"
        
        # 1.6
        su - "$ORIG_USER" -c "defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false"
        su - "$ORIG_USER" -c "defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false"
        log_and_print " • com.apple.UsageTracking CoreDonationsEnabled = false (for $ORIG_USER)"
        log_and_print " • com.apple.UsageTracking UDCAutomationEnabled = false (for $ORIG_USER)"
        
        log_and_print "Changes applied. Some may require logout/reboot to take effect."
        log_and_print "Backup saved to: $BACKUPFILE"
        ;;
    * )
        log_and_print "No changes or backup applied."
        ;;
esac

log_and_print "Script complete."
