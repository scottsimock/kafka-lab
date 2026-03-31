#!/usr/bin/env bash
# validate-dev-environment.sh — End-to-end dev environment health validation
# Checks the full stack: VMs → ZooKeeper → Kafka → Schema Registry → Connect → Function App → Web App → Data Flow
# Outputs structured JSON report to logs/dev-environment-health.json and human summary to stdout.
#
# Usage:
#   ./scripts/validate-dev-environment.sh [OPTIONS]
#
# Options:
#   --from-terraform    Extract IPs/hostnames from Terraform outputs (requires terraform CLI in dev dir)
#   --skip-data-flow    Skip the produce/consume round-trip test
#   --skip-webapp       Skip Function App and web app checks
#   --ssh-user USER     SSH user for VM checks (default: azureuser)
#   --ssh-key PATH      Path to SSH private key (default: ~/.ssh/id_rsa)
#   --ssh-opts OPTS     Extra SSH options (e.g., "-o ProxyJump=bastion")
#   --timeout SEC       Per-check timeout in seconds (default: 15)
#   --help              Show this help
#
# Environment variables (override defaults or --from-terraform):
#   ZK_HOSTS            Comma-separated ZooKeeper IPs (default: 10.1.2.4,10.1.2.5,10.1.2.6)
#   KB_HOSTS            Comma-separated Kafka broker IPs (default: 10.1.1.4,10.1.1.5,10.1.1.6)
#   SR_HOSTS            Comma-separated Schema Registry IPs (default: 10.1.3.4)
#   KC_HOSTS            Comma-separated Kafka Connect IPs (default: 10.1.4.4)
#   FUNCTION_APP_HOST   Function App hostname (e.g., klc-func-kafkalab-dev-scus.azurewebsites.net)
#   ZK_CLIENT_PORT      ZooKeeper client port (default: 2181)
#   KB_CLIENT_PORT      Kafka broker client port (default: 9092)
#   SR_PORT             Schema Registry port (default: 8081)
#   KC_PORT             Kafka Connect port (default: 8083)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/environments/dev"
LOGS_DIR="${REPO_ROOT}/logs"
REPORT_FILE="${LOGS_DIR}/dev-environment-health.json"

# Defaults (static inventory values)
ZK_HOSTS="${ZK_HOSTS:-10.1.2.4,10.1.2.5,10.1.2.6}"
KB_HOSTS="${KB_HOSTS:-10.1.1.4,10.1.1.5,10.1.1.6}"
SR_HOSTS="${SR_HOSTS:-10.1.3.4}"
KC_HOSTS="${KC_HOSTS:-10.1.4.4}"
FUNCTION_APP_HOST="${FUNCTION_APP_HOST:-}"
ZK_CLIENT_PORT="${ZK_CLIENT_PORT:-2181}"
KB_CLIENT_PORT="${KB_CLIENT_PORT:-9092}"
SR_PORT="${SR_PORT:-8081}"
KC_PORT="${KC_PORT:-8083}"

SSH_USER="${SSH_USER:-azureuser}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_rsa}"
SSH_OPTS="${SSH_OPTS:-}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-15}"

FROM_TERRAFORM=false
SKIP_DATA_FLOW=false
SKIP_WEBAPP=false

CONFLUENT_BIN="/opt/confluent/current/bin"
KAFKA_USER="kafka"
VERIFY_TOPIC="kafkalab-e2e-validate"

# Counters
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
START_EPOCH=0

# JSON accumulator for checks array
CHECKS_JSON="[]"

# =====================================================
# Argument parsing
# =====================================================
show_help() {
  head -30 "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

for arg in "$@"; do
  case "${arg}" in
    --from-terraform)  FROM_TERRAFORM=true ;;
    --skip-data-flow)  SKIP_DATA_FLOW=true ;;
    --skip-webapp)     SKIP_WEBAPP=true ;;
    --ssh-user=*)      SSH_USER="${arg#*=}" ;;
    --ssh-key=*)       SSH_KEY="${arg#*=}" ;;
    --ssh-opts=*)      SSH_OPTS="${arg#*=}" ;;
    --timeout=*)       CHECK_TIMEOUT="${arg#*=}" ;;
    --help)            show_help ;;
    *)
      echo "Unknown option: ${arg}" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# =====================================================
# Utilities
# =====================================================
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
ts()  { date -u +%Y-%m-%dT%H:%M:%SZ; }

epoch_ms() {
  if date +%s%N >/dev/null 2>&1; then
    echo $(( $(date +%s%N) / 1000000 ))
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

ssh_cmd() {
  local host="$1"
  shift
  # shellcheck disable=SC2086
  ssh -o StrictHostKeyChecking=no \
      -o ConnectTimeout="${CHECK_TIMEOUT}" \
      -o BatchMode=yes \
      -i "${SSH_KEY}" \
      ${SSH_OPTS} \
      "${SSH_USER}@${host}" "$@" 2>/dev/null
}

# Record a check result into CHECKS_JSON
record_check() {
  local component="$1" check="$2" status="$3" duration_ms="$4" details="${5:-}"
  TOTAL=$((TOTAL + 1))
  case "${status}" in
    PASS) PASSED=$((PASSED + 1)) ;;
    FAIL) FAILED=$((FAILED + 1)) ;;
    SKIP) SKIPPED=$((SKIPPED + 1)) ;;
  esac

  local entry
  entry=$(printf '{"component":"%s","check":"%s","status":"%s","duration_ms":%d' \
    "${component}" "${check}" "${status}" "${duration_ms}")
  if [[ -n "${details}" ]]; then
    # Escape double quotes and backslashes in details
    local safe_details
    safe_details=$(echo "${details}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    entry="${entry},\"details\":\"${safe_details}\""
  fi
  entry="${entry}}"

  CHECKS_JSON=$(echo "${CHECKS_JSON}" | sed "s/]$/,${entry}]/" | sed 's/\[,/[/')
}

# Run a single check with timing
run_check() {
  local component="$1" check_name="$2"
  shift 2
  local start_ms end_ms duration_ms output rc
  start_ms=$(epoch_ms)

  output=$("$@" 2>&1)
  rc=$?

  end_ms=$(epoch_ms)
  duration_ms=$((end_ms - start_ms))

  if [[ ${rc} -eq 0 ]]; then
    record_check "${component}" "${check_name}" "PASS" "${duration_ms}" "${output}"
    printf "  ✅  %-30s %-35s PASS  (%d ms)\n" "${component}" "${check_name}" "${duration_ms}"
  else
    record_check "${component}" "${check_name}" "FAIL" "${duration_ms}" "${output}"
    printf "  ❌  %-30s %-35s FAIL  (%d ms)\n" "${component}" "${check_name}" "${duration_ms}"
  fi
  return ${rc}
}

skip_check() {
  local component="$1" check_name="$2" reason="${3:-skipped}"
  record_check "${component}" "${check_name}" "SKIP" 0 "${reason}"
  printf "  ⏭️  %-30s %-35s SKIP  (%s)\n" "${component}" "${check_name}" "${reason}"
}

# =====================================================
# Terraform output extraction
# =====================================================
if [[ "${FROM_TERRAFORM}" == "true" ]]; then
  log "Extracting endpoints from Terraform outputs..."
  if ! command -v terraform >/dev/null 2>&1; then
    log "ERROR: terraform not found but --from-terraform specified"
    exit 1
  fi
  cd "${TF_DIR}" || exit 1

  extract_ips() {
    terraform output -json "$1" 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(v for _,v in sorted(d.items())))" 2>/dev/null
  }

  ZK_HOSTS=$(extract_ips zookeeper_private_ips)
  KB_HOSTS=$(extract_ips kafka_broker_private_ips)
  SR_HOSTS=$(extract_ips schema_registry_private_ips)
  KC_HOSTS=$(extract_ips kafka_connect_private_ips)
  FUNCTION_APP_HOST=$(terraform output -raw function_app_hostname 2>/dev/null || echo "")
  cd "${REPO_ROOT}" || exit 1
  log "Extracted: ZK=${ZK_HOSTS} KB=${KB_HOSTS} SR=${SR_HOSTS} KC=${KC_HOSTS} FuncApp=${FUNCTION_APP_HOST}"
fi

# Convert comma-separated lists to arrays
IFS=',' read -ra ZK_ARRAY <<< "${ZK_HOSTS}"
IFS=',' read -ra KB_ARRAY <<< "${KB_HOSTS}"
IFS=',' read -ra SR_ARRAY <<< "${SR_HOSTS}"
IFS=',' read -ra KC_ARRAY <<< "${KC_HOSTS}"

mkdir -p "${LOGS_DIR}"

# =====================================================
# Validation begins
# =====================================================
log "=========================================="
log " Dev Environment E2E Validation"
log "=========================================="
log "ZooKeeper:      ${ZK_HOSTS} (port ${ZK_CLIENT_PORT})"
log "Kafka Brokers:  ${KB_HOSTS} (port ${KB_CLIENT_PORT})"
log "Schema Registry: ${SR_HOSTS} (port ${SR_PORT})"
log "Kafka Connect:  ${KC_HOSTS} (port ${KC_PORT})"
log "Function App:   ${FUNCTION_APP_HOST:-not configured}"
log "SSH User:       ${SSH_USER}"
log "Check Timeout:  ${CHECK_TIMEOUT}s"
log "=========================================="
echo ""

START_EPOCH=$(date +%s)

# =====================================================
# Phase 1: VM SSH Reachability
# =====================================================
log "--- Phase 1: VM Reachability ---"

check_ssh() {
  local host="$1"
  ssh_cmd "${host}" "echo ok"
}

for ip in "${ZK_ARRAY[@]}"; do
  run_check "vm-zk-${ip}" "ssh-reachable" check_ssh "${ip}" || true
done
for ip in "${KB_ARRAY[@]}"; do
  run_check "vm-kb-${ip}" "ssh-reachable" check_ssh "${ip}" || true
done
for ip in "${SR_ARRAY[@]}"; do
  run_check "vm-sr-${ip}" "ssh-reachable" check_ssh "${ip}" || true
done
for ip in "${KC_ARRAY[@]}"; do
  run_check "vm-kc-${ip}" "ssh-reachable" check_ssh "${ip}" || true
done
echo ""

# =====================================================
# Phase 2: ZooKeeper Health
# =====================================================
log "--- Phase 2: ZooKeeper Ensemble ---"

check_zk_ruok() {
  local host="$1"
  local result
  result=$(ssh_cmd "${host}" "echo ruok | nc -w 5 localhost ${ZK_CLIENT_PORT}")
  [[ "${result}" == "imok" ]]
}

check_zk_mode() {
  local host="$1"
  local stat_output
  stat_output=$(ssh_cmd "${host}" "echo stat | nc -w 5 localhost ${ZK_CLIENT_PORT}")
  echo "${stat_output}" | grep -q "Mode:"
  local rc=$?
  local mode
  mode=$(echo "${stat_output}" | grep "Mode:" | head -1 | awk '{print $2}')
  echo "${mode}"
  return ${rc}
}

check_zk_quorum() {
  local leader_count=0 follower_count=0
  for ip in "${ZK_ARRAY[@]}"; do
    local stat_output
    stat_output=$(ssh_cmd "${ip}" "echo stat | nc -w 5 localhost ${ZK_CLIENT_PORT}" 2>/dev/null || true)
    local mode
    mode=$(echo "${stat_output}" | grep "Mode:" | awk '{print $2}')
    case "${mode}" in
      leader)   leader_count=$((leader_count + 1)) ;;
      follower) follower_count=$((follower_count + 1)) ;;
    esac
  done
  local total=$((leader_count + follower_count))
  echo "${leader_count} leader, ${follower_count} follower (${total}/${#ZK_ARRAY[@]} in quorum)"
  [[ ${leader_count} -eq 1 && ${total} -ge 2 ]]
}

for ip in "${ZK_ARRAY[@]}"; do
  run_check "zk-${ip}" "ruok" check_zk_ruok "${ip}" || true
  run_check "zk-${ip}" "mode-check" check_zk_mode "${ip}" || true
done

run_check "zk-ensemble" "quorum" check_zk_quorum || true
echo ""

# =====================================================
# Phase 3: Kafka Cluster Health
# =====================================================
log "--- Phase 3: Kafka Cluster ---"

FIRST_BROKER="${KB_ARRAY[0]}"
BOOTSTRAP_SERVERS=$(printf "%s:${KB_CLIENT_PORT}," "${KB_ARRAY[@]}" | sed 's/,$//')

check_kafka_api() {
  ssh_cmd "${FIRST_BROKER}" \
    "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-broker-api-versions --bootstrap-server localhost:${KB_CLIENT_PORT}" \
    >/dev/null 2>&1
}

check_kafka_brokers_isr() {
  local metadata
  metadata=$(ssh_cmd "${FIRST_BROKER}" \
    "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-metadata --snapshot /var/kafka-logs/__cluster_metadata-0/00000000000000000000.log --broker-count 2>/dev/null || \
     sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-topics --bootstrap-server localhost:${KB_CLIENT_PORT} --describe --under-replicated-partitions 2>/dev/null")
  local expected=${#KB_ARRAY[@]}
  # Check via broker list query
  local broker_list
  broker_list=$(ssh_cmd "${FIRST_BROKER}" \
    "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-broker-api-versions --bootstrap-server localhost:${KB_CLIENT_PORT} 2>/dev/null" \
    | grep -c "^[0-9]" || echo 0)
  echo "${broker_list}/${expected} brokers responding"
  [[ "${broker_list}" -ge "${expected}" ]]
}

check_kafka_controller() {
  local desc
  desc=$(ssh_cmd "${FIRST_BROKER}" \
    "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-metadata --snapshot /var/kafka-logs/__cluster_metadata-0/00000000000000000000.log --status 2>/dev/null || \
     echo 'controller check via topic list' && \
     sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-topics --bootstrap-server localhost:${KB_CLIENT_PORT} --list >/dev/null 2>&1 && echo 'controller elected'")
  echo "${desc}"
  echo "${desc}" | grep -qi "controller\|elected\|leader"
}

check_kafka_under_replicated() {
  local ur
  ur=$(ssh_cmd "${FIRST_BROKER}" \
    "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-topics --bootstrap-server localhost:${KB_CLIENT_PORT} --describe --under-replicated-partitions 2>/dev/null")
  local count
  count=$(echo "${ur}" | grep -c "Topic:" || echo 0)
  echo "${count} under-replicated partitions"
  [[ "${count}" -eq 0 ]]
}

run_check "kafka-cluster" "broker-api" check_kafka_api || true
run_check "kafka-cluster" "brokers-in-isr" check_kafka_brokers_isr || true
run_check "kafka-cluster" "controller-elected" check_kafka_controller || true
run_check "kafka-cluster" "under-replicated" check_kafka_under_replicated || true
echo ""

# =====================================================
# Phase 4: Schema Registry Health
# =====================================================
log "--- Phase 4: Schema Registry ---"

check_sr_subjects() {
  local host="$1"
  local response
  response=$(ssh_cmd "${host}" "curl -sf -m ${CHECK_TIMEOUT} http://localhost:${SR_PORT}/subjects")
  echo "${response}" | python3 -c "import json,sys; json.load(sys.stdin); print('subjects endpoint ok')" 2>/dev/null
}

check_sr_config() {
  local host="$1"
  local response
  response=$(ssh_cmd "${host}" "curl -sf -m ${CHECK_TIMEOUT} http://localhost:${SR_PORT}/config")
  echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('compatibility=' + d.get('compatibilityLevel','unknown'))" 2>/dev/null
}

for ip in "${SR_ARRAY[@]}"; do
  run_check "sr-${ip}" "subjects-endpoint" check_sr_subjects "${ip}" || true
  run_check "sr-${ip}" "config-endpoint" check_sr_config "${ip}" || true
done
echo ""

# =====================================================
# Phase 5: Kafka Connect Health
# =====================================================
log "--- Phase 5: Kafka Connect ---"

check_kc_root() {
  local host="$1"
  local response
  response=$(ssh_cmd "${host}" "curl -sf -m ${CHECK_TIMEOUT} http://localhost:${KC_PORT}/")
  echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('version=' + d.get('version','unknown'))" 2>/dev/null
}

check_kc_plugins() {
  local host="$1"
  local response
  response=$(ssh_cmd "${host}" "curl -sf -m ${CHECK_TIMEOUT} http://localhost:${KC_PORT}/connector-plugins")
  local count
  count=$(echo "${response}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
  echo "${count} plugins loaded"
  [[ "${count}" -gt 0 ]]
}

check_kc_connectors() {
  local host="$1"
  local response
  response=$(ssh_cmd "${host}" "curl -sf -m ${CHECK_TIMEOUT} http://localhost:${KC_PORT}/connectors")
  echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(len(d)) + ' connectors')" 2>/dev/null
}

for ip in "${KC_ARRAY[@]}"; do
  run_check "connect-${ip}" "root-endpoint" check_kc_root "${ip}" || true
  run_check "connect-${ip}" "connector-plugins" check_kc_plugins "${ip}" || true
  run_check "connect-${ip}" "connectors-list" check_kc_connectors "${ip}" || true
done
echo ""

# =====================================================
# Phase 6: Function App Health
# =====================================================
log "--- Phase 6: Function App ---"

if [[ "${SKIP_WEBAPP}" == "true" || -z "${FUNCTION_APP_HOST}" ]]; then
  skip_check "function-app" "health-endpoint" "${SKIP_WEBAPP:+skipped by flag}${FUNCTION_APP_HOST:+no hostname configured}"
  skip_check "function-app" "api-cluster" "depends on health-endpoint"
else
  check_funcapp_health() {
    local response
    response=$(curl -sf -m "${CHECK_TIMEOUT}" "https://${FUNCTION_APP_HOST}/api/cluster" 2>/dev/null)
    echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('cluster API ok')" 2>/dev/null
  }

  check_funcapp_page() {
    local status
    status=$(curl -so /dev/null -w "%{http_code}" -m "${CHECK_TIMEOUT}" "https://${FUNCTION_APP_HOST}/" 2>/dev/null)
    echo "HTTP ${status}"
    [[ "${status}" == "200" ]]
  }

  run_check "function-app" "health-endpoint" check_funcapp_health || true
  run_check "function-app" "page-load" check_funcapp_page || true
fi
echo ""

# =====================================================
# Phase 7: Web App Accessibility
# =====================================================
log "--- Phase 7: Web App Pages ---"

if [[ "${SKIP_WEBAPP}" == "true" || -z "${FUNCTION_APP_HOST}" ]]; then
  skip_check "webapp" "overview-page" "webapp checks skipped"
  skip_check "webapp" "topics-page" "webapp checks skipped"
  skip_check "webapp" "schemas-page" "webapp checks skipped"
else
  check_webapp_page() {
    local path="$1"
    local status
    status=$(curl -so /dev/null -w "%{http_code}" -m "${CHECK_TIMEOUT}" "https://${FUNCTION_APP_HOST}${path}" 2>/dev/null)
    echo "HTTP ${status}"
    [[ "${status}" == "200" ]]
  }

  run_check "webapp" "overview-page" check_webapp_page "/dashboard/overview" || true
  run_check "webapp" "topics-page" check_webapp_page "/dashboard/topics" || true
  run_check "webapp" "schemas-page" check_webapp_page "/dashboard/schemas" || true
fi
echo ""

# =====================================================
# Phase 8: Data Flow Validation (produce → consume)
# =====================================================
log "--- Phase 8: Data Flow ---"

if [[ "${SKIP_DATA_FLOW}" == "true" ]]; then
  skip_check "data-flow" "produce" "skipped by flag"
  skip_check "data-flow" "consume" "skipped by flag"
  skip_check "data-flow" "round-trip" "skipped by flag"
else
  VERIFY_MSG="e2e-validate-$(date +%s)-${RANDOM}"

  check_data_produce() {
    ssh_cmd "${FIRST_BROKER}" \
      "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-topics --bootstrap-server localhost:${KB_CLIENT_PORT} --create --if-not-exists --topic ${VERIFY_TOPIC} --partitions 3 --replication-factor 1 2>/dev/null && \
       printf '${VERIFY_MSG}\n' | sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-console-producer --bootstrap-server localhost:${KB_CLIENT_PORT} --topic ${VERIFY_TOPIC} 2>/dev/null"
    echo "produced: ${VERIFY_MSG}"
  }

  check_data_consume() {
    local consumed
    consumed=$(ssh_cmd "${FIRST_BROKER}" \
      "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-console-consumer --bootstrap-server localhost:${KB_CLIENT_PORT} --topic ${VERIFY_TOPIC} --from-beginning --max-messages 20 --timeout-ms 15000 2>/dev/null")
    echo "${consumed}" | grep -q "${VERIFY_MSG}"
    local rc=$?
    local count
    count=$(echo "${consumed}" | wc -l)
    echo "consumed ${count} messages, match=$([ ${rc} -eq 0 ] && echo 'yes' || echo 'no')"
    return ${rc}
  }

  check_data_round_trip() {
    local unique="round-trip-$(date +%s%N)"
    ssh_cmd "${FIRST_BROKER}" \
      "printf '${unique}\n' | sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-console-producer --bootstrap-server localhost:${KB_CLIENT_PORT} --topic ${VERIFY_TOPIC} 2>/dev/null"
    sleep 2
    local consumed
    consumed=$(ssh_cmd "${FIRST_BROKER}" \
      "sudo -u ${KAFKA_USER} ${CONFLUENT_BIN}/kafka-console-consumer --bootstrap-server localhost:${KB_CLIENT_PORT} --topic ${VERIFY_TOPIC} --from-beginning --max-messages 50 --timeout-ms 15000 2>/dev/null")
    echo "${consumed}" | grep -q "${unique}"
    local rc=$?
    echo "round-trip message: $([ ${rc} -eq 0 ] && echo 'verified' || echo 'NOT FOUND')"
    return ${rc}
  }

  run_check "data-flow" "produce" check_data_produce || true
  run_check "data-flow" "consume" check_data_consume || true
  run_check "data-flow" "round-trip" check_data_round_trip || true
fi
echo ""

# =====================================================
# Generate report
# =====================================================
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

if [[ ${FAILED} -gt 0 ]]; then
  OVERALL="FAIL"
  EXIT_CODE=1
else
  OVERALL="PASS"
  EXIT_CODE=0
fi

REPORT=$(cat <<EOF
{
  "timestamp": "$(ts)",
  "environment": "dev",
  "overall_status": "${OVERALL}",
  "duration_seconds": ${DURATION},
  "checks": ${CHECKS_JSON},
  "summary": {
    "total": ${TOTAL},
    "passed": ${PASSED},
    "failed": ${FAILED},
    "skipped": ${SKIPPED}
  }
}
EOF
)

# Pretty-print with python3 if available, fall back to raw output
if command -v python3 >/dev/null 2>&1; then
  echo "${REPORT}" | python3 -m json.tool > "${REPORT_FILE}" 2>/dev/null || echo "${REPORT}" > "${REPORT_FILE}"
else
  echo "${REPORT}" > "${REPORT_FILE}"
fi

# =====================================================
# Human summary
# =====================================================
echo ""
log "=========================================="
log " Validation Summary"
log "=========================================="
log " Status:   ${OVERALL}"
log " Duration: ${DURATION}s"
log " Checks:   ${TOTAL} total, ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
log " Report:   ${REPORT_FILE}"
log "=========================================="

if [[ ${FAILED} -gt 0 ]]; then
  log ""
  log "FAILED CHECKS:"
  echo "${CHECKS_JSON}" | python3 -c "
import json, sys
checks = json.load(sys.stdin)
for c in checks:
    if c['status'] == 'FAIL':
        details = c.get('details', '')
        print(f\"  ❌ {c['component']}/{c['check']}: {details}\")
" 2>/dev/null || true
fi

exit ${EXIT_CODE}
