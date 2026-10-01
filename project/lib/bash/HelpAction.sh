#!/bin/bash
################################################################################
# Command Help Option
################################################################################
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$LIB_DIR/TableHelper.sh" ] && source "$LIB_DIR/TableHelper.sh"

################################################################################
# show_help: Show a clean help summary about each command from cmbackup
################################################################################
function show_help (){
  type init_table_theme &>/dev/null && init_table_theme

  local BOLD="${CLR_BOLD:-}"
  local CYAN="${CLR_BOLD_CYAN:-}"
  local GREEN="${CLR_GREEN:-}"
  local YELLOW="${CLR_BOLD_YELLOW:-}"
  local RESET="${CLR_RESET:-}"

  printf "%bUsage:%b\n" "$BOLD" "$RESET"
  printf "  cmbackup %b-f%b [%b-m%b,%b-dl%b,%b-al%b,%b-ldp%b,%b-sig%b] [%b-d%b,%b-a%b] <mail/domain>\n" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET"
  printf "  cmbackup %b-i%b <mail>\n" "$GREEN" "$RESET"
  printf "  cmbackup %b-r%b [%b-m%b,%b-dl%b,%b-al%b,%b-ldp%b,%b-sig%b] [%b-d%b,%b-a%b] <session> <mail>\n" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET"
  printf "  cmbackup %b-r%b %b-ro%b <session> <mail_origin> <mail_destination>\n" "$GREEN" "$RESET" "$GREEN" "$RESET"
  printf "  cmbackup %b-l%b [-S] [session]\n" "$GREEN" "$RESET"
  printf "  cmbackup %b-c%b [-S] [mail]\n" "$GREEN" "$RESET"
  printf "  cmbackup %b-d%b <session>\n" "$GREEN" "$RESET"
  printf "  cmbackup %b-hp%b\n" "$GREEN" "$RESET"
  printf "  cmbackup %b-m%b\n" "$GREEN" "$RESET"

  printf "\n%bGeneral Options:%b\n" "$CYAN" "$RESET"
  printf "  %b-f,   --full%b                     Execute full backup of an account, list of accounts, or all accounts.\n" "$GREEN" "$RESET"
  printf "  %b-i,   --incremental%b              Execute incremental backup for an account, list of accounts, or all.\n" "$GREEN" "$RESET"
  printf "        %b--since <YYYY-MM-DD>%b       Specify explicit date for incremental backup.\n" "$YELLOW" "$RESET"
  printf "        %b--dry-run%b                  Test run without downloading or writing data.\n" "$YELLOW" "$RESET"
  printf "  %b-c,   --verify [-S] [account]%b    Audit and verify mailbox message count and storage.\n" "$GREEN" "$RESET"
  printf "  %b-l,   --list [-S] [session]%b      List backup sessions, or inspect accounts in a specific session.\n" "$GREEN" "$RESET"
  printf "  %b-S,   --sort-size%b                Sort session list, details, or audit by size (largest first).\n" "$YELLOW" "$RESET"
  printf "        %b--sort-size-asc%b            Sort by size ascending (smallest first).\n" "$YELLOW" "$RESET"
  printf "  %b-r,   --restore%b                  Restore backup data into user accounts.\n" "$GREEN" "$RESET"
  printf "  %b-d,   --delete <session>%b         Delete a specific backup session.\n" "$GREEN" "$RESET"
  printf "  %b-hp,  --housekeep%b                Clean old backups based on retention policy (ROTATE_TIME).\n" "$GREEN" "$RESET"
  printf "  %b-t,   --truncate%b                 Delete all backups and empty database (irreversible).\n" "$GREEN" "$RESET"
  printf "  %b-m,   --migrate%b                  Migrate session catalog between TXT and SQLITE3.\n" "$GREEN" "$RESET"
  printf "  %b-v,   --version%b                  Show cmbackup version.\n" "$GREEN" "$RESET"
  printf "  %b-h,   --help%b                     Show this help message.\n" "$GREEN" "$RESET"

  printf "\n%bFull Backup Filters:%b\n" "$CYAN" "$RESET"
  printf "  %b-m,   --mail%b                     Backup only the mailbox data.\n" "$GREEN" "$RESET"
  printf "  %b-dl,  --distributionlist%b         Backup distribution lists instead of user accounts.\n" "$GREEN" "$RESET"
  printf "  %b-al,  --alias%b                    Backup aliases instead of user accounts.\n" "$GREEN" "$RESET"
  printf "  %b-ldp, --ldap%b                     Backup only LDAP directory entries.\n" "$GREEN" "$RESET"
  printf "  %b-sig, --signature%b                Backup user signatures.\n" "$GREEN" "$RESET"
  printf "  %b-d,   --domain <domains>%b          Comma-separated list of domains to back up.\n" "$GREEN" "$RESET"
  printf "  %b-a,   --account <accounts>%b        Comma-separated list of accounts to back up.\n" "$GREEN" "$RESET"

  printf "\n%bRestore Options:%b\n" "$CYAN" "$RESET"
  printf "  %b-m,   --mail%b                     Restore only the mailbox data.\n" "$GREEN" "$RESET"
  printf "  %b-dl,  --distributionlist%b         Restore distribution lists.\n" "$GREEN" "$RESET"
  printf "  %b-al,  --alias%b                    Restore aliases.\n" "$GREEN" "$RESET"
  printf "  %b-ldp, --ldap%b                     Restore LDAP directory entries.\n" "$GREEN" "$RESET"
  printf "  %b-ro,  --restoreOnAccount%b         Restore one account into another account.\n" "$GREEN" "$RESET"
  printf "  %b-sig, --signature%b                Restore signatures.\n" "$GREEN" "$RESET"
  printf "  %b-d,   --domain <domains>%b          Filter restore by domain.\n" "$GREEN" "$RESET"
  printf "  %b-a,   --account <accounts>%b        Filter restore by account.\n" "$GREEN" "$RESET"
  printf "\n"
}
