#!/bin/bash

# undeploy_all.sh の動作テスト（モック環境）

echo "🧪 undeploy_all.sh 動作テスト開始"

# テスト用の一時ディレクトリ作成
TEST_DIR=$(mktemp -d)
echo "テスト用ディレクトリ: $TEST_DIR"

# 現在のディレクトリを保存
ORIGINAL_DIR=$(pwd)

# テスト用ディレクトリに移動
cd "$TEST_DIR"

# Healthmate-Appディレクトリをコピー
cp -r "$ORIGINAL_DIR" ./Healthmate-App

# モックサービスディレクトリを作成
mkdir -p Healthmate-Core Healthmate-HealthManager/scripts Healthmate-CoachAI Healthmate-Frontend

# モックアンデプロイスクリプトを作成
cat > Healthmate-Core/destroy.sh << 'EOF'
#!/bin/bash
echo "🗑️ Healthmate-Core アンデプロイ開始 (環境: $HEALTHMATE_ENV, リージョン: $AWS_REGION)"
sleep 1
echo "✅ Healthmate-Core アンデプロイ完了"
EOF

cat > Healthmate-HealthManager/scripts/destroy-full-stack.sh << 'EOF'
#!/bin/bash
echo "🗑️ Healthmate-HealthManager アンデプロイ開始 (環境: $HEALTHMATE_ENV, リージョン: $AWS_REGION)"
sleep 1
echo "✅ Healthmate-HealthManager アンデプロイ完了"
EOF

cat > Healthmate-CoachAI/destroy_from_aws.sh << 'EOF'
#!/bin/bash
echo "🗑️ Healthmate-CoachAI アンデプロイ開始 (環境: $HEALTHMATE_ENV, リージョン: $AWS_REGION)"
sleep 1
echo "✅ Healthmate-CoachAI アンデプロイ完了"
EOF

cat > Healthmate-Frontend/destroy.sh << 'EOF'
#!/bin/bash
echo "🗑️ Healthmate-Frontend アンデプロイ開始 (環境: $1, リージョン: $AWS_REGION)"
sleep 1
echo "✅ Healthmate-Frontend アンデプロイ完了"
EOF

# スクリプトに実行権限を付与
chmod +x Healthmate-Core/destroy.sh
chmod +x Healthmate-HealthManager/scripts/destroy-full-stack.sh
chmod +x Healthmate-CoachAI/destroy_from_aws.sh
chmod +x Healthmate-Frontend/destroy.sh

# AWS CLIコマンドをモック
cat > aws << 'EOF'
#!/bin/bash
if [[ "$1" == "sts" && "$2" == "get-caller-identity" ]]; then
    echo '{"Account": "123456789012"}'
elif [[ "$1" == "configure" && "$2" == "get" && "$3" == "region" ]]; then
    echo "us-west-2"
fi
EOF
chmod +x aws
export PATH="$PWD:$PATH"

# Healthmate-Appディレクトリに移動
cd Healthmate-App

echo "🔍 テスト1: デフォルト設定でのアンデプロイテスト"
# 確認プロンプトを自動化
echo "yes" | ./undeploy_all.sh
if [[ $? -eq 0 ]]; then
    echo "✅ デフォルト設定テスト成功"
else
    echo "❌ デフォルト設定テスト失敗"
fi

echo ""
echo "🔍 テスト2: 環境・リージョン指定でのアンデプロイテスト"
# 確認プロンプトを自動化
echo "yes" | ./undeploy_all.sh prod --region ap-northeast-1
if [[ $? -eq 0 ]]; then
    echo "✅ 環境・リージョン指定テスト成功"
else
    echo "❌ 環境・リージョン指定テスト失敗"
fi

# クリーンアップ
cd "$ORIGINAL_DIR"
rm -rf "$TEST_DIR"

echo "🎉 undeploy_all.sh 動作テスト完了"