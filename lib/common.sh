#!/bin/bash

# Healthmate-App 共通ライブラリ
# ログ機能、環境設定、AWS認証確認などの共通機能を提供

set -o pipefail  # パイプライン内のコマンドの終了コードを正しく取得

# カラーコード定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# グローバル変数
LOG_FILE=""
ENVIRONMENT=""
REGION=""

# ログファイル初期化
init_logging() {
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="logs/healthmate-app-${timestamp}.log"
    
    # ログディレクトリ作成
    mkdir -p logs
    
    # ログファイル初期化
    cat > "$LOG_FILE" << EOF
Healthmate-App 統合デプロイメント管理ログ
開始時刻: $(date '+%Y-%m-%d %H:%M:%S')
環境: $ENVIRONMENT
リージョン: $REGION
========================================
EOF
    
    log_info "ログファイル: $LOG_FILE"
}

# ログファイルへの書き込み
write_to_log() {
    local message="$1"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE"
    fi
}

# ログ出力関数群
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}] INFO: ${message}${NC}"
    write_to_log "[${timestamp}] INFO: ${message}"
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${timestamp}] SUCCESS: ${message}${NC}"
    write_to_log "[${timestamp}] SUCCESS: ${message}"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[${timestamp}] WARNING: ${message}${NC}"
    write_to_log "[${timestamp}] WARNING: ${message}"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[${timestamp}] ERROR: ${message}${NC}" >&2
    write_to_log "[${timestamp}] ERROR: ${message}"
}

# プログレス表示
log_progress() {
    local current="$1"
    local total="$2"
    local service="$3"
    local action="$4"
    echo -e "${CYAN}[${current}/${total}] ${service} ${action}中...${NC}"
}

# 実行時間計算とログ出力
log_duration() {
    local start_time="$1"
    local end_time="$2"
    local service_name="$3"
    local action="$4"
    
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    if [[ $minutes -gt 0 ]]; then
        log_info "$service_name の$action 実行時間: ${minutes}分${seconds}秒"
    else
        log_info "$service_name の$action 実行時間: ${seconds}秒"
    fi
}

# サービス準備完了確認
wait_for_service_ready() {
    local service_name="$1"
    local environment="$2"
    local max_wait_time=300  # 5分
    local check_interval=10  # 10秒間隔
    local elapsed_time=0
    
    log_info "$service_name の準備完了を確認中..."
    
    case "$service_name" in
        "Core")
            # Cognito User Pool の作成完了を確認
            while [[ $elapsed_time -lt $max_wait_time ]]; do
                if aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?contains(Name, 'Healthmate')]" --output text >/dev/null 2>&1; then
                    log_success "$service_name の準備が完了しました"
                    return 0
                fi
                sleep $check_interval
                elapsed_time=$((elapsed_time + check_interval))
                log_info "待機中... (${elapsed_time}/${max_wait_time}秒)"
            done
            ;;
        "HealthManager")
            # DynamoDB テーブルの作成完了を確認
            while [[ $elapsed_time -lt $max_wait_time ]]; do
                if aws dynamodb list-tables --query "TableNames[?contains(@, 'healthmate')]" --output text >/dev/null 2>&1; then
                    log_success "$service_name の準備が完了しました"
                    return 0
                fi
                sleep $check_interval
                elapsed_time=$((elapsed_time + check_interval))
                log_info "待機中... (${elapsed_time}/${max_wait_time}秒)"
            done
            ;;
        "CoachAI")
            # AgentCore エージェントの準備完了を確認
            local env_suffix=""
            if [[ "$environment" != "prod" ]]; then
                env_suffix="_$environment"
            fi
            local expected_runtime_name="healthmate_coach_ai${env_suffix}"
            log_info "エージェント状態確認します: $expected_runtime_name"
            while [[ $elapsed_time -lt $max_wait_time ]]; do
                # bedrock-agentcore-control APIでエージェントの状態を確認
                local runtime_status=$(aws bedrock-agentcore-control list-agent-runtimes \
                    --region "$REGION" \
                    --query "agentRuntimes[?agentRuntimeName=='$expected_runtime_name'].status" \
                    --output text 2>/dev/null)
                
                if [[ "$runtime_status" == "READY" ]]; then
                    log_success "$service_name の準備が完了しました"
                    return 0
                elif [[ -n "$runtime_status" && "$runtime_status" != "READY" ]]; then
                    log_info "$service_name の状態: $runtime_status"
                fi
                
                sleep $check_interval
                elapsed_time=$((elapsed_time + check_interval))
                log_info "待機中... (${elapsed_time}/${max_wait_time}秒)"
            done
            ;;
        "Frontend")
            # S3 バケットまたは CloudFront の準備完了を確認
            while [[ $elapsed_time -lt $max_wait_time ]]; do
                if aws s3 ls | grep -q "healthmate" >/dev/null 2>&1; then
                    log_success "$service_name の準備が完了しました"
                    return 0
                fi
                sleep $check_interval
                elapsed_time=$((elapsed_time + check_interval))
                log_info "待機中... (${elapsed_time}/${max_wait_time}秒)"
            done
            ;;
    esac
    
    log_warning "$service_name の準備完了確認がタイムアウトしました"
    WARNINGS+=("$service_name: 準備完了確認がタイムアウトしました")
    return 1
}

# デプロイ完了後の統合テスト推奨メッセージ
show_integration_test_recommendation() {
    echo ""
    echo -e "${CYAN}🧪 統合テストの推奨${NC}"
    echo "========================================"
    echo -e "${CYAN}デプロイが完了しました。以下の統合テストの実行を推奨します:${NC}"
    echo ""
    echo -e "${BLUE}1. 認証フローテスト${NC}"
    echo "   cd ../Healthmate-Core && python test_cognito_integration.py"
    echo ""
    echo -e "${BLUE}2. データ管理テスト${NC}"
    echo "   cd ../Healthmate-HealthManager && python test_mcp_client.py"
    echo ""
    echo -e "${BLUE}3. AI エージェントテスト${NC}"
    echo "   cd ../Healthmate-CoachAI && python manual_test_deployed_agent.py"
    echo ""
    echo -e "${BLUE}4. フロントエンドテスト${NC}"
    echo "   # ブラウザでフロントエンドにアクセスして動作確認"
    echo ""
    echo -e "${BLUE}5. エンドツーエンドテスト${NC}"
    echo "   # 全サービスを通じたユーザーフローの確認"
    echo ""
    echo -e "${CYAN}詳細なテスト手順については各サービスのREADME.mdを参照してください${NC}"
    echo ""
}

# エラー詳細表示関数
log_error_details() {
    local service_name="$1"
    local action="$2"
    local exit_code="$3"
    local error_message="$4"
    
    log_error "$service_name $action - Code: $exit_code, Message: $error_message"
    write_to_log "ERROR_DETAILS: $service_name $action - Code: $exit_code, Message: $error_message"
}

# デプロイ完了後の統合テスト推奨メッセージ（重複削除用）
show_integration_test_recommendation() {
    echo ""
    echo -e "${CYAN}🧪 統合テストの推奨${NC}"
    echo "========================================"
    echo -e "${CYAN}デプロイが完了しました。以下の統合テストの実行を推奨します:${NC}"
    echo ""
    echo -e "${BLUE}1. 認証フローテスト${NC}"
    echo "   cd ../Healthmate-Core && python test_cognito_integration.py"
    echo ""
    echo -e "${BLUE}2. データ管理テスト${NC}"
    echo "   cd ../Healthmate-HealthManager && python test_mcp_client.py"
    echo ""
    echo -e "${BLUE}3. AI エージェントテスト${NC}"
    echo "   cd ../Healthmate-CoachAI && python manual_test_deployed_agent.py"
    echo ""
    echo -e "${BLUE}4. フロントエンドテスト${NC}"
    echo "   # ブラウザでフロントエンドにアクセスして動作確認"
    echo ""
    echo -e "${BLUE}5. エンドツーエンドテスト${NC}"
    echo "   # 全サービスを通じたユーザーフローの確認"
    echo ""
    echo -e "${CYAN}詳細なテスト手順については各サービスのREADME.mdを参照してください${NC}"
    echo ""
}

# エラー詳細表示関数（重複削除用）
log_error_details() {
    local service_name="$1"
    local action="$2"
    local exit_code="$3"
    local error_message="$4"
    
    log_error "$service_name $action - Code: $exit_code, Message: $error_message"
    write_to_log "ERROR_DETAILS: $service_name $action - Code: $exit_code, Message: $error_message"
}

# 実行サマリー表示
show_execution_summary() {
    local action="$1"
    local start_time="$2"
    local successful_services_array_name="$3"
    local failed_services_array_name="$4"
    local warnings_array_name="$5"
    
    # 配列を間接参照で取得
    eval "local successful_services=(\"\${${successful_services_array_name}[@]}\")"
    eval "local failed_services=(\"\${${failed_services_array_name}[@]}\")"
    eval "local warnings=(\"\${${warnings_array_name}[@]}\")"
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo -e "${CYAN}📊 実行サマリー${NC}"
    echo "========================================"
    write_to_log "SUMMARY: Action=$action, Environment=$ENVIRONMENT, Region=$REGION"
    write_to_log "SUMMARY: Duration=${minutes}m${seconds}s, Success=${#successful_services[@]}, Failed=${#failed_services[@]}, Warnings=${#warnings[@]}"
    
    if [[ ${#successful_services[@]} -gt 0 ]]; then
        local success_list=$(IFS=' '; echo "${successful_services[*]}")
        write_to_log "SUMMARY: Successful services: $success_list"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        local failed_list=$(IFS=' '; echo "${failed_services[*]}")
        write_to_log "SUMMARY: Failed services: $failed_list"
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        local warnings_list=$(IFS='; '; echo "${warnings[*]}")
        write_to_log "SUMMARY: Warnings: $warnings_list"
    fi
    
    echo -e "${BLUE}📋 実行結果:${NC}"
    echo "   🌍 環境: $ENVIRONMENT"
    echo "   📍 リージョン: $REGION"
    echo "   ⏱️  実行時間: ${minutes}分${seconds}秒"
    echo "   ✅ 成功: ${#successful_services[@]} サービス"
    echo "   ❌ 失敗: ${#failed_services[@]} サービス"
    echo "   ⚠️  警告: ${#warnings[@]} 件"
    echo ""
    
    if [[ ${#successful_services[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ 成功したサービス:${NC}"
        for service in "${successful_services[@]}"; do
            echo "   - $service"
        done
        echo ""
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        echo -e "${RED}❌ 失敗したサービス:${NC}"
        for service in "${failed_services[@]}"; do
            echo "   - $service"
        done
        echo ""
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  警告:${NC}"
        for warning in "${warnings[@]}"; do
            echo "   - $warning"
        done
        echo ""
    fi
    
    echo -e "${BLUE}📄 詳細ログ: $LOG_FILE${NC}"
    echo ""
}

# 引数解析関数
parse_arguments() {
    # デフォルト値設定
    ENVIRONMENT="dev"
    REGION="us-west-2"
    
    # 第一引数が環境名の場合
    if [[ $# -gt 0 && "$1" =~ ^(dev|stage|prod)$ ]]; then
        ENVIRONMENT="$1"
        shift
    fi
    
    # オプション解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    REGION="$2"
                    shift 2
                else
                    log_error "--region オプションにはリージョン名が必要です"
                    show_usage
                    exit 1
                fi
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 環境とリージョンの検証
    if ! validate_environment "$ENVIRONMENT"; then
        exit 1
    fi
    
    if ! validate_region "$REGION"; then
        exit 1
    fi
}

# 環境名検証
validate_environment() {
    local env="$1"
    case "$env" in
        dev|stage|prod)
            return 0
            ;;
        *)
            log_error "無効な環境名: $env"
            log_error "有効な環境名: dev, stage, prod"
            return 1
            ;;
    esac
}

# リージョン検証
validate_region() {
    local region="$1"
    # 基本的なAWSリージョン形式の検証
    if [[ ! "$region" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
        log_error "無効なリージョン形式: $region"
        log_error "例: us-west-2, ap-northeast-1"
        return 1
    fi
    return 0
}

# 環境変数設定
setup_environment_variables() {
    local environment="$1"
    local region="$2"
    
    # グローバル変数に設定
    ENVIRONMENT="$environment"
    REGION="$region"
    
    # 環境変数としてエクスポート
    export HEALTHMATE_ENV="$environment"
    export AWS_REGION="$region"
    
    log_info "環境変数を設定しました:"
    log_info "  HEALTHMATE_ENV=$HEALTHMATE_ENV"
    log_info "  AWS_REGION=$AWS_REGION"
    
    return 0
}

# 使用方法表示（オーバーライド可能）
show_usage() {
    echo "使用方法が定義されていません。各スクリプトでオーバーライドしてください。"
}

# AWS認証情報確認
check_aws_credentials() {
    log_info "AWS認証情報を確認中..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS認証情報が設定されていません"
        log_error "以下のいずれかの方法で認証情報を設定してください:"
        log_error "  1. aws configure"
        log_error "  2. 環境変数 (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
        log_error "  3. IAM ロール (EC2/ECS/Lambda等)"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    log_success "AWS認証情報が有効です (アカウント: $account_id)"
    return 0
}

# サービスディレクトリ確認
check_service_directories() {
    log_info "サービスディレクトリを確認中..."
    
    local missing_dirs=()
    local service_dirs=("../Healthmate-Core" "../Healthmate-HealthManager" "../Healthmate-CoachAI" "../Healthmate-Frontend")
    
    for dir in "${service_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_error "以下のサービスディレクトリが見つかりません:"
        for dir in "${missing_dirs[@]}"; do
            log_error "  - $dir"
        done
        log_error "Healthmate-App ディレクトリから実行していることを確認してください"
        return 1
    fi
    
    log_success "すべてのサービスディレクトリが確認できました"
    return 0
}

# サービス準備完了確認
wait_for_service_ready() {
    local service_name="$1"
    local environment="$2"
    local max_wait_time=300  # 5分
    local check_interval=10  # 10秒間隔
    local elapsed_time=0
    
    log_info "$service_name の準備完了を確認中..."
    
    case "$service_name" in
        "Core")
            # Cognito User Poolの準備完了確認
            if wait_for_cognito_ready "$environment"; then
                log_success "$service_name の準備が完了しました"
                return 0
            else
                log_warning "$service_name の準備完了確認がタイムアウトしました"
                return 1
            fi
            ;;
        "HealthManager")
            # MCP Gatewayの準備完了確認
            if wait_for_healthmanager_ready "$environment"; then
                log_success "$service_name の準備が完了しました"
                return 0
            else
                log_warning "$service_name の準備完了確認がタイムアウトしました"
                return 1
            fi
            ;;
        "CoachAI")
            # AgentCore Runtimeの準備完了確認
            if wait_for_coachai_ready "$environment"; then
                log_success "$service_name の準備が完了しました"
                return 0
            else
                log_warning "$service_name の準備完了確認がタイムアウトしました"
                return 1
            fi
            ;;
        "Frontend")
            # CloudFront Distributionの準備完了確認
            if wait_for_frontend_ready "$environment"; then
                log_success "$service_name の準備が完了しました"
                return 0
            else
                log_warning "$service_name の準備完了確認がタイムアウトしました"
                return 1
            fi
            ;;
        *)
            log_warning "不明なサービス: $service_name - 準備完了確認をスキップします"
            return 0
            ;;
    esac
}

# Cognito User Pool準備完了確認
wait_for_cognito_ready() {
    local environment="$1"
    local stack_name="Healthmate-CoreStack-$environment"
    
    # CloudFormationスタックの状態確認
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" >/dev/null 2>&1; then
        local stack_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
        if [[ "$stack_status" == "CREATE_COMPLETE" || "$stack_status" == "UPDATE_COMPLETE" ]]; then
            return 0
        fi
    fi
    return 1
}

# HealthManager MCP Gateway準備完了確認
wait_for_healthmanager_ready() {
    local environment="$1"
    local stack_name="Healthmate-HealthManagerStack-$environment"
    
    # CloudFormationスタックの状態確認
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" >/dev/null 2>&1; then
        local stack_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
        if [[ "$stack_status" == "CREATE_COMPLETE" || "$stack_status" == "UPDATE_COMPLETE" ]]; then
            return 0
        fi
    fi
    return 1
}

# CoachAI AgentCore Runtime準備完了確認
wait_for_coachai_ready() {
    local environment="$1"
    local max_wait_time=300  # 5分
    local check_interval=10  # 10秒間隔
    local elapsed_time=0
    
    while [[ $elapsed_time -lt $max_wait_time ]]; do
        # bedrock-agentcore-control list-agent-runtimes を使用してエージェントの状態を確認
        local agent_list_output
        if agent_list_output=$(aws bedrock-agentcore-control list-agent-runtimes --region "$REGION" 2>/dev/null); then
            # jqが利用可能な場合
            if command -v jq >/dev/null 2>&1; then
                local agent_status=$(echo "$agent_list_output" | \
                    jq -r --arg env "$environment" '.agentRuntimes[] | select(.agentRuntimeName | contains($env)) | .status' 2>/dev/null | head -1)
            else
                # jqが利用できない場合はgrepとsedで代替
                local agent_status=$(echo "$agent_list_output" | \
                    grep -A 10 "\"agentRuntimeName\".*$environment" | \
                    grep "\"status\"" | \
                    sed 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | \
                    head -1)
            fi
            
            if [[ "$agent_status" == "READY" ]]; then
                log_success "CoachAI エージェントが READY 状態になりました"
                return 0
            elif [[ "$agent_status" == "FAILED" ]]; then
                log_error "CoachAI エージェントが FAILED 状態です"
                return 1
            elif [[ -n "$agent_status" ]]; then
                log_info "CoachAI エージェント状態: $agent_status"
            fi
        else
            log_info "エージェント状態の取得に失敗しました。リトライ中..."
        fi
        
        log_info "待機中... ($elapsed_time/$max_wait_time秒)"
        sleep $check_interval
        elapsed_time=$((elapsed_time + check_interval))
    done
    
    log_warning "CoachAI エージェントの準備完了確認がタイムアウトしました"
    return 1
}

# Frontend CloudFront Distribution準備完了確認
wait_for_frontend_ready() {
    local environment="$1"
    local stack_name="Healthmate-FrontendStack-$environment"
    
    # CloudFormationスタックの状態確認
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" >/dev/null 2>&1; then
        local stack_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
        if [[ "$stack_status" == "CREATE_COMPLETE" || "$stack_status" == "UPDATE_COMPLETE" ]]; then
            # CloudFront Distributionの状態も確認
            local distribution_id=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' --output text 2>/dev/null)
            if [[ -n "$distribution_id" ]]; then
                local distribution_status=$(aws cloudfront get-distribution --id "$distribution_id" --query 'Distribution.Status' --output text 2>/dev/null)
                if [[ "$distribution_status" == "Deployed" ]]; then
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

# 初期化処理
initialize() {
    log_info "Healthmate-App 統合デプロイメント管理を初期化中..."
    
    # AWS認証情報確認
    if ! check_aws_credentials; then
        return 1
    fi
    
    # サービスディレクトリ確認
    if ! check_service_directories; then
        return 1
    fi
    
    log_success "初期化完了"
    return 0
}