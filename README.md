# Healthmate-App 統合デプロイメント管理

Healthmate-App は、4つの独立したHealthmateサービスを統合管理するメタリポジトリです。一括デプロイメント機能により、複数のサービスを効率的に管理できます。

## 🏗️ アーキテクチャ概要

```
Healthmate-App (統合管理)
├── Healthmate-Core (認証基盤)
├── Healthmate-HealthManager (データ基盤)
├── Healthmate-CoachAI (AI エージェント)
└── Healthmate-Frontend (フロントエンド)
```

### サービス構成

| サービス | 役割 | 技術スタック | 依存関係 |
|---------|------|-------------|----------|
| **Healthmate-Core** | 認証基盤 | AWS CDK + Cognito | なし |
| **Healthmate-HealthManager** | データ基盤・MCP サーバー | AWS Lambda + DynamoDB | Core |
| **Healthmate-CoachAI** | AI健康コーチ | Bedrock AgentCore | HealthManager |
| **Healthmate-Frontend** | Webフロントエンド | React + TypeScript | 全サービス |

## 🚀 クイックスタート

### リポジトリのクローン

まず、すべてのHealthmateサービスをクローンします：

```bash
# 推奨: 専用ディレクトリを作成
mkdir healthmate-workspace && cd healthmate-workspace

# 5つのリポジトリを一括クローン
git clone https://github.com/tomofuminijo/Healthmate-Core.git
git clone https://github.com/tomofuminijo/Healthmate-HealthManager.git  
git clone https://github.com/tomofuminijo/Healthmate-CoachAI.git
git clone https://github.com/tomofuminijo/Healthmate-Frontend.git
git clone https://github.com/tomofuminijo/Healthmate-App.git

# ディレクトリ構造確認
ls -la
# healthmate-workspace/
# ├── Healthmate-Core/
# ├── Healthmate-HealthManager/
# ├── Healthmate-CoachAI/
# ├── Healthmate-Frontend/
# └── Healthmate-App/
```

### 前提条件確認

まず、すべての前提条件が満たされているかチェックしましょう：

```bash
# Healthmate-App ディレクトリに移動
cd Healthmate-App

# 前提条件の自動チェック
./check_prerequisites.sh
```

このスクリプトは以下をチェックします：
- 必須ソフトウェア（AWS CLI, Python, Node.js, npm, jq, Git）
- AWS認証設定
- ディレクトリ構造
- Python仮想環境
- Node.js依存関係
- デプロイスクリプト

### 初回セットアップ

前提条件に問題がある場合は、以下の手順で環境をセットアップしてください：

```bash
# 1. Python仮想環境セットアップ（各サービス）
cd ../Healthmate-Core && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && cd ../Healthmate-App
cd ../Healthmate-HealthManager && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && cd ../Healthmate-App
cd ../Healthmate-CoachAI && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt && cd ../Healthmate-App

# 2. HealthManager CDK Python環境セットアップ
cd ../Healthmate-HealthManager/cdk && python3 -m venv .venv && source .venv/bin/activate && cd ../../Healthmate-App

# 3. Node.js依存関係インストール（Frontendのみ）
cd ../Healthmate-Frontend && npm install && cd ../Healthmate-App

# 4. AWS認証設定
aws configure
# または
aws sso login

# 5. 前提条件再チェック
./check_prerequisites.sh
```

### 前提条件

#### 必須ソフトウェア

| ソフトウェア | バージョン | 用途 | インストール確認 |
|-------------|-----------|------|-----------------|
| **AWS CLI** | 2.0+ | AWSリソース管理 | `aws --version` |
| **Python** | 3.12+ | Core, HealthManager, CoachAI | `python3 --version` |
| **Node.js** | 18+ | Frontend, CDK | `node --version` |
| **npm** | 9+ | パッケージ管理 | `npm --version` |
| **jq** | 1.6+ | JSON処理 | `jq --version` |
| **Git** | 2.0+ | バージョン管理 | `git --version` |

#### AWS設定

```bash
# AWS CLI設定確認
aws configure list
aws sts get-caller-identity

# 必要なAWS権限
# - CloudFormation (フルアクセス)
# - IAM (ロール作成・管理)
# - S3 (バケット作成・管理)
# - DynamoDB (テーブル作成・管理)
# - Lambda (関数作成・管理)
# - Cognito (User Pool作成・管理)
# - Bedrock AgentCore (エージェント管理)
# - CloudFront (ディストリビューション管理)
```

#### Python環境設定

各サービスで仮想環境が必要です：

```bash
# Python仮想環境の確認・作成（各サービスディレクトリで実行）
cd Healthmate-Core
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cd ../Healthmate-HealthManager  
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cd ../Healthmate-CoachAI
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt  # 開発・テスト用依存関係
# 注意: デプロイ時は agent/requirements.txt が自動使用されます

# HealthManager CDK用の仮想環境
cd ../Healthmate-HealthManager/cdk
python3 -m venv .venv
source .venv/bin/activate
# CDKの依存関係は cdk.json で管理されます
```

#### Node.js環境設定

Frontend で必要です：

```bash
# Frontendの依存関係インストール
cd Healthmate-Frontend
npm install

# グローバルCDKインストール（未インストールの場合）
npm install -g aws-cdk
cdk --version
```

**注意**: HealthManager は Python CDK を使用するため、Node.js 依存関係は不要です。

#### 特殊ツール

```bash
# jq（JSON処理ツール）のインストール
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Amazon Linux
sudo yum install jq

# bedrock-agentcore-control CLI（CoachAI用）
# AWS CLIに含まれているため、追加インストール不要
aws bedrock-agentcore-control help
```

#### ディレクトリ構造

各サービスディレクトリが同じレベルに配置されている必要があります：

```bash
# 推奨ディレクトリ構造
healthmate-workspace/
├── Healthmate-Core/           # 認証基盤
├── Healthmate-HealthManager/  # データ基盤・MCP
├── Healthmate-CoachAI/        # AI エージェント
├── Healthmate-Frontend/       # React フロントエンド
└── Healthmate-App/            # このリポジトリ（統合管理）
```

#### 環境確認スクリプト

すべての前提条件を確認するには：

```bash
# Healthmate-App ディレクトリで実行
./check_prerequisites.sh
```

#### 初回セットアップ手順

```bash
# 1. 全サービスのクローン（推奨ディレクトリ構造）
mkdir healthmate-workspace && cd healthmate-workspace

# 各サービスリポジトリをクローン
git clone https://github.com/tomofuminijo/Healthmate-Core.git
git clone https://github.com/tomofuminijo/Healthmate-HealthManager.git  
git clone https://github.com/tomofuminijo/Healthmate-CoachAI.git
git clone https://github.com/tomofuminijo/Healthmate-Frontend.git
git clone https://github.com/tomofuminijo/Healthmate-App.git

# ワンライナーでのクローン（上記と同じ結果）
# git clone https://github.com/tomofuminijo/Healthmate-Core.git && git clone https://github.com/tomofuminijo/Healthmate-HealthManager.git && git clone https://github.com/tomofuminijo/Healthmate-CoachAI.git && git clone https://github.com/tomofuminijo/Healthmate-Frontend.git && git clone https://github.com/tomofuminijo/Healthmate-App.git

# ディレクトリ構造確認
ls -la
# 以下のような構造になります：
# healthmate-workspace/
# ├── Healthmate-Core/
# ├── Healthmate-HealthManager/
# ├── Healthmate-CoachAI/
# ├── Healthmate-Frontend/
# └── Healthmate-App/

# 2. Python仮想環境セットアップ
cd Healthmate-Core && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && cd ..
cd Healthmate-HealthManager && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && cd ..
cd Healthmate-CoachAI && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt && cd ..

# 注意: CoachAI は開発用に requirements-dev.txt を使用
# デプロイ時は agent/requirements.txt が自動的に使用されます

# 3. HealthManager CDK Python環境セットアップ
cd Healthmate-HealthManager/cdk && python3 -m venv .venv && source .venv/bin/activate && cd ../..

# 4. Node.js依存関係インストール（Frontendのみ）
cd Healthmate-Frontend && npm install && cd ..

# 5. AWS認証設定
aws configure
# または
aws sso login

# 6. 前提条件確認
cd Healthmate-App
./check_prerequisites.sh

# 7. 初回デプロイ
./deploy_all.sh dev
```

### 一括デプロイ

```bash
# 開発環境にデプロイ
./deploy_all.sh

# 本番環境にデプロイ（ap-northeast-1リージョン）
./deploy_all.sh prod --region ap-northeast-1

# ステージング環境にデプロイ
./deploy_all.sh stage
```

### 一括アンデプロイ

```bash
# 開発環境からアンデプロイ
./undeploy_all.sh

# 本番環境からアンデプロイ（ap-northeast-1リージョン）
./undeploy_all.sh prod --region ap-northeast-1
```

## 📋 コマンドリファレンス

### deploy_all.sh

4つのサービスを正しい順序でデプロイします。

```bash
使用方法: ./deploy_all.sh [environment] [options]

環境:
    dev     開発環境（デフォルト）
    stage   ステージング環境  
    prod    本番環境

オプション:
    --region REGION    AWSリージョンを指定
    --help, -h         ヘルプを表示

例:
    ./deploy_all.sh                              # dev環境、デフォルトリージョン
    ./deploy_all.sh dev                          # dev環境、デフォルトリージョン
    ./deploy_all.sh prod --region ap-northeast-1 # prod環境、ap-northeast-1リージョン
```

**デプロイ順序:**
1. Healthmate-Core (認証基盤)
2. Healthmate-HealthManager (データ基盤)
3. Healthmate-CoachAI (AI エージェント)
4. Healthmate-Frontend (フロントエンド)

**エラーハンドリング:**
- 一つのサービスが失敗すると、後続のサービスのデプロイは停止されます
- 詳細なエラー情報と対処方法が表示されます

### undeploy_all.sh

4つのサービスを逆順でアンデプロイします。

```bash
使用方法: ./undeploy_all.sh [environment] [options]

環境:
    dev     開発環境（デフォルト）
    stage   ステージング環境  
    prod    本番環境

オプション:
    --region REGION    AWSリージョンを指定
    --help, -h         ヘルプを表示
```

**アンデプロイ順序:**
1. Healthmate-Frontend (フロントエンド)
2. Healthmate-CoachAI (AI エージェント)
3. Healthmate-HealthManager (データ基盤)
4. Healthmate-Core (認証基盤)

**エラーハンドリング:**
- 一つのサービスが失敗しても、他のサービスのアンデプロイは継続されます
- 失敗したサービスは警告として表示されます

## 🔧 環境設定

### 環境変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `HEALTHMATE_ENV` | デプロイ環境 | `dev` |
| `AWS_REGION` | AWSリージョン | AWS CLIのデフォルト |

### リージョン設定の優先順位

1. コマンドライン引数 (`--region`)
2. 環境変数 (`AWS_REGION`)
3. AWS CLIのデフォルト設定

### 各サービスへの環境変数渡し

統合デプロイメント管理では、以下の環境変数が各サービスに自動的に渡されます：

- `HEALTHMATE_ENV`: 指定された環境名
- `AWS_REGION`: 指定されたリージョン

## 📊 ログとモニタリング

### ログファイル

実行ログは `logs/` ディレクトリに自動保存されます：

```bash
logs/
└── healthmate-app-YYYYMMDD-HHMMSS.log
```

### ログレベル

- **INFO**: 一般的な情報メッセージ
- **SUCCESS**: 成功メッセージ
- **WARNING**: 警告メッセージ（処理は継続）
- **ERROR**: エラーメッセージ（処理は停止）

### 実行サマリー

各実行の最後に詳細なサマリーが表示されます：

- 実行時間
- 成功/失敗したサービス一覧
- 警告メッセージ
- ログファイルの場所

## 🔗 サービスリンク

### 個別サービスリポジトリ

- **[Healthmate-Core](../Healthmate-Core/)**: 認証基盤サービス
- **[Healthmate-HealthManager](../Healthmate-HealthManager/)**: データ管理・MCP サーバー
- **[Healthmate-CoachAI](../Healthmate-CoachAI/)**: AI健康コーチエージェント
- **[Healthmate-Frontend](../Healthmate-Frontend/)**: Webフロントエンドアプリケーション

### ドキュメント

- **[プロダクト概要](../Healthmate-Core/.kiro/steering/product-overview.md)**: Healthmate プロダクト全体の概要
- **[技術スタック](../Healthmate-Core/.kiro/steering/tech-stack.md)**: 使用技術とツール
- **[プロジェクト構造](../Healthmate-Core/.kiro/steering/project-structure.md)**: ファイル構造と命名規則

## 🛠️ トラブルシューティング

### よくある問題

#### 1. AWS認証エラー

```bash
❌ AWS認証情報が無効です
```

**解決方法:**
```bash
# AWS認証情報を設定
aws configure

# または SSOログイン
aws sso login

# 認証確認
aws sts get-caller-identity
```

#### 2. Python仮想環境エラー

```bash
❌ ModuleNotFoundError: No module named 'boto3'
```

**解決方法:**
```bash
# 各サービスで仮想環境をアクティベート
cd Healthmate-Core
source .venv/bin/activate
pip install -r requirements.txt

# 他のサービスでも同様に実行
cd ../Healthmate-HealthManager
source .venv/bin/activate
pip install -r requirements.txt
```

#### 3. Node.js依存関係エラー

```bash
❌ Error: Cannot find module 'aws-cdk-lib'
```

**解決方法:**
```bash
# Frontend依存関係インストール
cd Healthmate-Frontend
npm install

# グローバルCDKインストール
npm install -g aws-cdk

# 注意: HealthManagerはPython CDKを使用するため、Node.js依存関係は不要です
```

#### 4. サービスディレクトリが見つからない

```bash
❌ サービスディレクトリが見つかりません: ../Healthmate-Core
```

**解決方法:**
- Healthmate-App が他の4つのサービスと同じレベルに配置されているか確認
- ディレクトリ名が正確であることを確認

#### 5. デプロイスクリプトが見つからない

```bash
❌ Core のデプロイスクリプトが見つかりません
```

**解決方法:**
```bash
# スクリプト存在確認
ls -la ../Healthmate-Core/deploy.sh

# 実行権限付与
chmod +x ../Healthmate-Core/deploy.sh
chmod +x ../Healthmate-Core/destroy.sh
```

#### 6. CoachAI デプロイエラー

```bash
❌ AgentCore エージェントの作成に失敗しました
```

**解決方法:**
```bash
# IAMロールの確認
aws iam get-role --role-name Healthmate-CoachAI-AgentCore-Runtime-Role

# 手動でIAMロール作成
cd ../Healthmate-CoachAI
python create_custom_iam_role.py

# 再デプロイ
./deploy_to_aws.sh
```

#### 7. HealthManager Credential Provider エラー

```bash
❌ ConflictException: Unable to create SecretsManager secret
```

**解決方法:**
- 自動リトライ機能が実装済み（30回、1秒間隔）
- 通常は自動的に解決されます
- 継続する場合は手動でSecretsManagerの古いシークレットを削除

#### 8. Frontend リージョン設定エラー

```bash
❌ Frontend が間違ったリージョンに接続している
```

**解決方法:**
```bash
# 環境変数ファイル確認
cat ../Healthmate-Frontend/.env

# 正しいリージョンを設定
echo "VITE_AWS_REGION=ap-northeast-1" >> ../Healthmate-Frontend/.env

# 再ビルド
cd ../Healthmate-Frontend
npm run build
```

### デバッグ方法

1. **ログファイルを確認**
   ```bash
   cat logs/healthmate-app-*.log
   ```

2. **個別サービスのテスト**
   ```bash
   cd ../Healthmate-Core
   ./deploy.sh
   ```

3. **AWS リソースの確認**
   ```bash
   aws cloudformation list-stacks
   aws s3 ls
   ```

## 🔄 開発ワークフロー

### 新機能開発時

1. 個別サービスで開発・テスト
2. 統合デプロイメントでdev環境にデプロイ
3. 統合テストの実行
4. stage環境での検証
5. prod環境へのデプロイ

### 本番デプロイ手順

```bash
# 1. ステージング環境での最終確認
./deploy_all.sh stage --region ap-northeast-1

# 2. 統合テストの実行
# (各サービスの統合テストを実行)

# 3. 本番環境へのデプロイ
./deploy_all.sh prod --region ap-northeast-1

# 4. 本番環境での動作確認
# (ヘルスチェック、機能テスト)
```

### ロールバック手順

```bash
# 問題が発生した場合の緊急ロールバック
./undeploy_all.sh prod --region ap-northeast-1

# 前のバージョンの再デプロイ
git checkout <previous-version>
./deploy_all.sh prod --region ap-northeast-1
```

## 📈 パフォーマンス

### デプロイ時間の目安

| サービス | 通常時間 | 初回デプロイ |
|---------|----------|-------------|
| Core | 2-3分 | 5-7分 |
| HealthManager | 3-5分 | 8-12分 |
| CoachAI | 5-8分 | 10-15分 |
| Frontend | 2-4分 | 5-8分 |
| **合計** | **12-20分** | **28-42分** |

### 最適化のヒント

- **並列実行**: 現在は順次実行ですが、将来的に依存関係のないサービスの並列デプロイを検討
- **キャッシュ活用**: CDK や npm のキャッシュを活用してビルド時間を短縮
- **リージョン選択**: 地理的に近いリージョンを選択してネットワーク遅延を削減

## 🔒 セキュリティ

### 認証・認可

- AWS IAM ロールベースのアクセス制御
- 環境ごとの分離されたリソース
- 最小権限の原則に基づく権限設定

### 機密情報管理

- 環境変数による設定管理
- AWS Secrets Manager での機密情報保存
- ログファイルでの機密情報マスキング

## 🤝 コントリビューション

### 開発ガイドライン

1. 既存サービスのコードは変更しない
2. 統合機能はHealthmate-App内でのみ実装
3. 既存のデプロイスクリプトを活用する
4. 日本語でのドキュメント作成

### プルリクエスト

1. 機能ブランチを作成
2. テストの実行と確認
3. ドキュメントの更新
4. プルリクエストの作成

## 📞 サポート

### 問題報告

- GitHub Issues での報告
- ログファイルの添付
- 環境情報の記載

### 緊急時連絡

- 本番環境での問題: 即座にロールバック実行
- 開発環境での問題: ログ確認後に個別対応

---

**最終更新**: 2025年12月25日  
**バージョン**: 1.0.0  
**メンテナー**: Healthmate開発チーム