#!/bin/bash

# 環境変数を取得（デフォルトはdevelopment）
ENVIRONMENT=${1:-development}

# 色付きの出力用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Flutter Web Build Script${NC}"
echo -e "${BLUE}================================================${NC}"

# 現在のindex.htmlをバックアップ（念のため）
if [ -f "web/index.html" ]; then
    cp web/index.html web/index.html.backup
    echo -e "${YELLOW}📋 Backed up current index.html${NC}"
fi

# 環境に応じたindex.htmlをコピー
case "$ENVIRONMENT" in
    production|prd)
        echo -e "${GREEN}📦 Building for PRODUCTION...${NC}"
        cp web/index.html.prd web/index.html
        flutter build web --release --dart-define=ENVIRONMENT=production
        ;;
    staging|stg)
        echo -e "${GREEN}📦 Building for STAGING...${NC}"
        cp web/index.html.stg web/index.html
        flutter build web --release --dart-define=ENVIRONMENT=staging
        ;;
    development|dev)
        echo -e "${GREEN}📦 Building for DEVELOPMENT...${NC}"
        cp web/index.html.dev web/index.html
        flutter build web --dart-define=ENVIRONMENT=development
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unknown environment: $ENVIRONMENT${NC}"
        echo -e "${YELLOW}Using development configuration...${NC}"
        cp web/index.html.dev web/index.html
        flutter build web --dart-define=ENVIRONMENT=development
        ;;
esac

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully for $ENVIRONMENT${NC}"
    echo -e "${BLUE}================================================${NC}"
else
    echo -e "${YELLOW}❌ Build failed${NC}"
    # バックアップから復元
    if [ -f "web/index.html.backup" ]; then
        mv web/index.html.backup web/index.html
        echo -e "${YELLOW}Restored original index.html${NC}"
    fi
    exit $BUILD_STATUS
fi

# バックアップを削除
rm -f web/index.html.backup