#!/bin/bash
# 导出 iOS IPA 脚本
# 用法: ./export_ipa.sh

set -e

# 配置
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
EXPORT_PATH="/Volumes/S10/ipa"
TEAM_ID="KZ7VQKP6UP"
PLIST_PATH="/tmp/exportOptions.plist"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== iOS IPA 导出脚本 ===${NC}"

# 1. 检查 Archive 目录
if [ ! -d "$ARCHIVE_DIR" ]; then
    echo -e "${RED}错误: 找不到 Archive 目录: $ARCHIVE_DIR${NC}"
    echo "请先执行: Product → Archive"
    exit 1
fi

# 2. 查找最新的 xcarchive
ARCHIVE=$(ls -dt "$ARCHIVE_DIR"/*.xcarchive 2>/dev/null | head -1)

if [ -z "$ARCHIVE" ]; then
    echo -e "${RED}错误: 找不到 .xcarchive 文件${NC}"
    echo "请先执行: Product → Archive"
    exit 1
fi

echo -e "${GREEN}找到 Archive: $(basename "$ARCHIVE")${NC}"

# 3. 创建导出目录
mkdir -p "$EXPORT_PATH"

# 4. 创建 exportOptions.plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

# 5. 导出 IPA
echo -e "${YELLOW}正在导出 IPA...${NC}"
cd "$ARCHIVE_DIR"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -allowProvisioningUpdates

# 6. 检查导出结果
IPA_FILE=$(ls -t "$EXPORT_PATH"/*.ipa 2>/dev/null | head -1)

if [ -f "$IPA_FILE" ]; then
    echo -e "${GREEN}✓ 导出成功!${NC}"
    echo -e "${GREEN}IPA 路径: $IPA_FILE${NC}"
    echo -e "${GREEN}文件大小: $(du -h "$IPA_FILE" | cut -f1)${NC}"
    
    # 显示二维码（可选）
    echo ""
    echo -e "${YELLOW}=== 上传蒲公英 ===${NC}"
    echo "1. 打开 https://www.pgyer.com"
    echo "2. 上传 IPA: $IPA_FILE"
    echo "3. 分享下载链接"
    
else
    echo -e "${RED}✗ 导出失败${NC}"
    exit 1
fi

# 7. 清理临时文件
rm -f "$PLIST_PATH"

echo ""
echo -e "${GREEN}完成!${NC}"
