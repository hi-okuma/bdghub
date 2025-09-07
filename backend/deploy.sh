#!/bin/bash

# デプロイスクリプト
# 使用方法: ./deploy.sh [dev|stg|prd] [functions|data|all]

ENV=${1:-dev}
TARGET=${2:-functions}

echo "🚀 デプロイ開始: 環境=${ENV}, ターゲット=${TARGET}"

# 環境の切り替え
firebase use $ENV

if [ $? -ne 0 ]; then
    echo "❌ エラー: 環境 '${ENV}' に切り替えできませんでした"
    exit 1
fi

echo "✅ 環境を ${ENV} に切り替えました"

# デプロイの実行
case $TARGET in
    "functions")
        echo "📦 Cloud Functions をデプロイしています..."
        firebase deploy --only functions
        ;;
    "data")
        echo "🗄️ Firestoreデータを移行しています..."
        if [ "$ENV" = "dev" ]; then
            echo "❌ dev環境からはデータを移行できません（移行元のため）"
            exit 1
        fi
        
        echo "📤 dev環境からデータをエクスポートしています..."
        DEV_PROJECT_ID="bdghub-dev"
        TARGET_PROJECT_ID=$(firebase use | grep "Active project" | awk '{print $3}' | sed 's/[()]//g')
        
        # Cloud Storageバケットにエクスポート
        EXPORT_PATH="gs://${DEV_PROJECT_ID}.appspot.com/firestore-backup-$(date +%Y%m%d-%H%M%S)"
        
        echo "エクスポート先: $EXPORT_PATH"
        gcloud firestore export $EXPORT_PATH --project=$DEV_PROJECT_ID
        
        echo "📥 ${ENV}環境にデータをインポートしています..."
        gcloud firestore import $EXPORT_PATH --project=$TARGET_PROJECT_ID
        ;;
    "all")
        echo "📦 Cloud Functions をデプロイしています..."
        firebase deploy --only functions
        
        if [ "$ENV" != "dev" ]; then
            echo ""
            read -p "Firestoreデータをdev環境から移行しますか？ (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "📤 dev環境からデータをエクスポートしています..."
                DEV_PROJECT_ID="bdghub-dev"
                TARGET_PROJECT_ID=$(firebase use | grep "Active project" | awk '{print $3}' | sed 's/[()]//g')
                
                # Cloud Storageバケットにエクスポート
                EXPORT_PATH="gs://${DEV_PROJECT_ID}.appspot.com/firestore-backup-$(date +%Y%m%d-%H%M%S)"
                
                echo "エクスポート先: $EXPORT_PATH"
                gcloud firestore export $EXPORT_PATH --project=$DEV_PROJECT_ID
                
                echo "📥 ${ENV}環境にデータをインポートしています..."
                gcloud firestore import $EXPORT_PATH --project=$TARGET_PROJECT_ID
            fi
        fi
        ;;
    *)
        echo "❌ エラー: 無効なターゲット '${TARGET}'"
        echo "有効なターゲット: functions, data, all"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo "✅ デプロイが完了しました！"
    PROJECT_ID=$(firebase use 2>/dev/null | grep "Active project" | awk '{print $3}' | sed 's/[()]//g')
    echo "🌐 Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}/overview"
else
    echo "❌ デプロイに失敗しました"
    exit 1
fi

echo "🎉 すべての処理が完了しました！"