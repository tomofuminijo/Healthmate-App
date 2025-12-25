#!/bin/bash

# common.sh の単体テスト
# 引数解析、バリデーション、環境変数設定機能のテスト

# テスト用の一時ディレクトリ設定
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# common.shをソース
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/lib/common.sh"

# テスト結果カウンタ
TESTS_PASSED=0
TESTS_FAILED=0

# テスト関数
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo "🧪 テスト実行: $test_name"
    
    if $test_function; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $test_name"
        ((TESTS_FAILED++))
    fi
    echo
}

# 環境名バリデーションテスト
test_validate_environment() {
    # 有効な環境名
    validate_environment "dev" && \
    validate_environment "stage" && \
    validate_environment "prod" && \
    
    # 無効な環境名
    ! validate_environment "invalid" && \
    ! validate_environment "" && \
    ! validate_environment "development"
}

# リージョン名バリデーションテスト
test_validate_region() {
    # 有効なリージョン名
    validate_region "us-west-2" && \
    validate_region "ap-northeast-1" && \
    validate_region "eu-west-1" && \
    
    # 無効なリージョン名
    ! validate_region "invalid" && \
    ! validate_region "" && \
    ! validate_region "us-west" && \
    ! validate_region "123-456-789"
}

# 環境変数設定テスト
test_setup_environment_variables() {
    # 有効な設定
    if setup_environment_variables "dev" "us-west-2"; then
        [[ "$HEALTHMATE_ENV" == "dev" ]] && \
        [[ "$AWS_REGION" == "us-west-2" ]]
    else
        return 1
    fi
}

# 引数解析テスト（基本）
test_parse_arguments_basic() {
    # デフォルト値テスト
    unset ENVIRONMENT REGION AWS_REGION
    
    # モック関数（show_usageとaws configureをモック）
    show_usage() { echo "Usage shown"; }
    aws() {
        if [[ "$1" == "configure" && "$2" == "get" && "$3" == "region" ]]; then
            echo "us-west-2"
        fi
    }
    
    parse_arguments
    
    [[ "$ENVIRONMENT" == "dev" ]] && \
    [[ "$REGION" == "us-west-2" ]]
}

# 引数解析テスト（環境指定）
test_parse_arguments_with_env() {
    unset ENVIRONMENT REGION AWS_REGION
    
    # モック関数
    show_usage() { echo "Usage shown"; }
    aws() {
        if [[ "$1" == "configure" && "$2" == "get" && "$3" == "region" ]]; then
            echo "us-west-2"
        fi
    }
    
    parse_arguments "prod"
    
    [[ "$ENVIRONMENT" == "prod" ]] && \
    [[ "$REGION" == "us-west-2" ]]
}

# 引数解析テスト（リージョン指定）
test_parse_arguments_with_region() {
    unset ENVIRONMENT REGION AWS_REGION
    
    # モック関数
    show_usage() { echo "Usage shown"; }
    
    parse_arguments "stage" "--region" "ap-northeast-1"
    
    [[ "$ENVIRONMENT" == "stage" ]] && \
    [[ "$REGION" == "ap-northeast-1" ]]
}

# 引数解析テスト（AWS_REGION環境変数）
test_parse_arguments_with_aws_region_env() {
    unset ENVIRONMENT REGION
    export AWS_REGION="eu-west-1"
    
    # モック関数
    show_usage() { echo "Usage shown"; }
    
    parse_arguments "dev"
    
    [[ "$ENVIRONMENT" == "dev" ]] && \
    [[ "$REGION" == "eu-west-1" ]]
}

# テスト実行
echo "🚀 common.sh 単体テスト開始"
echo "================================"

run_test "環境名バリデーション" test_validate_environment
run_test "リージョン名バリデーション" test_validate_region
run_test "環境変数設定" test_setup_environment_variables
run_test "引数解析（基本）" test_parse_arguments_basic
run_test "引数解析（環境指定）" test_parse_arguments_with_env
run_test "引数解析（リージョン指定）" test_parse_arguments_with_region
run_test "引数解析（AWS_REGION環境変数）" test_parse_arguments_with_aws_region_env

# 結果表示
echo "================================"
echo "📊 テスト結果:"
echo "  ✅ 成功: $TESTS_PASSED"
echo "  ❌ 失敗: $TESTS_FAILED"

# クリーンアップ
cd /
rm -rf "$TEST_DIR"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "🎉 すべてのテストが成功しました！"
    exit 0
else
    echo "💥 $TESTS_FAILED 個のテストが失敗しました"
    exit 1
fi