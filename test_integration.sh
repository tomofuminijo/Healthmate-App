#!/bin/bash

# Healthmate-App 統合テストスクリプト
# 全サービスのデプロイ・アンデプロイサイクルをテストします

set -e

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリを読み込み
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/services.sh"

# テスト設定
TEST_ENVIRONMENT="dev"
TEST_REGION="us-west-2"
TEST_START_TIME=""
TEST_RESULTS=()
FAILED_TESTS=()

# 使用方法表示
show_test_usage() {
    cat << EOF
使用方法: $0 [options]

Healthmate-App 統合テストスクリプト

オプション:
    --environment ENV  テスト環境を指定 (dev, stage, prod)
    --region REGION    AWSリージョンを指定
    --help, -h         このヘルプを表示

例:
    $0                                    # dev環境、us-west-2リージョン
    $0 --environment stage                # stage環境、us-west-2リージョン
    $0 --region ap-northeast-1            # dev環境、ap-northeast-1リージョン

テスト内容:
    1. 完全デプロイサイクルテスト
    2. 異なるリージョンでのデプロイ検証
    3. エラー条件での動作確認
    4. アンデプロイサイクルテスト

注意事項:
    - 実際のAWSリソースが作成・削除されます
    - テスト実行には時間がかかります（30-60分）
    - 適切なAWS認証情報が必要です
EOF
}

# 引数解析
parse_test_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                TEST_ENVIRONMENT="$2"
                shift 2
                ;;
            --region)
                TEST_REGION="$2"
                shift 2
                ;;
            --help|-h)
                show_test_usage
                exit 0
                ;;
            *)
                log_error "無効な引数: $1"
                show_test_usage
                exit 1
                ;;
        esac
    done
}

# テスト実行関数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "テスト開始: $test_name"
    local start_time=$(date +%s)
    
    if eval "$test_command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        TEST_RESULTS+=("✅ $test_name (${duration}秒)")
        log_success "テスト成功: $test_name"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        TEST_RESULTS+=("❌ $test_name (${duration}秒)")
        FAILED_TESTS+=("$test_name")
        log_error "テスト失敗: $test_name"
        return 1
    fi
}

# テスト1: 完全デプロイサイクル
test_full_deploy_cycle() {
    log_info "=== テスト1: 完全デプロイサイクル ==="
    
    # デプロイ実行
    if ! ./deploy_all.sh "$TEST_ENVIRONMENT" --region "$TEST_REGION"; then
        log_error "デプロイが失敗しました"
        return 1
    fi
    
    # 基本的な動作確認
    log_info "デプロイされたリソースの確認中..."
    
    # Cognito User Pool の確認
    if ! aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?contains(Name, 'Healthmate')]" --output text >/dev/null 2>&1; then
        log_error "Cognito User Pool が見つかりません"
        return 1
    fi
    
    # DynamoDB テーブルの確認
    if ! aws dynamodb list-tables --query "TableNames[?contains(@, 'healthmate')]" --output text >/dev/null 2>&1; then
        log_error "DynamoDB テーブルが見つかりません"
        return 1
    fi
    
    # S3 バケットの確認
    if ! aws s3 ls | grep -q "healthmate" >/dev/null 2>&1; then
        log_error "S3 バケットが見つかりません"
        return 1
    fi
    
    log_success "全てのリソースが正常に作成されました"
    return 0
}

# テスト2: 異なるリージョンでのデプロイ検証
test_different_region_deploy() {
    log_info "=== テスト2: 異なるリージョンでのデプロイ検証 ==="
    
    local original_region="$TEST_REGION"
    local test_region="ap-northeast-1"
    
    # 元のリソースをクリーンアップ
    if ! ./undeploy_all.sh "$TEST_ENVIRONMENT" --region "$original_region"; then
        log_warning "元のリソースのクリーンアップに失敗しました"
    fi
    
    # 異なるリージョンでデプロイ
    if ! ./deploy_all.sh "$TEST_ENVIRONMENT" --region "$test_region"; then
        log_error "異なるリージョンでのデプロイが失敗しました"
        return 1
    fi
    
    # リージョン固有のリソース確認
    export AWS_REGION="$test_region"
    
    if ! aws cognito-idp list-user-pools --max-results 10 --region "$test_region" --query "UserPools[?contains(Name, 'Healthmate')]" --output text >/dev/null 2>&1; then
        log_error "$test_region リージョンでCognito User Pool が見つかりません"
        return 1
    fi
    
    # 元のリージョンに戻す
    export AWS_REGION="$original_region"
    TEST_REGION="$original_region"
    
    # テスト用リソースをクリーンアップ
    if ! ./undeploy_all.sh "$TEST_ENVIRONMENT" --region "$test_region"; then
        log_warning "テスト用リソースのクリーンアップに失敗しました"
    fi
    
    log_success "異なるリージョンでのデプロイが正常に動作しました"
    return 0
}

# テスト3: エラー条件での動作確認
test_error_conditions() {
    log_info "=== テスト3: エラー条件での動作確認 ==="
    
    # 無効な環境名でのテスト
    log_info "無効な環境名でのテスト..."
    if ./deploy_all.sh "invalid_env" --region "$TEST_REGION" 2>/dev/null; then
        log_error "無効な環境名が受け入れられました"
        return 1
    fi
    log_success "無効な環境名が正しく拒否されました"
    
    # 無効なリージョンでのテスト
    log_info "無効なリージョンでのテスト..."
    if ./deploy_all.sh "$TEST_ENVIRONMENT" --region "invalid-region" 2>/dev/null; then
        log_error "無効なリージョンが受け入れられました"
        return 1
    fi
    log_success "無効なリージョンが正しく拒否されました"
    
    # ヘルプ表示のテスト
    log_info "ヘルプ表示のテスト..."
    if ! ./deploy_all.sh --help >/dev/null 2>&1; then
        log_error "ヘルプ表示が失敗しました"
        return 1
    fi
    log_success "ヘルプ表示が正常に動作しました"
    
    return 0
}

# テスト4: アンデプロイサイクル
test_undeploy_cycle() {
    log_info "=== テスト4: アンデプロイサイクル ==="
    
    # まずデプロイを実行
    if ! ./deploy_all.sh "$TEST_ENVIRONMENT" --region "$TEST_REGION"; then
        log_error "テスト用デプロイが失敗しました"
        return 1
    fi
    
    # アンデプロイ実行（確認プロンプトを自動化）
    echo "yes" | ./undeploy_all.sh "$TEST_ENVIRONMENT" --region "$TEST_REGION"
    local undeploy_result=$?
    
    if [[ $undeploy_result -ne 0 && $undeploy_result -ne 2 ]]; then
        log_error "アンデプロイが予期しないエラーで失敗しました"
        return 1
    fi
    
    # リソースが削除されたことを確認
    log_info "リソースの削除確認中..."
    
    # 少し待機してからチェック
    sleep 30
    
    # Cognito User Pool の削除確認
    local cognito_pools=$(aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?contains(Name, 'Healthmate')]" --output text 2>/dev/null || echo "")
    if [[ -n "$cognito_pools" ]]; then
        log_warning "一部のCognito User Pool が残存している可能性があります"
    fi
    
    log_success "アンデプロイサイクルが完了しました"
    return 0
}

# テスト結果サマリー表示
show_test_summary() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - TEST_START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo -e "${PURPLE}📋 統合テスト結果サマリー${NC}"
    echo "========================================"
    echo -e "${BLUE}🌍 テスト環境: $TEST_ENVIRONMENT${NC}"
    echo -e "${BLUE}📍 テストリージョン: $TEST_REGION${NC}"
    echo -e "${BLUE}⏱️  総実行時間: ${minutes}分${seconds}秒${NC}"
    echo -e "${BLUE}📅 完了時刻: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    echo -e "${CYAN}📊 テスト結果:${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        echo "   $result"
    done
    echo ""
    
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 全てのテストが成功しました！${NC}"
        echo -e "${GREEN}Healthmate-App 統合デプロイメント管理は正常に動作しています${NC}"
    else
        echo -e "${RED}❌ 失敗したテスト (${#FAILED_TESTS[@]}):${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}   - $test${NC}"
        done
        echo ""
        echo -e "${YELLOW}⚠️  一部のテストが失敗しました。ログを確認して問題を修正してください${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📄 詳細ログ: $LOG_FILE${NC}"
    echo ""
}

# メイン処理
main() {
    # 開始時刻記録
    TEST_START_TIME=$(date +%s)
    
    # 引数解析
    parse_test_arguments "$@"
    
    # 環境変数設定
    if ! setup_environment_variables "$TEST_ENVIRONMENT" "$TEST_REGION"; then
        log_error "環境設定に失敗しました"
        exit 1
    fi
    
    # ログ初期化
    init_logging
    
    # 初期化（前提条件チェック）
    if ! initialize; then
        log_error "初期化に失敗しました"
        exit 1
    fi
    
    echo ""
    echo -e "${PURPLE}🧪 Healthmate-App 統合テストを開始します${NC}"
    echo "========================================"
    echo -e "${BLUE}📋 テスト設定:${NC}"
    echo -e "${BLUE}   🌍 環境: $TEST_ENVIRONMENT${NC}"
    echo -e "${BLUE}   📍 リージョン: $TEST_REGION${NC}"
    echo -e "${BLUE}   📅 開始時刻: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  注意: このテストは実際のAWSリソースを作成・削除します${NC}"
    echo -e "${YELLOW}⚠️  テスト実行には30-60分程度かかる場合があります${NC}"
    echo ""
    
    read -p "テストを実行しますか？ (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "テストがキャンセルされました"
        exit 0
    fi
    
    # テスト実行
    run_test "完全デプロイサイクル" "test_full_deploy_cycle"
    run_test "異なるリージョンでのデプロイ検証" "test_different_region_deploy"
    run_test "エラー条件での動作確認" "test_error_conditions"
    run_test "アンデプロイサイクル" "test_undeploy_cycle"
    
    # 結果表示
    show_test_summary
    
    # 終了コード決定
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        exit 0  # 全て成功
    else
        exit 1  # 一部失敗
    fi
}

# スクリプト実行
main "$@"