## B-Backup-AiTools: zips Claude Code memory and MCP config, Codex memories and rules, and the logins of AI and cloud CLIs, plus a restore.ps1 that puts them back
function B-Backup-AiTools {
  [CmdletBinding()]
  param(
    [string]$Output = 'ai-tools-backup.zip',
    [switch]$DryRun
  )

  BBackup-ItemsBackup (BBackupAi-HomeItems) $Output $DryRun
}

# Paths relative to the home folder; linked items (CLAUDE.md, settings.json, skills, hooks,
# codex config and skills) are recreated by the dotfiles install so they are not listed.
# Session transcripts under .claude/projects are left out on purpose, only the memory folders go.
function BBackupAi-HomeItems() {
  return @(
    '.claude.json',
    '.claude/projects/*/memory',
    '.claude/history.jsonl',
    '.claude/statusline-command.ps1',
    '.claude/plugins/known_marketplaces.json',
    '.codex/auth.json',
    '.codex/memories',
    '.codex/memories_1.sqlite*',
    '.codex/rules',
    '.codex/secrets',
    '.codex/history.jsonl',
    '.grok/auth.json',
    '.gemini/oauth_creds.json', '.gemini/settings.json',
    '.copilot/config.json', '.copilot/mcp-config.json', '.copilot/settings.json',
    '.aish/agent-config/*/*.json',
    '.codebuddy.json',
    '.mal-mcp-config.json', '.mal-mcp-tokens.json',
    '.th-client',
    '.rest-client',
    '.config/configstore',
    '.azure/azureProfile.json', '.azure/config',
    'AppData/Roaming/gcloud/credentials.db',
    'AppData/Roaming/gcloud/access_tokens.db',
    'AppData/Roaming/gcloud/application_default_credentials.json',
    'AppData/Roaming/gcloud/active_config',
    'AppData/Roaming/gcloud/configurations',
    'AppData/Roaming/gcloud/legacy_credentials',
    'AppData/Roaming/com.vercel.cli/Data',
    'AppData/Roaming/netlify/Config/config.json'
  )
}
