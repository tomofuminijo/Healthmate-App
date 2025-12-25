#!/bin/bash

# Healthmate-App サービス設定
# 4つのサービスの設定とデプロイ・アンデプロイスクリプトの定義

set -o pipefail  # パイプライン内のコマンドの終了コードを正しく取得

# サービス設定配列
# フォーマット: "サービス名:相対パス:デプロイスクリプト:アンデプロイスクリプト"
declare -a SERVICES=(
    "Core:../Healthmate-Core:deploy.sh:destroy.sh"
    "HealthManager:../Healthmate-HealthManager:scripts/deploy-full-stack.sh:scripts/destroy-full-stack.sh"
    "CoachAI:../Healthmate-CoachAI:deploy_to_aws.sh:destroy_from_aws.sh"
    "Frontend:../Healthmate-Frontend:deploy.sh:destroy.sh"
)

# デプロイ順序（Core → HealthManager → CoachAI → Frontend）
declare -a DEPLOY_ORDER=("Core" "HealthManager" "CoachAI" "Frontend")

# アンデプロイ順序（Frontend → CoachAI → HealthManager → Core）
declare -a UNDEPLOY_ORDER=("Frontend" "CoachAI" "HealthManager" "Core")

# サービス情報取得関数
get_service_info() {
    local service_name="$1"
    local info_type="$2"  # name, path, deploy_script, undeploy_script
    
    for service_config in "${SERVICES[@]}"; do
        IFS=':' read -r name path deploy_script undeploy_script <<< "$service_config"
        
        if [[ "$name" == "$service_name" ]]; then
            case "$info_type" in
                name)
                    echo "$name"
                    return 0
                    ;;
                path)
                    echo "$path"
                    return 0
                    ;;
                deploy_script)
                    echo "$deploy_script"
                    return 0
                    ;;
                undeploy_script)
                    echo "$undeploy_script"
                    return 0
                    ;;
                *)
                    log_error "無効な情報タイプ: $info_type"
                    return 1
                    ;;
            esac
        fi
    done
    
    log_error "サービスが見つかりません: $service_name"
    return 1
}

# サービススクリプト存在確認
check_service_script() {
    local service_name="$1"
    local script_type="$2"  # deploy または undeploy
    
    local service_path=$(get_service_info "$service_name" "path")
    local script_name
    
    if [[ "$script_type" == "deploy" ]]; then
        script_name=$(get_service_info "$service_name" "deploy_script")
    elif [[ "$script_type" == "undeploy" ]]; then
        script_name=$(get_service_info "$service_name" "undeploy_script")
    else
        log_error "無効なスクリプトタイプ: $script_type"
        return 1
    fi
    
    local script_path="$service_path/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "$service_name の$script_type スクリプトが見つかりません: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log_warning "$service_name の$script_type スクリプトに実行権限がありません: $script_path"
        log_info "実行権限を付与しています..."
        chmod +x "$script_path"
    fi
    
    return 0
}

# 全サービスのスクリプト存在確認
check_all_service_scripts() {
    local script_type="$1"  # deploy または undeploy
    local missing_scripts=()
    
    log_info "全サービスの$script_type スクリプトを確認中..."
    
    for service_name in "${DEPLOY_ORDER[@]}"; do
        if ! check_service_script "$service_name" "$script_type"; then
            missing_scripts+=("$service_name")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "以下のサービスの$script_type スクリプトに問題があります:"
        for service in "${missing_scripts[@]}"; do
            log_error "  - $service"
        done
        return 1
    fi
    
    log_success "すべてのサービスの$script_type スクリプトが確認できました"
    return 0
}

# サービス実行関数
execute_service_script() {
    local service_name="$1"
    local script_type="$2"  # deploy または undeploy
    local environment="$3"
    
    local service_path=$(get_service_info "$service_name" "path")
    local script_name
    
    if [[ "$script_type" == "deploy" ]]; then
        script_name=$(get_service_info "$service_name" "deploy_script")
    elif [[ "$script_type" == "undeploy" ]]; then
        script_name=$(get_service_info "$service_name" "undeploy_script")
    else
        log_error "無効なスクリプトタイプ: $script_type"
        return 1
    fi
    
    log_info "$service_name の$script_type を開始..."
    write_to_log "EXECUTE: Starting $service_name $script_type"
    
    # サービスディレクトリに移動
    local original_dir=$(pwd)
    
    # ログファイルの絶対パスを取得
    local absolute_log_file="$original_dir/$LOG_FILE"
    
    cd "$service_path" || {
        log_error "$service_name のディレクトリに移動できません: $service_path"
        write_to_log "EXECUTE_ERROR: Cannot change to directory $service_path"
        return 1
    }
    
    # 現在の仮想環境を無効化（他のサービスの仮想環境の影響を排除）
    if [[ -n "$VIRTUAL_ENV" ]]; then
        log_info "$service_name: 既存の仮想環境を無効化中 ($VIRTUAL_ENV)"
        # 仮想環境のPATHを保存
        local venv_bin_path="$VIRTUAL_ENV/bin"
        deactivate 2>/dev/null || true
        unset VIRTUAL_ENV
        unset PYTHONPATH
        # システムの基本コマンドパスを確保
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$(echo "$PATH" | sed "s|$venv_bin_path:||g")"
    fi
    
    # サービス固有の仮想環境をアクティベート（存在する場合）
    if [[ -f ".venv/bin/activate" ]]; then
        log_info "$service_name: サービス固有の仮想環境をアクティベート中"
        source .venv/bin/activate
    elif [[ -f "venv/bin/activate" ]]; then
        log_info "$service_name: サービス固有の仮想環境をアクティベート中"
        source venv/bin/activate
    else
        log_info "$service_name: 仮想環境が見つかりません。システムPythonを使用します"
    fi
    
    # 環境変数設定（各サービス用）
    export HEALTHMATE_ENV="$environment"
    export AWS_REGION="$REGION"
    
    # スクリプト実行
    local start_time=$(date +%s)
    local exit_code=0
    
    # Frontendサービスは引数で環境を渡す
    if [[ "$service_name" == "Frontend" ]]; then
        if ! ./"$script_name" "$environment" 2>&1 | tee -a "$absolute_log_file"; then
            exit_code=$?
            cd "$original_dir"
            log_error "$service_name の$script_type が失敗しました (終了コード: $exit_code)"
            log_error_details "$service_name" "$script_type" "$exit_code" "スクリプト実行エラー"
            write_to_log "EXECUTE_ERROR: $service_name $script_type failed with exit code $exit_code"
            return 1
        fi
    else
        if ! ./"$script_name" 2>&1 | tee -a "$absolute_log_file"; then
            exit_code=$?
            cd "$original_dir"
            log_error "$service_name の$script_type が失敗しました (終了コード: $exit_code)"
            log_error_details "$service_name" "$script_type" "$exit_code" "スクリプト実行エラー"
            write_to_log "EXECUTE_ERROR: $service_name $script_type failed with exit code $exit_code"
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    log_duration "$start_time" "$end_time" "$service_name" "$script_type"
    
    # 元のディレクトリに戻る
    cd "$original_dir"
    
    # 元の仮想環境に戻す（統合システムの仮想環境）
    if [[ -f "$original_dir/.venv/bin/activate" ]]; then
        source "$original_dir/.venv/bin/activate"
    fi
    
    log_success "$service_name の$script_type が完了しました"
    write_to_log "EXECUTE_SUCCESS: $service_name $script_type completed successfully"
    
    return 0
}