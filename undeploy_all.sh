#!/bin/bash

# Healthmate-App 統合デプロイメント管理
# 4つのHealthmateサービスを一括でアンデプロイするスクリプト

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
UNDEPLOYED_SERVICES=()
FAILED_SERVICES=()
WARNINGS=()

# 使用方法表示（オーバーライド）
show_usage() {
    cat << EOF
使用方法: $0 [environment] [options]

Healthmate-App 統合デプロイメント管理 - 一括アンデプロイ

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

アンデプロイ順序:
    1. Healthmate-Frontend (フロントエンド)
    2. Healthmate-CoachAI (AI エージェント)
    3. Healthmate-HealthManager (データ基盤)
    4. Healthmate-Core (認証基盤)

注意事項:
    - アンデプロイは逆順で実行されます
    - 一つのサービスが失敗しても、他のサービスのアンデプロイは継続されます
    - 失敗したサービスは警告として表示されます

前提条件:
    - AWS CLI が設定済みであること
    - 各サービスディレクトリが存在すること
    - 適切なAWS認証情報が設定されていること
EOF
}

# アンデプロイ開始メッセージ
show_undeploy_start() {
    echo ""
    echo "🗑️ Healthmate-App 統合アンデプロイメントを開始します"
    echo "=============================================="
    echo "📋 アンデプロイ設定:"
    echo "   🌍 環境: $ENVIRONMENT"
    echo "   📍 リージョン: $REGION"
    echo "   📅 開始時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "📝 アンデプロイ順序:"
    for i in "${!UNDEPLOY_ORDER[@]}"; do
        local service="${UNDEPLOY_ORDER[$i]}"
        local service_path=$(get_service_info "$service" "path")
        local undeploy_script=$(get_service_info "$service" "undeploy_script")
        echo "   $((i+1)). $service ($service_path/$undeploy_script)"
    done
    echo ""
    echo "⚠️  注意: 一つのサービスが失敗しても、他のサービスのアンデプロイは継続されます"
    echo ""
}

# サービスアンデプロイ実行
undeploy_service() {
    local service_name="$1"
    local service_index="$2"
    local total_services="$3"
    
    log_progress "$((service_index+1))" "$total_services" "$service_name" "アンデプロイ"
    log_info "[$((service_index+1))/$total_services] $service_name のアンデプロイを開始..."
    
    # サービススクリプト存在確認
    if ! check_service_script "$service_name" "undeploy"; then
        log_warning "$service_name のアンデプロイスクリプトが見つかりません"
        WARNINGS+=("$service_name: アンデプロイスクリプトが見つかりません")
        return 1
    fi
    
    # アンデプロイ実行
    local start_time=$(date +%s)
    
    if execute_service_script "$service_name" "undeploy" "$ENVIRONMENT"; then
        local end_time=$(date +%s)
        
        UNDEPLOYED_SERVICES+=("$service_name")
        log_duration "$start_time" "$end_time" "$service_name" "アンデプロイ"
        log_success "[$((service_index+1))/$total_services] $service_name のアンデプロイが完了しました"
        
        # サービス間の短い待機時間
        if [[ $((service_index+1)) -lt $total_services ]]; then
            log_info "次のサービスのアンデプロイ準備中..."
            sleep 1  # デプロイより短い待機時間
        fi
        
        return 0
    else
        FAILED_SERVICES+=("$service_name")
        log_warning "[$((service_index+1))/$total_services] $service_name のアンデプロイが失敗しました（継続します）"
        WARNINGS+=("$service_name: アンデプロイが失敗しました")
        return 1
    fi
}

# 全サービスアンデプロイ実行
undeploy_all_services() {
    local total_services=${#UNDEPLOY_ORDER[@]}
    
    log_info "全 $total_services サービスのアンデプロイを開始します..."
    
    # 全サービスのスクリプト存在確認（警告のみ、継続実行）
    if ! check_all_service_scripts "undeploy"; then
        log_warning "一部のアンデプロイスクリプトに問題がありますが、継続します"
    fi
    
    # 順次アンデプロイ実行（エラーがあっても継続）
    for i in "${!UNDEPLOY_ORDER[@]}"; do
        local service="${UNDEPLOY_ORDER[$i]}"
        
        # 個別サービスの失敗は継続（戻り値は無視）
        undeploy_service "$service" "$i" "$total_services" || true
    done
    
    return 0
}

# アンデプロイ完了メッセージ
show_undeploy_success() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    echo "🎉 Healthmate-App 統合アンデプロイメントが完了しました！"
    echo "=============================================="
    echo "📋 アンデプロイ結果:"
    echo "   ✅ 成功したサービス: ${#UNDEPLOYED_SERVICES[@]}/${#UNDEPLOY_ORDER[@]}"
    for service in "${UNDEPLOYED_SERVICES[@]}"; do
        echo "      - $service"
    done
    
    if [[ ${#FAILED_SERVICES[@]} -gt 0 ]]; then
        echo "   ⚠️  失敗したサービス: ${#FAILED_SERVICES[@]}/${#UNDEPLOY_ORDER[@]}"
        for service in "${FAILED_SERVICES[@]}"; do
            echo "      - $service"
        done
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "   ⚠️  警告:"
        for warning in "${WARNINGS[@]}"; do
            echo "      - $warning"
        done
    fi
    
    echo "   ⏱️  総実行時間: ${minutes}分${seconds}秒"
    echo "   📅 完了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    if [[ ${#FAILED_SERVICES[@]} -eq 0 ]]; then
        echo "🎉 すべてのサービスが正常にアンデプロイされました"
    else
        echo "⚠️  一部のサービスでアンデプロイに失敗しました"
        echo "🔧 失敗したサービスについて:"
        echo "   1. 手動でリソースを確認してください"
        echo "   2. AWS コンソールで残存リソースを確認してください"
        echo "   3. 必要に応じて個別にアンデプロイを実行してください"
    fi
    echo ""
    echo "💰 アンデプロイされたリソースのAWSコストは発生しなくなります"
    echo ""
}

# 確認プロンプト
show_confirmation() {
    echo ""
    echo "⚠️  警告: この操作により以下のリソースが削除されます:"
    echo ""
    for service in "${UNDEPLOY_ORDER[@]}"; do
        case "$service" in
            "Frontend")
                echo "   🌐 Healthmate-Frontend:"
                echo "      - S3 バケット"
                echo "      - CloudFront ディストリビューション"
                echo "      - CDK スタック"
                ;;
            "CoachAI")
                echo "   🤖 Healthmate-CoachAI:"
                echo "      - AgentCore エージェント"
                echo "      - ECR リポジトリ"
                echo "      - IAM ロール"
                echo "      - メモリリソース (dev環境のみ)"
                ;;
            "HealthManager")
                echo "   📊 Healthmate-HealthManager:"
                echo "      - DynamoDB テーブル (全データ)"
                echo "      - Lambda 関数"
                echo "      - AgentCore Gateway"
                echo "      - CDK スタック"
                ;;
            "Core")
                echo "   🔐 Healthmate-Core:"
                echo "      - Cognito User Pool (全ユーザーデータ)"
                echo "      - User Pool Client"
                echo "      - CloudFormation Exports"
                echo "      - CDK スタック"
                ;;
        esac
    done
    echo ""
    echo "🚨 この操作は取り消せません！"
    echo "📋 対象環境: $ENVIRONMENT"
    echo "📍 対象リージョン: $REGION"
    echo ""
    
    read -p "本当にアンデプロイを実行しますか？ (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "アンデプロイがキャンセルされました"
        exit 0
    fi
    
    echo ""
    log_info "アンデプロイを開始します..."
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
    
    # アンデプロイ開始メッセージ
    show_undeploy_start
    
    # 確認プロンプト
    show_confirmation
    
    # 全サービスアンデプロイ実行
    undeploy_all_services
    
    # 結果表示
    show_undeploy_success
    
    # 実行サマリー表示
    show_execution_summary "undeploy" "$START_TIME" UNDEPLOYED_SERVICES[@] FAILED_SERVICES[@] WARNINGS[@]
    
    # 終了コード決定
    if [[ ${#FAILED_SERVICES[@]} -eq 0 ]]; then
        exit 0  # 全て成功
    else
        exit 2  # 一部失敗（警告レベル）
    fi
}

# スクリプト実行
main "$@"