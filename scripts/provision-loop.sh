#!/usr/bin/env bash
# Retries `terraform apply` until OCI hands us an A1.Flex host, or the time
# budget runs out. Only "out of host capacity" (and a few genuinely transient
# API errors) are retried; anything else fails immediately so a broken
# credential or quota never hides behind an endless loop.
set -uo pipefail

TF_DIR="${TF_DIR:-terraform}"
MAX_RUNTIME="${MAX_RUNTIME:-19200}"   # 5h20m, inside the 6h runner limit
SLEEP_BASE="${SLEEP_BASE:-60}"
SLEEP_JITTER="${SLEEP_JITTER:-45}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

tf() { terraform -chdir="$TF_DIR" "$@"; }
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

capacity_re='out of host capacity|OutOfCapacity|InternalError[^"]*[Cc]apacity|capacity for the requested|host capacity'
transient_re='"code"[[:space:]]*:[[:space:]]*"InternalError"|"code"[[:space:]]*:[[:space:]]*"TooManyRequests"|"code"[[:space:]]*:[[:space:]]*"ServiceUnavailable"|Please retry'

deadline=$(( SECONDS + MAX_RUNTIME ))
attempt=0

while :; do
  if (( SECONDS >= deadline )); then
    log "Time budget exhausted after $attempt attempts. This is normal in a busy region."
    {
      echo "### No capacity in this window"
      echo ""
      echo "Made **$attempt** attempts without an A1.Flex host being available."
      echo "The next scheduled run picks up where this one stopped - the network"
      echo "resources already exist, so it only retries the instance."
    } >> "$SUMMARY"
    # Not a failure: the schedule will keep trying.
    exit 0
  fi

  attempt=$(( attempt + 1 ))
  log "Attempt #$attempt (${SECONDS}s elapsed)"

  if out=$(tf apply -auto-approve -input=false -no-color -lock-timeout=5m 2>&1); then
    printf '%s\n' "$out"
    log "Instance provisioned."
    exit 0
  fi
  printf '%s\n' "$out" | tail -n 40

  if grep -qiE "$capacity_re" <<<"$out"; then
    log "Out of host capacity."
  elif grep -qiE "$transient_re" <<<"$out" && (( attempt <= 6 )); then
    log "Transient OCI API error, retrying."
  else
    {
      echo "### Provisioning failed"
      echo '```'
      printf '%s\n' "$out" | tail -n 60
      echo '```'
    } >> "$SUMMARY"
    echo "::error::Terraform failed for a reason that will not fix itself. Not retrying."
    if grep -q '401-NotAuthenticated' <<<"$out"; then
      echo "::error::OCI rejected the credentials (401). Check OCI_USER_OCID first: it must be exactly 76 characters and is safest copied from Cloud Shell with echo \$OCI_CS_USER_OCID. Then confirm the OCI_FINGERPRINT value is listed under My profile -> API keys."
    elif grep -qiE 'LimitExceeded|QuotaExceeded' <<<"$out"; then
      echo "::error::This looks like a service limit (Always Free allows 2 VCNs and 2 OCPUs). Delete leftover VCNs under Networking -> Virtual Cloud Networks and retry."
    fi
    exit 1
  fi

  nap=$(( SLEEP_BASE + RANDOM % SLEEP_JITTER ))
  log "Sleeping ${nap}s."
  sleep "$nap"
done
