#!/usr/bin/env bash
# Switch command: Switch GitHub auth to matching profile

cmd_switch() {
  local idx
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }
  
  local gh_u
  gh_u=$(profile_get_field "$idx" "gh_username")
  if [[ -z "$gh_u" || "$gh_u" == "null" ]]; then
    echo "No gh_username configured for this profile."
    exit 1
  fi
  gh_auth_switch_user "$gh_u"
}
