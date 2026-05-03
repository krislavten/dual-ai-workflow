#!/bin/bash

# Dual AI Workflow — Unit Tests
# Run: bash tests/test-unit.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOW="$PROJECT_DIR/bin/workflow"
AGENTS_DIR="$PROJECT_DIR/agents"

# Test workspace
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

# ─── Test helpers ────────────────────────────────────────────

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        ((FAIL++))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc"
        echo "    expected to contain: $needle"
        echo "    actual: ${haystack:0:200}"
        ((FAIL++))
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        echo "  ✓ $desc"
        ((PASS++))
    else
        echo "  ✗ $desc — file not found: $path"
        ((FAIL++))
    fi
}

# Source workflow functions (need to set up env first)
source_workflow_funcs() {
    # Override dirs to use temp space
    export PROJECT_ROOT="$TMP_DIR/project"
    export WORKFLOW_DIR="$TMP_DIR/project/.workflow"
    export PLANS_DIR="$TMP_DIR/project/.workflow/plans"
    export AGENTS_DIR="$PROJECT_DIR/agents"
    mkdir -p "$PROJECT_ROOT" "$WORKFLOW_DIR" "$PLANS_DIR"

    # Source the workflow script but replace main() and set -euo to prevent issues
    eval "$(sed -e 's/^main "$@"/# main disabled for testing/' \
                 -e 's/^set -euo pipefail/# set disabled for testing/' \
                 "$WORKFLOW")"
}

# ─── Tests ───────────────────────────────────────────────────

echo "=== load_agent_config ==="

test_load_config_real_file() {
    source_workflow_funcs
    load_agent_config "cursor"
    assert_eq "loads model from cursor.md" "gpt-5.3-codex-xhigh" "$AGENT_MODEL"
    assert_contains "loads system prompt" "严格的代码审查专家" "$AGENT_SYSTEM_PROMPT"
    assert_contains "prompt includes APPROVE format" "APPROVE" "$AGENT_SYSTEM_PROMPT"
    assert_contains "prompt includes CONCERNS format" "CONCERNS" "$AGENT_SYSTEM_PROMPT"
}
test_load_config_real_file

test_load_config_missing_file() {
    source_workflow_funcs
    load_agent_config "nonexistent" 2>/dev/null
    assert_eq "falls back to default model" "gpt-5.3-codex" "$AGENT_MODEL"
    assert_eq "empty system prompt" "" "$AGENT_SYSTEM_PROMPT"
}
test_load_config_missing_file

test_load_config_custom() {
    source_workflow_funcs
    # Create a custom agent config
    local custom_dir="$TMP_DIR/custom_agents"
    mkdir -p "$custom_dir"
    cat > "$custom_dir/test-agent.md" <<'EOF'
# Test Agent

## Model

model: opus-4.6-thinking

## System Prompt

You are a test agent.
Be helpful.
EOF
    AGENTS_DIR="$custom_dir"
    load_agent_config "test-agent"
    assert_eq "parses custom model" "opus-4.6-thinking" "$AGENT_MODEL"
    assert_contains "parses custom prompt" "test agent" "$AGENT_SYSTEM_PROMPT"

    # Restore
    AGENTS_DIR="$PROJECT_DIR/agents"
}
test_load_config_custom

echo ""
echo "=== update_meta ==="

test_update_meta_simple() {
    source_workflow_funcs
    local task_dir="$TMP_DIR/meta-test-1"
    mkdir -p "$task_dir"
    echo '{"status":"pending","steps":{"proposal":"pending"}}' > "$task_dir/meta.json"

    update_meta "$task_dir" '.status = "done"'
    local result
    result=$(jq -r '.status' "$task_dir/meta.json")
    assert_eq "simple update" "done" "$result"
}
test_update_meta_simple

test_update_meta_with_arg() {
    source_workflow_funcs
    local task_dir="$TMP_DIR/meta-test-2"
    mkdir -p "$task_dir"
    echo '{"status":"pending"}' > "$task_dir/meta.json"

    update_meta "$task_dir" --arg cid "abc-123" '.agent_chat_id = $cid'
    local result
    result=$(jq -r '.agent_chat_id' "$task_dir/meta.json")
    assert_eq "update with --arg" "abc-123" "$result"
}
test_update_meta_with_arg

test_update_meta_chained() {
    source_workflow_funcs
    local task_dir="$TMP_DIR/meta-test-3"
    mkdir -p "$task_dir"
    echo '{"steps":{"proposal":"pending","review":"pending"}}' > "$task_dir/meta.json"

    update_meta "$task_dir" '.steps.proposal = "done" | .steps.review = "approved"'
    local p r
    p=$(jq -r '.steps.proposal' "$task_dir/meta.json")
    r=$(jq -r '.steps.review' "$task_dir/meta.json")
    assert_eq "chained update — proposal" "done" "$p"
    assert_eq "chained update — review" "approved" "$r"
}
test_update_meta_chained

echo ""
echo "=== sync_to_issue ==="

test_sync_to_issue_no_issue() {
    source_workflow_funcs
    local task_dir="$TMP_DIR/sync-test-1"
    mkdir -p "$task_dir"
    echo '{"status":"pending"}' > "$task_dir/meta.json"

    # Should return 0 silently when no issue_number
    local result
    result=$(sync_to_issue "$task_dir" "Claude" "Test" "body" 2>&1)
    assert_eq "no-op when no issue_number" "" "$result"
}
test_sync_to_issue_no_issue

echo ""
echo "=== create_task ==="

test_create_task_structure() {
    source_workflow_funcs
    # Mock check_agent and init_agent_session to avoid real agent calls
    check_agent() { return 0; }
    init_agent_session() { return 0; }

    create_task "test-task" "claude" > /dev/null 2>&1

    # Find the created task dir
    local task_dir
    task_dir=$(ls -d "$PLANS_DIR"/*-test-task 2>/dev/null | head -1)

    assert_file_exists "task dir created" "$task_dir/meta.json"
    assert_file_exists "task.md created" "$task_dir/task.md"

    local executor reviewer status
    executor=$(jq -r '.executor' "$task_dir/meta.json")
    reviewer=$(jq -r '.reviewer' "$task_dir/meta.json")
    status=$(jq -r '.status' "$task_dir/meta.json")
    assert_eq "executor is claude" "claude" "$executor"
    assert_eq "reviewer is cursor" "cursor" "$reviewer"
    assert_eq "initial status is proposal" "proposal" "$status"
}
test_create_task_structure

test_create_task_cursor_executor() {
    source_workflow_funcs
    check_agent() { return 0; }
    init_agent_session() { return 0; }

    create_task "cursor-task" "cursor" > /dev/null 2>&1

    local task_dir
    task_dir=$(ls -d "$PLANS_DIR"/*-cursor-task 2>/dev/null | head -1)

    local executor reviewer
    executor=$(jq -r '.executor' "$task_dir/meta.json")
    reviewer=$(jq -r '.reviewer' "$task_dir/meta.json")
    assert_eq "executor is cursor" "cursor" "$executor"
    assert_eq "reviewer follows default backend(cursor)" "cursor" "$reviewer"
}
test_create_task_cursor_executor

test_create_task_codex_backend() {
    source_workflow_funcs
    check_agent() { return 0; }
    init_agent_session() { return 0; }

    WORKFLOW_REVIEW_BACKEND=codex create_task "codex-task" "claude" > /dev/null 2>&1

    local task_dir
    task_dir=$(ls -d "$PLANS_DIR"/*-codex-task 2>/dev/null | head -1)

    local reviewer
    reviewer=$(jq -r '.reviewer' "$task_dir/meta.json")
    assert_eq "reviewer follows codex backend" "codex" "$reviewer"
}
test_create_task_codex_backend

echo ""
echo "=== validate_task_name ==="

test_validate_task_name_valid() {
    source_workflow_funcs
    validate_task_name "my-task-123" 2>/dev/null
    assert_eq "valid name passes" "0" "$?"
}
test_validate_task_name_valid

test_validate_task_name_invalid() {
    source_workflow_funcs
    local result
    result=$(validate_task_name "my task!" 2>&1) && status=0 || status=$?
    assert_eq "invalid name fails" "1" "$status"
}
test_validate_task_name_invalid

echo ""
echo "=== parse_project_url ==="

test_parse_org_url() {
    source_workflow_funcs
    ISSUE_PROJECT_OWNER="" ISSUE_PROJECT_NUMBER=""
    parse_project_url "https://github.com/orgs/kanyun-inc/projects/3"
    assert_eq "org URL — owner" "kanyun-inc" "$ISSUE_PROJECT_OWNER"
    assert_eq "org URL — number" "3" "$ISSUE_PROJECT_NUMBER"
}
test_parse_org_url

test_parse_user_url() {
    source_workflow_funcs
    ISSUE_PROJECT_OWNER="" ISSUE_PROJECT_NUMBER=""
    parse_project_url "https://github.com/users/kris/projects/7"
    assert_eq "user URL — owner" "kris" "$ISSUE_PROJECT_OWNER"
    assert_eq "user URL — number" "7" "$ISSUE_PROJECT_NUMBER"
}
test_parse_user_url

test_parse_invalid_url() {
    source_workflow_funcs
    local status=0
    parse_project_url "https://github.com/kanyun-inc/rush" 2>/dev/null || status=$?
    assert_eq "invalid URL fails" "1" "$status"
}
test_parse_invalid_url

test_no_project_graceful() {
    source_workflow_funcs
    ISSUE_PROJECT_OWNER="" ISSUE_PROJECT_NUMBER=""
    # get_project_item_id should return 1 silently
    local status=0
    get_project_item_id "123" 2>/dev/null || status=$?
    assert_eq "no project config — skips gracefully" "1" "$status"
}
test_no_project_graceful

echo ""
echo "=== review backend ==="

test_review_backend_default() {
    source_workflow_funcs
    unset WORKFLOW_REVIEW_BACKEND
    local backend
    backend=$(get_review_backend)
    assert_eq "default review backend" "cursor" "$backend"
}
test_review_backend_default

test_review_backend_codex() {
    source_workflow_funcs
    local backend
    backend=$(WORKFLOW_REVIEW_BACKEND=codex get_review_backend)
    assert_eq "codex review backend" "codex" "$backend"
}
test_review_backend_codex

test_review_backend_invalid() {
    source_workflow_funcs
    local status=0
    WORKFLOW_REVIEW_BACKEND=foo get_review_backend 2>/dev/null || status=$?
    assert_eq "invalid backend fails" "1" "$status"
}
test_review_backend_invalid

test_review_backend_glm() {
    source_workflow_funcs
    local backend
    backend=$(WORKFLOW_REVIEW_BACKEND=glm get_review_backend)
    assert_eq "glm review backend" "glm" "$backend"
}
test_review_backend_glm

test_review_backend_glm_uppercase() {
    source_workflow_funcs
    local backend
    backend=$(WORKFLOW_REVIEW_BACKEND=GLM get_review_backend)
    assert_eq "glm backend case-insensitive" "glm" "$backend"
}
test_review_backend_glm_uppercase

echo ""
echo "=== fallback backend ==="

test_fallback_unset() {
    source_workflow_funcs
    unset WORKFLOW_REVIEW_BACKEND_FALLBACK
    local fb
    fb=$(get_review_backend_fallback)
    assert_eq "no fallback when unset" "" "$fb"
}
test_fallback_unset

test_fallback_glm() {
    source_workflow_funcs
    local fb
    fb=$(WORKFLOW_REVIEW_BACKEND_FALLBACK=glm get_review_backend_fallback)
    assert_eq "fallback glm" "glm" "$fb"
}
test_fallback_glm

test_fallback_invalid() {
    source_workflow_funcs
    local status=0
    WORKFLOW_REVIEW_BACKEND_FALLBACK=bogus get_review_backend_fallback 2>/dev/null || status=$?
    assert_eq "invalid fallback fails" "1" "$status"
}
test_fallback_invalid

test_reviewer_label_glm() {
    source_workflow_funcs
    local label
    label=$(reviewer_label_for_backend "glm")
    assert_eq "glm label" "GLM" "$label"
}
test_reviewer_label_glm

echo ""
echo "=== call_reviewer fallback behavior ==="

test_call_reviewer_fallback_triggers() {
    source_workflow_funcs
    # 主 backend 失败 → 备 backend 成功 → 应返回备的结果
    _call_backend() {
        local backend="$1"
        if [[ "$backend" == "cursor" ]]; then
            echo "cursor failed" >&2
            return 1
        fi
        if [[ "$backend" == "glm" ]]; then
            echo "APPROVE from glm"
            return 0
        fi
        return 1
    }

    local result
    result=$(WORKFLOW_REVIEW_BACKEND=cursor WORKFLOW_REVIEW_BACKEND_FALLBACK=glm \
        call_reviewer "test prompt" "" 2>/dev/null)
    assert_eq "fallback to glm on primary failure" "APPROVE from glm" "$result"
}
test_call_reviewer_fallback_triggers

test_call_reviewer_no_fallback_fails() {
    source_workflow_funcs
    _call_backend() {
        echo "failed" >&2
        return 1
    }

    local status=0
    WORKFLOW_REVIEW_BACKEND=cursor call_reviewer "p" "" >/dev/null 2>&1 || status=$?
    assert_eq "no fallback, main fails → return non-zero" "1" "$status"
}
test_call_reviewer_no_fallback_fails

test_call_reviewer_primary_success_skips_fallback() {
    source_workflow_funcs
    local fallback_called=0
    _call_backend() {
        local backend="$1"
        if [[ "$backend" == "cursor" ]]; then
            echo "APPROVE from cursor"
            return 0
        fi
        fallback_called=1
        return 0
    }

    local result
    result=$(WORKFLOW_REVIEW_BACKEND=cursor WORKFLOW_REVIEW_BACKEND_FALLBACK=glm \
        call_reviewer "p" "" 2>/dev/null)
    assert_eq "primary success returns primary result" "APPROVE from cursor" "$result"
    assert_eq "fallback not invoked on primary success" "0" "$fallback_called"
}
test_call_reviewer_primary_success_skips_fallback

test_call_reviewer_same_primary_fallback() {
    source_workflow_funcs
    _call_backend() {
        return 1
    }

    local status=0
    WORKFLOW_REVIEW_BACKEND=glm WORKFLOW_REVIEW_BACKEND_FALLBACK=glm \
        call_reviewer "p" "" >/dev/null 2>&1 || status=$?
    assert_eq "same primary/fallback — fails without extra retry" "1" "$status"
}
test_call_reviewer_same_primary_fallback

echo ""
echo "=== check_glm ==="

test_check_glm_no_key() {
    source_workflow_funcs
    local status=0
    ( unset WORKFLOW_GLM_API_KEY; check_glm ) 2>/dev/null || status=$?
    assert_eq "check_glm fails without API key" "1" "$status"
}
test_check_glm_no_key

test_check_glm_with_key() {
    source_workflow_funcs
    WORKFLOW_GLM_API_KEY="fake.key" check_glm 2>/dev/null
    assert_eq "check_glm passes with API key" "0" "$?"
}
test_check_glm_with_key

echo ""
echo "=== glm response parsing (jq expression) ==="

# 防止 Sparring CONCERN 3 回归：content="" 时 jq `//` 不会回退到 reasoning_content
test_glm_jq_content_present() {
    local fixture='{"choices":[{"message":{"content":"APPROVE\n理由","reasoning_content":"思考"}}]}'
    local result
    result=$(echo "$fixture" | jq -r '.choices[0].message.content // empty')
    assert_eq "非空 content 正常返回" "APPROVE
理由" "$result"
}
test_glm_jq_content_present

test_glm_jq_empty_content_does_not_fallback_to_reasoning() {
    # content="" 时，代码不应兜底到 reasoning_content（思考链不是 review 格式）
    local fixture='{"choices":[{"message":{"content":"","reasoning_content":"1. 思考"}}]}'
    local result
    result=$(echo "$fixture" | jq -r '.choices[0].message.content // empty')
    # 预期空字符串（不是 "1. 思考"）
    assert_eq "content='' 不兜底到 reasoning_content" "" "$result"
}
test_glm_jq_empty_content_does_not_fallback_to_reasoning

test_glm_jq_detect_reasoning_exhausted() {
    # 当 content 空但 reasoning 非空时，测 has_reasoning 检测
    local fixture='{"choices":[{"message":{"content":"","reasoning_content":"abc"}}]}'
    local has_reasoning
    has_reasoning=$(echo "$fixture" | jq -r '(.choices[0].message.reasoning_content // "") | length > 0')
    assert_eq "检测到 reasoning 被用尽" "true" "$has_reasoning"
}
test_glm_jq_detect_reasoning_exhausted

echo ""
echo "=== _agent_attempts ==="

test_agent_attempts_default() {
    source_workflow_funcs
    unset AGENT_RETRIES
    local attempts
    attempts=$(AGENT_RETRIES=1 _agent_attempts)
    assert_eq "RETRIES=1 → 2 次尝试" "2" "$attempts"
}
test_agent_attempts_default

test_agent_attempts_zero_retries() {
    source_workflow_funcs
    local attempts
    attempts=$(AGENT_RETRIES=0 _agent_attempts)
    assert_eq "RETRIES=0 → 1 次尝试（不重试）" "1" "$attempts"
}
test_agent_attempts_zero_retries

test_agent_attempts_multi() {
    source_workflow_funcs
    local attempts
    attempts=$(AGENT_RETRIES=3 _agent_attempts)
    assert_eq "RETRIES=3 → 4 次尝试" "4" "$attempts"
}
test_agent_attempts_multi

echo ""
echo "=== commands/ frontmatter ==="

test_commands_frontmatter() {
    for cmd_file in "$PROJECT_DIR"/commands/*.md; do
        local name
        name=$(basename "$cmd_file")
        local has_frontmatter
        has_frontmatter=$(head -1 "$cmd_file")
        assert_eq "$name has frontmatter" "---" "$has_frontmatter"

        local has_description
        has_description=$(grep -c "^description:" "$cmd_file" || true)
        assert_eq "$name has description" "1" "$has_description"
    done
}
test_commands_frontmatter

echo ""
echo "=== workflow help ==="

test_help_runs() {
    local output
    output=$(bash "$WORKFLOW" help 2>&1)
    assert_contains "help shows setup" "setup" "$output"
    assert_contains "help shows workflow commands" "review-proposal" "$output"
    assert_contains "help shows background review command" "review-proposal-bg" "$output"
    assert_contains "help shows review job status command" "review-status" "$output"
    assert_contains "help shows issue commands" "issue-poll" "$output"
}
test_help_runs

echo ""
echo "=== workflow verify (syntax only) ==="

test_syntax() {
    bash -n "$WORKFLOW" 2>&1
    assert_eq "workflow script syntax valid" "0" "$?"

    if [[ -f "$PROJECT_DIR/bin/setup" ]]; then
        bash -n "$PROJECT_DIR/bin/setup" 2>&1
        assert_eq "setup script syntax valid" "0" "$?"
    fi
}
test_syntax

# ─── Summary ─────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
