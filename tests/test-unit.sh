#!/bin/bash

# Dual AI Workflow — Unit Tests
# Run: bash tests/test-unit.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOW="$PROJECT_DIR/bin/sparring"
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

    # 隔离：指向不存在的 config 文件，避免读取用户真实 ~/.config/sparring/config.json
    export CONFIG_DIR_GLOBAL="$TMP_DIR/config-global"
    export CONFIG_FILE_GLOBAL="$CONFIG_DIR_GLOBAL/config.json"
    export CONFIG_DIR_PROJECT="$TMP_DIR/project/.sparring"
    export CONFIG_FILE_PROJECT="$CONFIG_DIR_PROJECT/config.json"

    # 清掉所有可能影响测试的 env 变量
    unset WORKFLOW_REVIEW_BACKEND WORKFLOW_REVIEW_BACKEND_FALLBACK
    unset WORKFLOW_REVIEW_TIMEOUT WORKFLOW_REVIEW_RETRIES
    unset WORKFLOW_AGENT_MODEL WORKFLOW_CODEX_MODEL WORKFLOW_CODEX_EFFORT WORKFLOW_CODEX_HOME
    unset WORKFLOW_GLM_API_KEY WORKFLOW_GLM_MODEL WORKFLOW_GLM_THINKING
    unset WORKFLOW_GLM_MAX_TOKENS WORKFLOW_GLM_TEMPERATURE WORKFLOW_GLM_API_BASE
    unset SPARRING_REVIEW_BACKEND SPARRING_REVIEW_FALLBACK SPARRING_REVIEW_TIMEOUT SPARRING_REVIEW_RETRIES
    unset SPARRING_GLM_API_KEY SPARRING_GLM_MODEL SPARRING_CURSOR_MODEL

    # Source the workflow script but replace main() and set -euo to prevent issues
    eval "$(sed -e 's/^main "$@"/# main disabled for testing/' \
                 -e 's/^set -euo pipefail/# set disabled for testing/' \
                 "$WORKFLOW")"

    # source 过程会执行 CONFIG_FILE_* 赋值，覆盖我们上面的 export。再次强制设置
    CONFIG_DIR_GLOBAL="$TMP_DIR/config-global"
    CONFIG_FILE_GLOBAL="$CONFIG_DIR_GLOBAL/config.json"
    CONFIG_DIR_PROJECT="$TMP_DIR/project/.sparring"
    CONFIG_FILE_PROJECT="$CONFIG_DIR_PROJECT/config.json"

    # 清掉可能残留的 warn 哨兵文件（避免测试间互相干扰）
    rm -f "${TMPDIR:-/tmp}/workflow-cfg-warn-$$-"* 2>/dev/null || true
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
    local attempts
    attempts=$(SPARRING_REVIEW_RETRIES=1 _agent_attempts)
    assert_eq "RETRIES=1 → 2 次尝试" "2" "$attempts"
}
test_agent_attempts_default

test_agent_attempts_zero_retries() {
    source_workflow_funcs
    local attempts
    attempts=$(SPARRING_REVIEW_RETRIES=0 _agent_attempts)
    assert_eq "RETRIES=0 → 1 次尝试（不重试）" "1" "$attempts"
}
test_agent_attempts_zero_retries

test_agent_attempts_multi() {
    source_workflow_funcs
    local attempts
    attempts=$(SPARRING_REVIEW_RETRIES=3 _agent_attempts)
    assert_eq "RETRIES=3 → 4 次尝试" "4" "$attempts"
}
test_agent_attempts_multi

echo ""
echo "=== _config_get 四层优先级 ==="

test_config_defaults() {
    source_workflow_funcs
    # 无 global / project / env → 读默认
    local backend timeout
    backend=$(_config_get review.backend)
    timeout=$(_config_get review.timeout)
    assert_eq "默认 backend=cursor" "cursor" "$backend"
    assert_eq "默认 timeout=60" "60" "$timeout"
}
test_config_defaults

test_config_global_overrides_default() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo '{"review":{"backend":"glm","timeout":45}}' > "$CONFIG_FILE_GLOBAL"
    local backend timeout
    backend=$(_config_get review.backend)
    timeout=$(_config_get review.timeout)
    assert_eq "global 覆盖默认 backend" "glm" "$backend"
    assert_eq "global 覆盖默认 timeout" "45" "$timeout"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_global_overrides_default

test_config_project_overrides_global() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL" "$CONFIG_DIR_PROJECT"
    echo '{"review":{"backend":"glm"}}' > "$CONFIG_FILE_GLOBAL"
    echo '{"review":{"backend":"codex"}}' > "$CONFIG_FILE_PROJECT"
    local backend
    backend=$(_config_get review.backend)
    assert_eq "project 覆盖 global" "codex" "$backend"
    rm -f "$CONFIG_FILE_GLOBAL" "$CONFIG_FILE_PROJECT"
}
test_config_project_overrides_global

test_config_sparring_env_highest() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL" "$CONFIG_DIR_PROJECT"
    echo '{"review":{"backend":"glm"}}' > "$CONFIG_FILE_GLOBAL"
    echo '{"review":{"backend":"codex"}}' > "$CONFIG_FILE_PROJECT"
    local backend
    backend=$(SPARRING_REVIEW_BACKEND=cursor _config_get review.backend)
    assert_eq "SPARRING_* env 最高优先级" "cursor" "$backend"
    rm -f "$CONFIG_FILE_GLOBAL" "$CONFIG_FILE_PROJECT"
}
test_config_sparring_env_highest

test_config_workflow_env_fallback() {
    source_workflow_funcs
    # SPARRING_* 未设，WORKFLOW_* 应该生效
    local backend
    backend=$(WORKFLOW_REVIEW_BACKEND=glm _config_get review.backend)
    assert_eq "WORKFLOW_* 兼容别名" "glm" "$backend"
}
test_config_workflow_env_fallback

test_config_sparring_wins_over_workflow() {
    source_workflow_funcs
    local backend
    backend=$(SPARRING_REVIEW_BACKEND=cursor WORKFLOW_REVIEW_BACKEND=glm \
        _config_get review.backend)
    assert_eq "SPARRING_* 优先于 WORKFLOW_*" "cursor" "$backend"
}
test_config_sparring_wins_over_workflow

test_config_legacy_alias_fallback() {
    source_workflow_funcs
    # 历史变量：WORKFLOW_REVIEW_BACKEND_FALLBACK → review.fallback
    local fb
    fb=$(WORKFLOW_REVIEW_BACKEND_FALLBACK=codex _config_get review.fallback)
    assert_eq "WORKFLOW_REVIEW_BACKEND_FALLBACK legacy 别名" "codex" "$fb"
}
test_config_legacy_alias_fallback

test_config_legacy_alias_agent_model() {
    source_workflow_funcs
    local model
    model=$(WORKFLOW_AGENT_MODEL=opus-4.7 _config_get cursor.model)
    assert_eq "WORKFLOW_AGENT_MODEL legacy 别名" "opus-4.7" "$model"
}
test_config_legacy_alias_agent_model

test_config_malformed_file() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo 'not valid json {' > "$CONFIG_FILE_GLOBAL"
    local backend
    backend=$(_config_get review.backend 2>/dev/null)
    # 格式错的文件被忽略，应该回退到默认
    assert_eq "非法 JSON 文件回退到默认" "cursor" "$backend"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_malformed_file

test_config_nested_merge() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL" "$CONFIG_DIR_PROJECT"
    # global 设 glm.api_key，project 设 glm.model → 应该合并不是覆盖
    echo '{"glm":{"api_key":"global-key"}}' > "$CONFIG_FILE_GLOBAL"
    echo '{"glm":{"model":"glm-4-plus"}}' > "$CONFIG_FILE_PROJECT"
    local key model
    key=$(_config_get glm.api_key)
    model=$(_config_get glm.model)
    assert_eq "递归合并保留 global.glm.api_key" "global-key" "$key"
    assert_eq "递归合并加上 project.glm.model" "glm-4-plus" "$model"
    rm -f "$CONFIG_FILE_GLOBAL" "$CONFIG_FILE_PROJECT"
}
test_config_nested_merge

echo ""
echo "=== config 子命令 ==="

test_config_init_global() {
    source_workflow_funcs
    rm -f "$CONFIG_FILE_GLOBAL"
    config_init >/dev/null 2>&1
    assert_file_exists "global config 创建" "$CONFIG_FILE_GLOBAL"
    # 检查 chmod 600
    local perms
    perms=$(stat -f %A "$CONFIG_FILE_GLOBAL" 2>/dev/null || stat -c %a "$CONFIG_FILE_GLOBAL" 2>/dev/null)
    assert_eq "global config chmod 600" "600" "$perms"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_init_global

test_config_init_project() {
    source_workflow_funcs
    rm -rf "$CONFIG_DIR_PROJECT"
    config_init project >/dev/null 2>&1
    assert_file_exists "project config 创建" "$CONFIG_FILE_PROJECT"
    assert_file_exists "project .gitignore 创建" "$CONFIG_DIR_PROJECT/.gitignore"
    # 项目配置不应包含 api_key 字段
    local has_key
    has_key=$(jq -r 'has("glm") and (.glm | has("api_key"))' "$CONFIG_FILE_PROJECT")
    assert_eq "project config 不应包含 glm.api_key" "false" "$has_key"
    rm -rf "$CONFIG_DIR_PROJECT"
}
test_config_init_project

test_config_init_existing_no_force() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo '{"review":{"backend":"codex"}}' > "$CONFIG_FILE_GLOBAL"
    config_init >/dev/null 2>&1
    # 文件未被覆盖
    local backend
    backend=$(jq -r '.review.backend' "$CONFIG_FILE_GLOBAL")
    assert_eq "已存在时不覆盖" "codex" "$backend"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_init_existing_no_force

test_config_show_masks_key() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo '{"glm":{"api_key":"abcd1234secretxyz"}}' > "$CONFIG_FILE_GLOBAL"
    local output
    output=$(config_show 2>&1)
    # 明文 key 不应出现
    if echo "$output" | grep -q "abcd1234secretxyz"; then
        echo "  ✗ config show 泄漏明文 key"
        ((FAIL++))
    else
        echo "  ✓ config show 不泄漏明文 key"
        ((PASS++))
    fi
    # 掩码应出现
    assert_contains "config show 显示掩码" "abcd\*\*\*" "$output"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_show_masks_key

test_config_get_masks_api_key() {
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo '{"glm":{"api_key":"abcd1234secretxyz"}}' > "$CONFIG_FILE_GLOBAL"
    local output
    output=$(config_get_cmd glm.api_key)
    if [[ "$output" == "abcd1234secretxyz" ]]; then
        echo "  ✗ config get glm.api_key 泄漏明文"
        ((FAIL++))
    else
        echo "  ✓ config get glm.api_key 掩码"
        ((PASS++))
    fi
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_get_masks_api_key

test_config_init_project_preserves_gitignore() {
    # Sparring CONCERN 1: config init project 不应覆盖已有的 .gitignore
    source_workflow_funcs
    rm -rf "$CONFIG_DIR_PROJECT"
    mkdir -p "$CONFIG_DIR_PROJECT"
    cat > "$CONFIG_DIR_PROJECT/.gitignore" <<'EOF'
# 用户现有规则
*.log
tmp/
EOF
    config_init project >/dev/null 2>&1
    # 原有规则必须保留
    assert_contains "原有 *.log 规则保留" "\*\.log" "$(cat "$CONFIG_DIR_PROJECT/.gitignore")"
    assert_contains "原有 tmp/ 规则保留" "tmp/" "$(cat "$CONFIG_DIR_PROJECT/.gitignore")"
    # 新规则也追加进去
    assert_contains "新增 *.local.json 规则" "\*\.local\.json" "$(cat "$CONFIG_DIR_PROJECT/.gitignore")"
    rm -rf "$CONFIG_DIR_PROJECT"
}
test_config_init_project_preserves_gitignore

test_config_init_project_no_secrets_file_mention() {
    # Sparring CONCERN 2: .gitignore 模板不应误导用户以为 secrets.json 会被读取
    source_workflow_funcs
    rm -rf "$CONFIG_DIR_PROJECT"
    config_init project >/dev/null 2>&1
    # 不应在 config.json 或 .gitignore 里出现显式的 secrets.json 引用（避免误导）
    if grep -q "^secrets\.json$" "$CONFIG_DIR_PROJECT/.gitignore" 2>/dev/null; then
        echo "  ✗ .gitignore 仍显式提 secrets.json（误导）"
        ((FAIL++))
    else
        echo "  ✓ .gitignore 不再显式提 secrets.json"
        ((PASS++))
    fi
    # 项目 config.json 注释必须明确说 api_key 不放这里
    local comment
    comment=$(jq -r '._comment // ""' "$CONFIG_FILE_PROJECT")
    assert_contains "项目 config 注释警告 api_key 不放这里" "api_key" "$comment"
    rm -rf "$CONFIG_DIR_PROJECT"
}
test_config_init_project_no_secrets_file_mention

test_config_read_file_warns_once() {
    # Sparring CONCERN 3: 非法 JSON 的告警在同一进程只出现一次
    source_workflow_funcs
    mkdir -p "$CONFIG_DIR_GLOBAL"
    echo 'not valid json {' > "$CONFIG_FILE_GLOBAL"
    # 调用多次 _config_get，触发多次读
    local err_output
    err_output=$({ _config_get review.backend; _config_get review.timeout; _config_get glm.model; } 2>&1 >/dev/null)
    local warn_count
    warn_count=$(echo "$err_output" | grep -c "配置文件格式错误")
    assert_eq "非法 JSON 只告警一次" "1" "$warn_count"
    rm -f "$CONFIG_FILE_GLOBAL"
}
test_config_read_file_warns_once

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
echo "=== sparring verify (syntax only) ==="

test_syntax() {
    bash -n "$WORKFLOW" 2>&1
    assert_eq "sparring script syntax valid" "0" "$?"

    if [[ -f "$PROJECT_DIR/bin/setup" ]]; then
        bash -n "$PROJECT_DIR/bin/setup" 2>&1
        assert_eq "setup script syntax valid" "0" "$?"
    fi
}
test_syntax

echo ""
echo "=== sparring / workflow 兼容别名 ==="

test_workflow_symlink_exists() {
    assert_file_exists "bin/workflow 软链存在" "$PROJECT_DIR/bin/workflow"
    # 必须是软链，而不是文件副本
    if [[ -L "$PROJECT_DIR/bin/workflow" ]]; then
        echo "  ✓ bin/workflow 是软链（防止重复代码）"
        ((PASS++))
    else
        echo "  ✗ bin/workflow 应该是软链，不是文件"
        ((FAIL++))
    fi
}
test_workflow_symlink_exists

test_workflow_and_sparring_same_output() {
    # 调两个命令的 help，输出应该一致
    local out_sparring out_workflow
    out_sparring=$(bash "$PROJECT_DIR/bin/sparring" help 2>&1 | wc -l | tr -d ' ')
    out_workflow=$(bash "$PROJECT_DIR/bin/workflow" help 2>&1 | wc -l | tr -d ' ')
    assert_eq "workflow 软链和 sparring 输出行数一致" "$out_sparring" "$out_workflow"
}
test_workflow_and_sparring_same_output

test_help_shows_sparring_usage() {
    local output
    output=$(bash "$WORKFLOW" help 2>&1)
    assert_contains "help 标题用 Sparring" "Sparring" "$output"
    assert_contains "help 用法提示 sparring" "sparring <command>" "$output"
    assert_contains "help 提到 workflow 兼容别名" "兼容别名" "$output"
}
test_help_shows_sparring_usage

test_setup_exec_uses_resolve_script_dir() {
    # Sparring CONCERN 1 源码断言：sparring 的 setup dispatch 必须用 _resolve_script_dir
    # 不能用 $(cd "$(dirname "$0")" && pwd)/setup（会把 global symlink 目录当根）
    # 做法：直接扫源码，不 exec 真 setup（避免污染环境、消耗 API 配额）
    local setup_line
    setup_line=$(grep -E 'setup\).*exec bash' "$WORKFLOW" | head -1)
    if echo "$setup_line" | grep -q '_resolve_script_dir.*bin/setup'; then
        echo "  ✓ setup exec 使用 _resolve_script_dir（支持全局软链调用）"
        ((PASS++))
    else
        echo "  ✗ setup exec 未使用 _resolve_script_dir"
        echo "    line: $setup_line"
        ((FAIL++))
    fi
}
test_setup_exec_uses_resolve_script_dir

test_setup_rejects_non_tty() {
    # bin/setup 没有 TTY 时应立刻 exit 2，不能误触发完整 setup
    local output status=0
    output=$(bash "$PROJECT_DIR/bin/setup" </dev/null 2>&1) || status=$?
    assert_eq "非 TTY 时 setup exit 2" "2" "$status"
    assert_contains "错误信息提示 TTY 要求" "TTY" "$output"
}
test_setup_rejects_non_tty

test_setup_help_quick_path() {
    # sparring setup --help 必须是 quick path，不进入交互流程
    local output status=0
    output=$(bash "$PROJECT_DIR/bin/setup" --help </dev/null 2>&1) || status=$?
    assert_eq "setup --help 正常退出" "0" "$status"
    assert_contains "setup --help 打印用法" "用法" "$output"
    # 确保没打 verify 或 install 相关副作用信息
    if echo "$output" | grep -qE "安装|验证|检查"; then
        # 允许列出功能步骤中提到，但不应有实际执行提示
        if echo "$output" | grep -qE "^(正在|✓|已安装)"; then
            echo "  ✗ setup --help 有执行副作用"
            ((FAIL++))
        else
            echo "  ✓ setup --help 无副作用"
            ((PASS++))
        fi
    else
        echo "  ✓ setup --help 无副作用"
        ((PASS++))
    fi
}
test_setup_help_quick_path

test_resolve_script_dir_via_symlink() {
    # 软链解析必须指向 repo 根，无论从哪调
    source_workflow_funcs
    local fake_bin="$TMP_DIR/fake-chain"
    mkdir -p "$fake_bin"
    ln -sf "$PROJECT_DIR/bin/sparring" "$fake_bin/sparring"
    # 在 subshell 里模拟以软链为 $0 调用
    local resolved
    resolved=$(bash -c '
        _resolve_script_dir() {
            local src="$0"
            while [[ -L "$src" ]]; do
                local dir
                dir=$(cd -P "$(dirname "$src")" && pwd)
                src=$(readlink "$src")
                [[ "$src" != /* ]] && src="$dir/$src"
            done
            cd -P "$(dirname "$src")/.." && pwd
        }
        _resolve_script_dir
    ' "$fake_bin/sparring")
    assert_eq "通过软链 _resolve_script_dir 回到 repo 根" "$PROJECT_DIR" "$resolved"
}
test_resolve_script_dir_via_symlink

# ─── Summary ─────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
