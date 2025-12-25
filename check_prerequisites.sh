#!/bin/bash

# Healthmate-App 前提条件確認スクリプト
# 統合デプロイメントに必要なすべての前提条件をチェックします

set -e

# カラーコード定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# チェック結果
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# ログ関数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

log_header() {
    echo ""
    echo -e "${CYAN}$1${NC}"
    echo "========================================"
}

# バージョン比較関数
version_compare() {
    local version1="$1"
    local operator="$2"
    local version2="$3"
    
    # バージョン文字列から数字のみ抽出
    local v1=$(echo "$version1" | sed 's/[^0-9.]//g')
    local v2=$(echo "$version2" | sed 's/[^0-9.]//g')
    
    if [[ "$operator" == ">=" ]]; then
        if printf '%s\n%s\n' "$v2" "$v1" | sort -V -C; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# 必須ソフトウェアチェック
check_required_software() {
    log_header "必須ソフトウェアチェック"
    
    # AWS CLI
    if command -v aws >/dev/null 2>&1; then
        local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        if version_compare "$aws_version" ">=" "2.0.0"; then
            log_success "AWS CLI: $aws_version"
        else
            log_error "AWS CLI バージョンが古すぎます: $aws_version (必要: 2.0+)"
        fi
    else
        log_error "AWS CLI がインストールされていません"
        echo "  インストール: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    fi
    
    # Python
    if command -v python3 >/dev/null 2>&1; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        if version_compare "$python_version" ">=" "3.12.0"; then
            log_success "Python: $python_version"
        else
            log_warning "Python バージョンが推奨より古いです: $python_version (推奨: 3.12+)"
        fi
    else
        log_error "Python3 がインストールされていません"
    fi
    
    # Node.js
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version | sed 's/v//')
        if version_compare "$node_version" ">=" "18.0.0"; then
            log_success "Node.js: $node_version"
        else
            log_error "Node.js バージョンが古すぎます: $node_version (必要: 18+)"
        fi
    else
        log_error "Node.js がインストールされていません"
    fi
    
    # npm
    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version)
        if version_compare "$npm_version" ">=" "9.0.0"; then
            log_success "npm: $npm_version"
        else
            log_warning "npm バージョンが推奨より古いです: $npm_version (推奨: 9+)"
        fi
    else
        log_error "npm がインストールされていません"
    fi
    
    # jq
    if command -v jq >/dev/null 2>&1; then
        local jq_version=$(jq --version | sed 's/jq-//')
        log_success "jq: $jq_version"
    else
        log_error "jq がインストールされていません"
        echo "  macOS: brew install jq"
        echo "  Ubuntu: sudo apt-get install jq"
        echo "  Amazon Linux: sudo yum install jq"
    fi
    
    # Git
    if command -v git >/dev/null 2>&1; then
        local git_version=$(git --version | cut -d' ' -f3)
        log_success "Git: $git_version"
    else
        log_error "Git がインストールされていません"
    fi
    
    # CDK
    if command -v cdk >/dev/null 2>&1; then
        local cdk_version=$(cdk --version | cut -d' ' -f1)
        log_success "AWS CDK: $cdk_version"
    else
        log_warning "AWS CDK がグローバルインストールされていません"
        echo "  インストール: npm install -g aws-cdk"
    fi
}

# AWS設定チェック
check_aws_configuration() {
    log_header "AWS設定チェック"
    
    # AWS認証情報
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS認証: アカウント $account_id"
        echo "  ユーザー: $user_arn"
    else
        log_error "AWS認証情報が設定されていません"
        echo "  設定方法: aws configure または aws sso login"
        return
    fi
    
    # デフォルトリージョン
    local default_region=$(aws configure get region 2>/dev/null || echo "未設定")
    if [[ "$default_region" != "未設定" ]]; then
        log_success "デフォルトリージョン: $default_region"
    else
        log_warning "デフォルトリージョンが設定されていません"
        echo "  設定方法: aws configure set region us-west-2"
    fi
    
    # bedrock-agentcore-control
    if aws bedrock-agentcore-control help >/dev/null 2>&1; then
        log_success "Bedrock AgentCore CLI が利用可能です"
    else
        log_error "Bedrock AgentCore CLI が利用できません"
        echo "  AWS CLI を最新版に更新してください"
    fi
}

# ディレクトリ構造チェック
check_directory_structure() {
    log_header "ディレクトリ構造チェック"
    
    local required_dirs=(
        "../Healthmate-Core"
        "../Healthmate-HealthManager"
        "../Healthmate-CoachAI"
        "../Healthmate-Frontend"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "$(basename "$dir") ディレクトリが存在します"
        else
            log_error "$(basename "$dir") ディレクトリが見つかりません: $dir"
        fi
    done
}

# Python仮想環境チェック
check_python_environments() {
    log_header "Python仮想環境チェック"
    
    local python_services=(
        "../Healthmate-Core"
        "../Healthmate-HealthManager"
        "../Healthmate-CoachAI"
    )
    
    for service_dir in "${python_services[@]}"; do
        local service_name=$(basename "$service_dir")
        
        if [[ -d "$service_dir" ]]; then
            if [[ -d "$service_dir/.venv" ]]; then
                log_success "$service_name: 仮想環境が存在します"
                
                # requirements.txt の確認（CoachAIは requirements-dev.txt を使用）
                if [[ -f "$service_dir/requirements.txt" ]]; then
                    log_success "$service_name: requirements.txt が存在します"
                elif [[ "$service_name" == "Healthmate-CoachAI" && -f "$service_dir/requirements-dev.txt" ]]; then
                    log_success "$service_name: requirements-dev.txt が存在します"
                else
                    if [[ "$service_name" == "Healthmate-CoachAI" ]]; then
                        log_warning "$service_name: requirements-dev.txt が見つかりません"
                    else
                        log_warning "$service_name: requirements.txt が見つかりません"
                    fi
                fi
            else
                log_error "$service_name: 仮想環境が作成されていません"
                echo "  作成方法: cd $service_dir && python3 -m venv .venv"
            fi
        fi
    done
}

# Node.js依存関係チェック
check_nodejs_dependencies() {
    log_header "Node.js依存関係チェック"
    
    # Frontend
    if [[ -d "../Healthmate-Frontend" ]]; then
        if [[ -d "../Healthmate-Frontend/node_modules" ]]; then
            log_success "Frontend: node_modules が存在します"
        else
            log_error "Frontend: 依存関係がインストールされていません"
            echo "  インストール: cd ../Healthmate-Frontend && npm install"
        fi
        
        if [[ -f "../Healthmate-Frontend/package.json" ]]; then
            log_success "Frontend: package.json が存在します"
        else
            log_error "Frontend: package.json が見つかりません"
        fi
    fi
    
    # HealthManager CDK - Python CDKを使用しているためNode.js依存関係は不要
    if [[ -d "../Healthmate-HealthManager/cdk" ]]; then
        if [[ -f "../Healthmate-HealthManager/cdk/cdk.json" ]]; then
            log_success "HealthManager CDK: Python CDK設定が存在します (cdk.json)"
        else
            log_warning "HealthManager CDK: cdk.json が見つかりません"
        fi
        
        if [[ -f "../Healthmate-HealthManager/cdk/app.py" ]]; then
            log_success "HealthManager CDK: Python CDKアプリが存在します (app.py)"
        else
            log_error "HealthManager CDK: app.py が見つかりません"
        fi
        
        # Python CDKの仮想環境確認
        if [[ -d "../Healthmate-HealthManager/cdk/.venv" ]]; then
            log_success "HealthManager CDK: Python仮想環境が存在します"
        else
            log_warning "HealthManager CDK: Python仮想環境が作成されていません"
            echo "  作成方法: cd ../Healthmate-HealthManager/cdk && python3 -m venv .venv"
        fi
    fi
}

# デプロイスクリプトチェック
check_deploy_scripts() {
    log_header "デプロイスクリプトチェック"
    
    local services=(
        "Core:../Healthmate-Core:deploy.sh:destroy.sh"
        "HealthManager:../Healthmate-HealthManager:scripts/deploy-full-stack.sh:scripts/destroy-full-stack.sh"
        "CoachAI:../Healthmate-CoachAI:deploy_to_aws.sh:destroy_from_aws.sh"
        "Frontend:../Healthmate-Frontend:deploy.sh:destroy.sh"
    )
    
    for service_config in "${services[@]}"; do
        IFS=':' read -r name path deploy_script undeploy_script <<< "$service_config"
        
        if [[ -d "$path" ]]; then
            # デプロイスクリプト
            if [[ -f "$path/$deploy_script" ]]; then
                if [[ -x "$path/$deploy_script" ]]; then
                    log_success "$name: デプロイスクリプト ($deploy_script) が実行可能です"
                else
                    log_warning "$name: デプロイスクリプトに実行権限がありません"
                    echo "  修正方法: chmod +x $path/$deploy_script"
                fi
            else
                log_error "$name: デプロイスクリプトが見つかりません: $path/$deploy_script"
            fi
            
            # アンデプロイスクリプト
            if [[ -f "$path/$undeploy_script" ]]; then
                if [[ -x "$path/$undeploy_script" ]]; then
                    log_success "$name: アンデプロイスクリプト ($undeploy_script) が実行可能です"
                else
                    log_warning "$name: アンデプロイスクリプトに実行権限がありません"
                    echo "  修正方法: chmod +x $path/$undeploy_script"
                fi
            else
                log_error "$name: アンデプロイスクリプトが見つかりません: $path/$undeploy_script"
            fi
        fi
    done
}

# 結果サマリー
show_summary() {
    log_header "チェック結果サマリー"
    
    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED))
    
    echo -e "${GREEN}✅ 成功: $CHECKS_PASSED${NC}"
    echo -e "${RED}❌ 失敗: $CHECKS_FAILED${NC}"
    echo -e "${YELLOW}⚠️  警告: $WARNINGS${NC}"
    echo -e "${BLUE}📊 合計: $total_checks チェック${NC}"
    echo ""
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 すべての前提条件が満たされています！${NC}"
        echo -e "${CYAN}統合デプロイメントを実行できます:${NC}"
        echo "  ./deploy_all.sh dev"
        echo ""
    else
        echo -e "${RED}💥 前提条件に問題があります${NC}"
        echo -e "${YELLOW}上記のエラーを修正してから再実行してください${NC}"
        echo ""
        echo -e "${CYAN}修正後の再チェック:${NC}"
        echo "  ./check_prerequisites.sh"
        echo ""
    fi
    
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  警告がありますが、デプロイは可能です${NC}"
        echo -e "${YELLOW}可能であれば警告も修正することを推奨します${NC}"
        echo ""
    fi
}

# メイン実行
main() {
    echo -e "${CYAN}🔍 Healthmate-App 前提条件チェック${NC}"
    echo "========================================"
    echo "統合デプロイメントに必要な前提条件をチェックします"
    
    check_required_software
    check_aws_configuration
    check_directory_structure
    check_python_environments
    check_nodejs_dependencies
    check_deploy_scripts
    show_summary
    
    # 終了コード設定
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# スクリプト実行
main "$@"