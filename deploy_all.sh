#!/bin/bash

# Healthmate-App 統合デプロイメント管理
# 4つのHealthmateサービスを一括でデプロイするスクリプト

set -e  # エラー時に停止

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリを読み込み
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/services.sh"

# グローバル変数
ENVIRONMENT=""
REGION=""
START_TIME=""
DEPLOYED_SERVICES=()
FAILED_SERVICES=()
WARNINGS=()

# 使用方法表示（オーバーライド）
show_usage() {
    cat << EOF
使用方法: $0 [environment] [options]

Healthmate-App 統合デプロイメント管理 - 一括デプロイ

環境:
    dev     開発環境（デフォルト）
    stage   ステージング環境  
    prod    本番環境

オプション:
    --region REGION    AWSリージョンを指定
    --help, -h         このヘルプを表示

例:
    $0                              # dev環境、デフォルトリージョン
    $0 dev                          # dev環境、デフォルトリージョン
    $0 prod --region ap-northeast-1 # prod環境、ap-northeast-1リージョン
    $0 stage                        # stage環境、デフォルトリージョン

デプロイ順序:
    1. Healthmate-Core (認証基盤)
    2. Healthmate-HealthManager (データ基盤)
    3. Healthmate-CoachAI (AI エージェント)
    4. Healthmate-Frontend (フロントエンド)

前提条件:
    - AWS CLI が設定済みであること
    - 各サービスディレクトリが存在すること
    - 適切なAWS認証情報が設定されていること
EOF
}

# デプロイ開始メッセージ
show_deploy_start() {
    echo ""
    echo "🚀 Healthmate-App 統合デプロイメントを開始します"
    echo "=============================================="
    echo "📋 デプロイ設定:"
    echo "   🌍 環境: $ENVIRONMENT"
    echo "   📍 リージョン: $REGION"
    echo "   📅 開始時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "📝 デプロイ順序:"
    for i in "${!DEPLOY_ORDER[@]}"; do
        local service="${DEPLOY_ORDER[$i]}"
        local service_path=$(get_service_info "$service" "path")
        local deploy_script=$(get_service_info "$service" "deploy_script")
        echo "   $((i+1)). $service ($service_path/$deploy_script)"
    done
    echo ""
}

# サービスデプロイ実行
deploy_service() {
    local service_name="$1"
    local service_index="$2"
    local total_services="$3"
    
    log_progress "$((service_index+1))" "$total_services" "$service_name" "デプロイ"
    log_info "[$((service_index+1))/$total_services] $service_name のデプロイを開始..."
    
    # サービススクリプト存在確認
    if ! check_service_script "$service_name" "deploy"; then
        log_error "$service_name のデプロイスクリプトが見つかりません"
        FAILED_SERVICES+=("$service_name")
        WARNINGS+=("$service_name: デプロイスクリプトが見つかりません")
        return 1
    fi
    
    # デプロイ実行
    local start_time=$(date +%s)
    
    if execute_service_script "$service_name" "deploy" "$ENVIRONMENT"; then
        local end_time=$(date +%s)
        
        DEPLOYED_SERVICES+=("$service_name")
        log_duration "$start_time" "$end_time" "$service_name" "デプロイ"
        log_success "[$((service_index+1))/$total_services] $service_name のデプロイが完了しました"
        
        # サービス準備完了確認
        log_info "$service_name の準備完了を確認中..."
        if wait_for_service_ready "$service_name" "$ENVIRONMENT" 2>/dev/null; then
            log_success "$service_name の準備が完了しました"
        else
            log_warning "$service_name の準備完了確認に失敗しましたが、継続します"
        fi
        
        # サービス間同期確認
        if [[ $((service_index+1)) -lt $total_services ]]; then
            log_info "次のサービスのデプロイ準備中..."
            sleep 3  # 同期のための待機時間を少し延長
        fi
        
        return 0
    else
        FAILED_SERVICES+=("$service_name")
        log_error "[$((service_index+1))/$total_services] $service_name のデプロイが失敗しました"
        return 1
    fi
}

# 全サービスデプロイ実行
deploy_all_services() {
    local total_services=${#DEPLOY_ORDER[@]}
    
    log_info "全 $total_services サービスのデプロイを開始します..."
    
    # 全サービスのスクリプト存在確認
    if ! check_all_service_scripts "deploy"; then
        log_error "デプロイスクリプトの確認に失敗しました"
        return 1
    fi
    
    # 順次デプロイ実行
    for i in "${!DEPLOY_ORDER[@]}"; do
        local service="${DEPLOY_ORDER[$i]}"
        
        if ! deploy_service "$service" "$i" "$total_services"; then
            log_error "デプロイが失敗しました。後続のサービスのデプロイを中止します"
            return 1
        fi
    done
    
    return 0
}

# デプロイ完了メッセージ
show_deploy_success() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo "🎉 Healthmate-App 統合デプロイメントが完了しました！"
    echo "=============================================="
    echo "📋 デプロイ結果:"
    echo "   ✅ 成功したサービス: ${#DEPLOYED_SERVICES[@]}/${#DEPLOY_ORDER[@]}"
    for service in "${DEPLOYED_SERVICES[@]}"; do
        echo "      - $service"
    done
    echo "   ⏱️  総実行時間: ${minutes}分${seconds}秒"
    echo "   📅 完了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "🚀 次のステップ:"
    echo "   1. 各サービスの動作確認を行ってください"
    echo "   2. 統合テストの実行を推奨します"
    echo "   3. 問題がある場合は ./undeploy_all.sh でロールバックできます"
    echo ""
    
    # 統合テスト推奨メッセージを表示
    show_integration_test_recommendation
}

# デプロイ失敗メッセージ
show_deploy_failure() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo "💥 Healthmate-App 統合デプロイメントが失敗しました"
    echo "=============================================="
    echo "📋 デプロイ結果:"
    echo "   ✅ 成功したサービス: ${#DEPLOYED_SERVICES[@]}/${#DEPLOY_ORDER[@]}"
    for service in "${DEPLOYED_SERVICES[@]}"; do
        echo "      - $service"
    done
    if [[ -n "$FAILED_SERVICE" ]]; then
        echo "   ❌ 失敗したサービス: $FAILED_SERVICE"
    fi
    echo "   ⏱️  実行時間: ${minutes}分${seconds}秒"
    echo "   📅 失敗時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "🔧 トラブルシューティング:"
    echo "   1. AWS認証情報を確認してください"
    echo "   2. 失敗したサービスのログを確認してください"
    echo "   3. 必要に応じて ./undeploy_all.sh で部分的にロールバックしてください"
    echo "   4. 問題を修正後、再度デプロイを実行してください"
    echo ""
}

# メイン処理
main() {
    # 開始時刻記録
    START_TIME=$(date +%s)
    
    # 引数解析
    parse_arguments "$@"
    
    # 環境変数設定
    if ! setup_environment_variables "$ENVIRONMENT" "$REGION"; then
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
    
    # デプロイ開始メッセージ
    show_deploy_start
    
    # 全サービスデプロイ実行
    if deploy_all_services; then
        show_deploy_success
        # 実行サマリー表示
        show_execution_summary "deploy" "$START_TIME" DEPLOYED_SERVICES[@] FAILED_SERVICES[@] WARNINGS[@]
        exit 0
    else
        show_deploy_failure
        # 実行サマリー表示
        show_execution_summary "deploy" "$START_TIME" DEPLOYED_SERVICES[@] FAILED_SERVICES[@] WARNINGS[@]
        exit 1
    fi
}

# スクリプト実行
main "$@"