#!/usr/bin/env bash
# verify-final.sh — optional LocalStack probe after lab 12.
# Usage:
#   ./verify-final.sh --bucket B --lambda L [--invoke]
set -euo pipefail

ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
BUCKET=""
LAMBDA=""
DO_INVOKE=0

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="$REGION"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) BUCKET="$2"; shift 2 ;;
    --lambda) LAMBDA="$2"; shift 2 ;;
    --invoke) DO_INVOKE=1; shift ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --table) shift 2 ;; # ignored (removed from this course)
    -h|--help)
      echo "Usage: $0 --bucket B --lambda L [--invoke]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail=0
ok()  { echo "  OK  $*"; }
bad() { echo "  FAIL $*"; fail=1; }
have() { command -v "$1" >/dev/null 2>&1; }

aws_local() {
  aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"
}

echo "== aws-terraform final verify =="
echo "ENDPOINT=$ENDPOINT"
echo

if ! have curl; then
  echo "curl not found" >&2
  exit 1
fi

echo "-- LocalStack health --"
code=$(curl -sS -o /tmp/ls-health.json -w "%{http_code}" --connect-timeout 3 \
  "$ENDPOINT/_localstack/health" || echo "000")
if [[ "$code" == "200" ]]; then
  ok "health HTTP 200"
else
  bad "health HTTP $code (start LocalStack: see ENVIRONMENT.md / mockctl-setup LOCALSTACK.md)"
fi

if ! have aws; then
  bad "aws CLI not found — install AWS CLI for resource checks"
  echo
  [[ "$fail" -eq 0 ]] && echo "RESULT: PASS (health only)" && exit 0
  echo "RESULT: FAIL"; exit 1
fi

if [[ -z "$BUCKET" || -z "$LAMBDA" ]]; then
  bad "pass --bucket and --lambda (from terraform output)"
  echo "RESULT: FAIL"
  exit 1
fi

echo "-- core resources --"
if aws_local s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  ok "s3 bucket $BUCKET"
else
  bad "s3 bucket $BUCKET missing"
fi

if aws_local lambda get-function --function-name "$LAMBDA" >/dev/null 2>&1; then
  ok "lambda $LAMBDA"
else
  bad "lambda $LAMBDA missing"
fi

if [[ "$DO_INVOKE" -eq 1 ]]; then
  echo "-- invoke smoke --"
  payload='{"filename":"verify.txt"}'
  if aws_local lambda invoke \
      --function-name "$LAMBDA" \
      --cli-binary-format raw-in-base64-out \
      --payload "$payload" \
      /tmp/aws-tf-invoke.json >/dev/null 2>&1 \
    || aws_local lambda invoke \
      --function-name "$LAMBDA" \
      --payload "$payload" \
      /tmp/aws-tf-invoke.json >/dev/null 2>&1; then
    ok "lambda invoke"
  else
    bad "lambda invoke failed"
  fi

  found=0
  for _ in $(seq 1 10); do
    files=$(aws_local s3 ls "s3://$BUCKET/files/" 2>/dev/null || true)
    if [[ -n "$files" ]]; then
      ok "files/ has objects"
      found=1
      break
    fi
    sleep 2
  done
  if [[ "$found" -eq 0 ]]; then
    bad "no files/ objects after invoke (check Lambda logs / IAM)"
  fi
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "RESULT: PASS (LocalStack layer)"
  echo "Still review IAM (trust vs PutObject — see 07–08)."
  exit 0
else
  echo "RESULT: FAIL (see messages above)"
  exit 1
fi
