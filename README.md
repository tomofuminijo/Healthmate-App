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

### 前提条件

- AWS CLI が設定済みであること
- 適切なAWS認証情報が設定されていること
- 各サービスディレクトリが同じレベルに配置されていること

```bash
# ディレクトリ構造
parent-directory/
├── Healthmate-Core/
├── Healthmate-HealthManager/
├── Healthmate-CoachAI/
├── Healthmate-Frontend/
└── Healthmate-App/          # このリポジトリ
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
```

#### 2. サービスディレクトリが見つからない

```bash
❌ サービスディレクトリが見つかりません: ../Healthmate-Core
```

**解決方法:**
- Healthmate-App が他の4つのサービスと同じレベルに配置されているか確認
- ディレクトリ名が正確であることを確認

#### 3. デプロイスクリプトが見つからない

```bash
❌ Core のデプロイスクリプトが見つかりません
```

**解決方法:**
- 各サービスに必要なデプロイスクリプトが存在することを確認
- スクリプトに実行権限があることを確認

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